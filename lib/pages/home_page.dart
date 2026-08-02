import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../controllers/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/question.dart';
import '../services/auth_middleware.dart';
import '../utils/constants.dart';
import '../widgets/app_drawer.dart';
import '../widgets/category_section.dart';
import '../widgets/user_menu_button.dart';
import 'question_detail_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.onNavigate});

  final String title;
  final void Function(BuildContext, String) onNavigate;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final AuthMiddleware _authMiddleware = AuthMiddleware();
  List<Question> _questions = [];
  String? _errorMessage;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<int> _selectedCategoryIds = {};
  Timer? _debounceTimer;

  /// Controls infinite-scroll pagination.
  final ScrollController _scrollController = ScrollController();

  /// Offset of the next page to fetch (number of questions already loaded).
  int _offset = 0;

  /// Whether more pages are available on the backend.
  bool _hasMore = true;

  /// Whether a page is currently being appended (infinite scroll).
  bool _isLoadingMore = false;

  /// Internal mutex guarding against concurrent fetches.
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Defer the initial fetch until after the first frame is built so the
    // build context can depend on inherited widgets such as `AppLocalizations`.
    // Accessing `AppLocalizations.of(context)` from `initState` directly throws
    // because inherited widgets are not yet available at that point.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchQuestions();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Triggers loading the next page when the user scrolls near the bottom.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold &&
        _hasMore &&
        !_isLoading &&
        !_isLoadingMore) {
      _fetchQuestions(reset: false);
    }
  }

  /// Loads questions from the backend using the paginated `/questions/restSearch`
  /// endpoint.
  ///
  /// When [reset] is `true` the current list is cleared, the pagination state is
  /// reset, and the first page (size [pageSize], offset 0) is fetched. This is
  /// used for the initial load, search, category filtering and manual refresh.
  ///
  /// When [reset] is `false` the next page is appended to the existing list.
  /// This is used by the infinite-scroll handler [_onScroll] once the user
  /// reaches the bottom of the list.
  ///
  /// [searchQuery] optionally overrides the currently applied search term; when
  /// omitted, the current [_searchQuery] is used so appended pages keep the same
  /// filter as the already loaded ones.
  Future<void> _fetchQuestions({bool reset = true, String? searchQuery}) async {
    // Prevent concurrent requests (initial load, search, append) from
    // interfering with each other.
    if (_isFetching) return;
    _isFetching = true;

    final l10n = AppLocalizations.of(context);
    final String effectiveSearch = (searchQuery ?? _searchQuery).trim();

    debugPrint(
      'Fetching questions...'
      '${effectiveSearch.isNotEmpty ? ' with search: $effectiveSearch' : ''}'
      '${reset ? '' : ' (append, offset: $_offset)'}',
    );

    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _offset = 0;
        _hasMore = true;
        _questions = [];
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final languageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final preAuth = context.read<AuthController>();
    final preBirthYear = preAuth.birthYear;
    debugPrint('Fetching questions for language: $languageCode');

    try {
      // Use the restSearch endpoint for all question loading.
      // Language selection and age verification are handled server-side via
      // the `language` and `age` parameters. Results are fetched in pages of
      // [pageSize] questions; infinite scroll appends further pages as the
      // user scrolls down. Category filtering is applied via `categoryIds`.
      final currentYear = DateTime.now().year;
      final userAge = preBirthYear != null ? currentYear - preBirthYear : null;

      final Map<String, Object> body = <String, Object>{
        'language': languageCode,
        'offset': _offset,
        'limit': pageSize,
        // Only apply substring search for queries of at least 3 characters.
        if (effectiveSearch.length >= 3) 'search': effectiveSearch,
        if (_selectedCategoryIds.isNotEmpty)
          'categoryIds': _selectedCategoryIds.toList(),
      };
      if (userAge != null) {
        body['age'] = userAge;
      }

      final response = await _authMiddleware.post(
        '${ApiConfig.baseUrl}/questions/restSearch',
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // The backend returns the JSON literal `null` (HTTP 200) for an empty
        // result set, so guard against a null body here.
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];

        final newQuestions = data
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _questions.addAll(newQuestions);
          _offset += newQuestions.length;
          // If we received fewer items than a full page there are no further
          // pages to load.
          _hasMore = newQuestions.length >= pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
        debugPrint(
          'Loaded ${newQuestions.length} questions (total: ${_questions.length})',
        );
      } else if (response.statusCode == 401) {
        // Token refresh failed, user needs to login again.
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        if (mounted) {
          context.read<AuthController>().logout(showLoginPage: true);
        }
      } else {
        setState(() {
          _errorMessage = l10n.serverError;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching questions: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = l10n.connectionError(e.toString());
        _isLoading = false;
        _isLoadingMore = false;
      });
    } finally {
      _isFetching = false;
    }
  }

  void _onSearchChanged(String value) {
    // Always update search query state first
    setState(() {
      _searchQuery = value;
    });

    // Cancel any pending previous search FIRST to prevent immediate execution
    _debounceTimer?.cancel();

    // Handle different search scenarios
    if (value.isEmpty) {
      // When clearing search: fetch non-search questions immediately
      // but prevent any search scheduling
      _fetchQuestions();
      return;
    } else if (value.length >= 3) {
      // Schedule the search with delay ONLY for 3+ characters
      _debounceTimer = Timer(
        const Duration(milliseconds: searchDelayMilliseconds),
        () {
          // Check if this is still the current value before making API call
          if (_searchController.text == value && value.length >= 3) {
            _fetchQuestions(searchQuery: value);
          }
        },
      );
    } else {
      // For values < 3 characters: don't trigger search yet
      // This prevents immediate search on first letter
      return;
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    // Schedule clear action with small delay to prevent immediate fetch
    _debounceTimer = Timer(
      const Duration(milliseconds: 200),
      () => _onSearchChanged(''),
    );
  }

  /// Shows a multi-select dialog that lets the user pick which categories to
  /// filter questions by. The selection is applied via [categoryIds] on the
  /// next question fetch.
  void _showCategoryFilterDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = context.read<AuthController>().categories;
    // Sort categories by name for a stable display order.
    final sortedEntries = categories.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    // Work on a local copy so Cancel leaves the current selection intact.
    final Set<int> tempSelected = Set<int>.from(_selectedCategoryIds);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.filterDialogTitle),
              content: SizedBox(
                width: double.maxFinite,
                child: sortedEntries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: Text(l10n.noCategoriesAvailable)),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: sortedEntries.map((entry) {
                          return CheckboxListTile(
                            title: Text(entry.value),
                            value: tempSelected.contains(entry.key),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  tempSelected.add(entry.key);
                                } else {
                                  tempSelected.remove(entry.key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => setDialogState(() => tempSelected.clear()),
                  child: Text(l10n.clear),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedCategoryIds
                        ..clear()
                        ..addAll(tempSelected);
                    });
                    _fetchQuestions();
                  },
                  child: Text(l10n.apply),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Map<String, List<Question>> _groupQuestionsByCategory() {
    final Map<String, List<Question>> grouped = {};
    for (final question in _questions) {
      grouped.putIfAbsent(question.categoryName, () => []).add(question);
    }
    return grouped;
  }

  void _navigateToDetails(Question question) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionDetailsPage(question: question),
      ),
    );
  }

  void showSearchDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.searchDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
                ),
                onChanged: _onSearchChanged, // Use the same debounced handler
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _fetchQuestions(); // Reset when canceled
              },
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Widget buildSearchField() {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: l10n.searchFieldHint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupedQuestions = _groupQuestionsByCategory();
    final authController = context.watch<AuthController>();

    return Scaffold(
      drawer: AppDrawer(
        selectedRoute: 'questions',
        onSelect: widget.onNavigate,
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          // Search button
          IconButton(
            onPressed: () {
              showSearchDialog(context);
            },
            icon: const Icon(Icons.search),
            tooltip: l10n.searchTooltip,
          ),
          // Category filter button
          IconButton(
            onPressed: () => _showCategoryFilterDialog(context),
            icon: Badge(
              isLabelVisible: _selectedCategoryIds.isNotEmpty,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: l10n.filterTooltip,
          ),
          const UserMenuButton(),
          IconButton(
            onPressed: _isLoading ? null : _fetchQuestions,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.reload,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchQuestions,
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            )
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // Search field at the top
                buildSearchField(),
                const SizedBox(height: 16),
                // Display search query indicator when searching
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (_searchQuery.length > 2)
                                ? 'Search results for "$_searchQuery"'
                                : 'Type at least three characters',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearSearch,
                          child: Text(l10n.clear),
                        ),
                      ],
                    ),
                  ),
                // Active category filter chips
                if (_selectedCategoryIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ..._selectedCategoryIds.map((id) {
                          final name = authController.categories[id] ??
                              l10n.categoryFallback(id);
                          return Chip(
                            label: Text(name),
                            onDeleted: () {
                              setState(
                                  () => _selectedCategoryIds.remove(id));
                              _fetchQuestions();
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                // Categories
                ...groupedQuestions.entries.map(
                  (entry) => CategorySection(
                    categoryName: entry.key,
                    questions: entry.value,
                    onQuestionTap: _navigateToDetails,
                  ),
                ),
                // Infinite-scroll footer.
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (!_hasMore && _questions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.allQuestionsLoaded,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else if (_questions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.noQuestionsFound,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
