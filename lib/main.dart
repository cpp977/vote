import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/api_config.dart';
import 'controllers/auth_controller.dart';
import 'services/auth_middleware.dart';
import 'pages/login_page.dart';
import 'l10n/app_localizations.dart';
import 'l10n/auth_error_localization.dart';
import 'models/auth_models.dart';

void main() {
  runApp(const MyApp());
}

/// Fallback category name used by [Question.fromJson] when the backend
/// returns none. It is matched (case-sensitively) at the display site so the
/// localized equivalent can be shown instead.
const String uncategorizedFallback = 'Uncategorized';

class Question {
  final int id;
  final String text;
  final int categoryId;
  final String categoryName;
  final String language;

  Question({
    required this.id,
    required this.text,
    required this.categoryId,
    required this.categoryName,
    required this.language,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      text: json['text'] as String,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String? ?? uncategorizedFallback,
      language: json['language'] as String? ?? 'en',
    );
  }
}

class AnswerOption {
  final int id;
  final int questionId;
  final String text;

  AnswerOption({
    required this.id,
    required this.questionId,
    required this.text,
  });

  factory AnswerOption.fromJson(Map<String, dynamic> json) {
    return AnswerOption(
      id: json['id'] as int,
      questionId: json['question_id'] as int,
      text: json['text'] as String,
    );
  }
}

/// Statistics for a single answer option.
class AnswerStats {
  final int answerId;
  final String answerText;
  final int count;
  final double percent;

  AnswerStats({
    required this.answerId,
    required this.answerText,
    required this.count,
    required this.percent,
  });

  factory AnswerStats.fromJson(Map<String, dynamic> json) {
    return AnswerStats(
      answerId: json['answer_id'] as int,
      answerText: json['answer_text'] as String,
      count: json['count'] as int,
      percent: (json['percent'] as num).toDouble(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController()..checkAuthStatus(),
      child: MaterialApp(
        title: 'Vote',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthGate(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}

/// Widget that shows login page or home page based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.isAuthenticated) {
          return const MyHomePage(title: 'Vote');
        }
        return const LoginPage();
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

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
  static const int _searchDelayMilliseconds = 500;
  Timer? _debounceTimer;

  /// Controls infinite-scroll pagination.
  final ScrollController _scrollController = ScrollController();

  /// Number of questions requested per page from the backend.
  static const int _pageSize = 20;

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
  /// reset, and the first page (size [_pageSize], offset 0) is fetched. This is
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
      // [_pageSize] questions; infinite scroll appends further pages as the
      // user scrolls down. Category filtering is applied via `categoryIds`.
      final currentYear = DateTime.now().year;
      final userAge = preBirthYear != null ? currentYear - preBirthYear : null;

      final Map<String, Object> body = <String, Object>{
        'language': languageCode,
        'offset': _offset,
        'limit': _pageSize,
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
          _hasMore = newQuestions.length >= _pageSize;
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
          context.read<AuthController>().logout();
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
        const Duration(milliseconds: _searchDelayMilliseconds),
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

  Future<void> _handleLogout() async {
    final authController = context.read<AuthController>();
    await authController.logout();
  }

  /// Opens a dialog showing the currently logged-in user's profile details.
  void _showUserDetailsDialog(BuildContext context) {
    final authController = context.read<AuthController>();
    showDialog(
      context: context,
      builder: (dialogContext) =>
          UserDetailsDialog(authController: authController),
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
          // User menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                authController.username?.substring(0, 1).toUpperCase() ??
                    l10n.userInitialFallback,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              } else if (value == 'details') {
                _showUserDetailsDialog(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  authController.username ?? l10n.userMenuName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline),
                    const SizedBox(width: 8),
                    Text(l10n.userDetails),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout),
                    const SizedBox(width: 8),
                    Text(l10n.logout),
                  ],
                ),
              ),
            ],
          ),
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
                          final name =
                              authController.categories[id] ??
                              l10n.categoryFallback(id);
                          return Chip(
                            label: Text(name),
                            onDeleted: () {
                              setState(() => _selectedCategoryIds.remove(id));
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Question> questions;
  final void Function(Question) onQuestionTap;

  const CategorySection({
    super.key,
    required this.categoryName,
    required this.questions,
    required this.onQuestionTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    categoryName == uncategorizedFallback
                        ? l10n.uncategorized
                        : categoryName,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...questions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QuestionCard(
                question: question,
                onTap: () => onQuestionTap(question),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onTap;

  const QuestionCard({super.key, required this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.help_outline,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  question.text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: colorScheme.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A widget that displays voting statistics for a question.
///
/// Uses a tabbed layout to support multiple views of the statistics.
/// Currently only shows an "Overall" tab with vote counts and percentages.
/// Gender-specific statistics data.
class GenderStats {
  final String gender;
  final String label;
  final List<AnswerStats> stats;
  final bool isLoading;
  final String? errorMessage;

  GenderStats({
    required this.gender,
    required this.label,
    required this.stats,
    required this.isLoading,
    this.errorMessage,
  });
}

/// Distinct colors for answer bars — cycles through the list.
const List<Color> _answerColors = [
  Color(0xFF6750A4), // Purple
  Color(0xFF0061A4), // Blue
  Color(0xFF006E60), // Teal
  Color(0xFF7D5260), // Rose
  Color(0xFF8C4A60), // Mauve
  Color(0xFF4C662B), // Green
  Color(0xFF8B6914), // Gold
  Color(0xFF984061), // Crimson
];

class QuestionStatsWidget extends StatefulWidget {
  final List<AnswerStats> stats;
  final bool isLoading;
  final String? errorMessage;
  final List<GenderStats> genderStats;

  const QuestionStatsWidget({
    super.key,
    required this.stats,
    required this.isLoading,
    this.errorMessage,
    required this.genderStats,
  });

  @override
  State<QuestionStatsWidget> createState() => _QuestionStatsWidgetState();
}

class _QuestionStatsWidgetState extends State<QuestionStatsWidget>
    with TickerProviderStateMixin {
  int _selectedView = 0; // 0 = bars, 1 = donut, 2 = gender
  int _selectedGenderIndex = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalVotes = widget.stats.fold<int>(0, (sum, s) => sum + s.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with total votes and view toggle
        Row(
          children: [
            Expanded(child: _TotalVotesBadge(totalVotes: totalVotes)),
            const SizedBox(width: 12),
            _ViewToggle(
              selectedIndex: _selectedView,
              onSelected: (index) {
                setState(() => _selectedView = index);
                _animController.reset();
                _animController.forward();
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Content area
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildContent(colorScheme),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    switch (_selectedView) {
      case 0:
        return _buildBarChart(colorScheme);
      case 1:
        return _buildDonutChart(colorScheme);
      case 2:
        return _buildGenderComparison(colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Bar Chart View ──────────────────────────────────────────────

  Widget _buildBarChart(ColorScheme colorScheme) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.errorMessage != null) {
      return _buildError(widget.errorMessage!, colorScheme);
    }
    if (widget.stats.isEmpty) {
      return _buildEmpty(colorScheme);
    }

    final sorted = List<AnswerStats>.from(widget.stats)
      ..sort((a, b) => b.count.compareTo(a.count));
    final maxCount = sorted.first.count;

    return Column(
      children: [
        // Legend
        _buildLegend(colorScheme, sorted),
        const SizedBox(height: 16),
        // Bars
        ...List.generate(sorted.length, (index) {
          final stat = sorted[index];
          return _AnimatedBar(
            stat: stat,
            color: _answerColors[index % _answerColors.length],
            maxCount: maxCount,
            isWinner: index == 0 && stat.count > 0,
            delay: Duration(milliseconds: index * 80),
          );
        }),
      ],
    );
  }

  // ─── Donut Chart View ────────────────────────────────────────────

  Widget _buildDonutChart(ColorScheme colorScheme) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.errorMessage != null) {
      return _buildError(widget.errorMessage!, colorScheme);
    }
    if (widget.stats.isEmpty) {
      return _buildEmpty(colorScheme);
    }

    final sorted = List<AnswerStats>.from(widget.stats)
      ..sort((a, b) => b.count.compareTo(a.count));

    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 160,
            height: 160,
            child: _DonutChart(stats: sorted, colors: _answerColors),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(colorScheme, sorted),
      ],
    );
  }

  // ─── Gender Comparison View ──────────────────────────────────────

  Widget _buildGenderComparison(ColorScheme colorScheme) {
    final allLoading = widget.genderStats.every((g) => g.isLoading);
    if (allLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        // Gender selector chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(widget.genderStats.length, (index) {
              final g = widget.genderStats[index];
              final isSelected = _selectedGenderIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g.label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedGenderIndex = index);
                  },
                  selectedColor: colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        // Selected gender stats
        if (_selectedGenderIndex < widget.genderStats.length)
          _buildGenderStatsForIndex(colorScheme, _selectedGenderIndex),
      ],
    );
  }

  Widget _buildGenderStatsForIndex(ColorScheme colorScheme, int index) {
    final l10n = AppLocalizations.of(context);
    final g = widget.genderStats[index];
    if (g.isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (g.errorMessage != null) {
      return _buildError(g.errorMessage!, colorScheme);
    }
    if (g.stats.isEmpty) {
      return _buildEmpty(colorScheme);
    }

    final sorted = List<AnswerStats>.from(g.stats)
      ..sort((a, b) => b.count.compareTo(a.count));
    final totalVotes = g.stats.fold<int>(0, (sum, s) => sum + s.count);
    final maxCount = sorted.first.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.votesCount(totalVotes),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ...List.generate(sorted.length, (i) {
          final stat = sorted[i];
          return _AnimatedBar(
            stat: stat,
            color: _answerColors[i % _answerColors.length],
            maxCount: maxCount,
            isWinner: false,
            delay: Duration(milliseconds: i * 60),
          );
        }),
      ],
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────

  Widget _buildLegend(ColorScheme colorScheme, List<AnswerStats> sorted) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: List.generate(sorted.length, (index) {
        final stat = sorted[index];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _answerColors[index % _answerColors.length],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              stat.answerText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildError(String message, ColorScheme colorScheme) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 28),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noVotesYet,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Total Votes Badge ─────────────────────────────────────────────

class _TotalVotesBadge extends StatelessWidget {
  final int totalVotes;

  const _TotalVotesBadge({required this.totalVotes});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_vote, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            l10n.totalVotes(totalVotes),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── View Toggle (Segmented Button style) ──────────────────────────

class _ViewToggle extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ViewToggle({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final icons = [Icons.bar_chart, Icons.donut_large, Icons.people_outline];
    final tooltips = [l10n.viewBars, l10n.viewDonut, l10n.viewGender];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(icons.length, (index) {
          final isSelected = selectedIndex == index;
          return Tooltip(
            message: tooltips[index],
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icons[index],
                  size: 18,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Animated Bar ──────────────────────────────────────────────────

class _AnimatedBar extends StatefulWidget {
  final AnswerStats stat;
  final Color color;
  final int maxCount;
  final bool isWinner;
  final Duration delay;

  const _AnimatedBar({
    required this.stat,
    required this.color,
    required this.maxCount,
    required this.isWinner,
    required this.delay,
  });

  @override
  State<_AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<_AnimatedBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _barAnimation;
  late Animation<double> _percentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _barAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _percentAnimation = Tween<double>(
      begin: 0,
      end: widget.stat.percent,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fraction = widget.maxCount > 0
        ? widget.stat.count / widget.maxCount
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              if (widget.isWinner) ...[
                Icon(Icons.emoji_events, size: 16, color: widget.color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  widget.stat.answerText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: widget.isWinner
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _percentAnimation,
                builder: (context, _) {
                  return Text(
                    '${widget.stat.count} (${_percentAnimation.value.toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Bar track
          AnimatedBuilder(
            animation: _barAnimation,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Filled portion with gradient
                    FractionallySizedBox(
                      widthFactor: fraction * _barAnimation.value,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [
                              widget.color,
                              widget.color.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: widget.isWinner
                              ? [
                                  BoxShadow(
                                    color: widget.color.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Donut Chart (Custom Painter) ──────────────────────────────────

class _DonutChart extends StatelessWidget {
  final List<AnswerStats> stats;
  final List<Color> colors;

  const _DonutChart({required this.stats, required this.colors});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final total = stats.fold<int>(0, (sum, s) => sum + s.count);

    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _DonutChartPainter(
              stats: stats,
              colors: colors,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.4,
              ),
              textColor: colorScheme.onSurface,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.votesNoun,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<AnswerStats> stats;
  final List<Color> colors;
  final Color backgroundColor;
  final Color textColor;

  _DonutChartPainter({
    required this.stats,
    required this.colors,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = stats.fold<int>(0, (sum, s) => sum + s.count);
    if (total == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.32;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Segments
    double startAngle = -3.14159 / 2; // Start at top
    for (int i = 0; i < stats.length; i++) {
      final sweepAngle = (stats[i].count / total) * 2 * 3.14159;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

class QuestionDetailsPage extends StatefulWidget {
  final Question question;

  const QuestionDetailsPage({super.key, required this.question});

  @override
  State<QuestionDetailsPage> createState() => _QuestionDetailsPageState();
}

class _QuestionDetailsPageState extends State<QuestionDetailsPage> {
  final AuthMiddleware _authMiddleware = AuthMiddleware();
  List<AnswerOption> _answers = [];
  String? _errorMessage;
  bool _isLoading = true;
  final Set<int> _submittingAnswerIds = {};
  final Set<int> _votedAnswerIds = {};

  // Statistics state
  List<AnswerStats> _stats = [];
  bool _isLoadingStats = true;
  String? _statsErrorMessage;

  // Gender-resolved statistics state
  final List<String> _genders = ['m', 'f', 'd'];
  final Map<String, List<AnswerStats>> _genderStats = {};
  final Map<String, bool> _genderLoading = {};
  final Map<String, String?> _genderErrors = {};

  @override
  void initState() {
    super.initState();
    // Defer the initial fetches until after the first frame is built so the
    // build context can depend on inherited widgets such as `AppLocalizations`.
    // Accessing `AppLocalizations.of(context)` from `initState` directly throws
    // because inherited widgets are not yet available at that point.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchAnswers();
      _fetchStats();
      for (final gender in _genders) {
        _fetchStatsForGender(gender);
      }
    });
  }

  Future<void> _fetchAnswers() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authMiddleware.get(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/answers',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];
        setState(() {
          _answers = data
              .map((e) => AnswerOption.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          context.read<AuthController>().logout();
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = l10n.questionNotFound;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = l10n.serverError;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = l10n.connectionError(e.toString());
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStats() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoadingStats = true;
      _statsErrorMessage = null;
    });

    try {
      final response = await _authMiddleware.get(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/stats',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];
        setState(() {
          _stats = data
              .map((e) => AnswerStats.fromJson(e as Map<String, dynamic>))
              .toList();
          _isLoadingStats = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          context.read<AuthController>().logout();
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _statsErrorMessage = l10n.statsNotAvailable;
          _isLoadingStats = false;
        });
      } else {
        setState(() {
          _statsErrorMessage = l10n.statsLoadFailed;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      setState(() {
        _statsErrorMessage = l10n.connectionError(e.toString());
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _fetchStatsForGender(String gender) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _genderLoading[gender] = true;
      _genderErrors[gender] = null;
    });

    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/stats',
      ).replace(queryParameters: {'tagKey': 'gender', 'tagValue': gender});
      final response = await _authMiddleware.get(uri.toString());

      if (response.statusCode == 200) {
        final List<dynamic> data =
            (jsonDecode(response.body) as List?) ?? <dynamic>[];
        setState(() {
          _genderStats[gender] = data
              .map((e) => AnswerStats.fromJson(e as Map<String, dynamic>))
              .toList();
          _genderLoading[gender] = false;
        });
      } else if (response.statusCode == 401) {
        if (mounted) {
          context.read<AuthController>().logout();
        }
      } else if (response.statusCode == 404) {
        setState(() {
          _genderErrors[gender] = l10n.statsNotAvailable;
          _genderLoading[gender] = false;
        });
      } else {
        setState(() {
          _genderErrors[gender] = l10n.statsLoadFailed;
          _genderLoading[gender] = false;
        });
      }
    } catch (e) {
      setState(() {
        _genderErrors[gender] = l10n.connectionError(e.toString());
        _genderLoading[gender] = false;
      });
    }
  }

  Future<void> _submitAnswer(AnswerOption answer) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submittingAnswerIds.add(answer.id);
    });

    try {
      final authController = context.read<AuthController>();

      // Build tags from user demographic data
      final tags = <String, String>{};
      if (authController.birthYear != null) {
        tags['birth_year'] = authController.birthYear.toString();
      }
      if (authController.gender != null) {
        tags['gender'] = authController.gender!;
      }
      if (authController.nationality != null) {
        tags['nationality'] = authController.nationality!;
      }

      // The new endpoint encodes the question id in the path and expects a
      // JSON object for `tags` (the backend validates `tags` with `isObject`).
      final body = jsonEncode({
        'answer_id': answer.id,
        if (tags.isNotEmpty) 'tags': tags,
      });

      final response = await _authMiddleware.post(
        '${ApiConfig.baseUrl}/questions/${widget.question.id}/answer',
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _submittingAnswerIds.remove(answer.id);
          _votedAnswerIds.add(answer.id);
        });
        // Refresh statistics to reflect the new vote
        _fetchStats();
        for (final gender in _genders) {
          _fetchStatsForGender(gender);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.voteSubmitted(answer.text)),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.statusCode == 409) {
        // The backend enforces "one answer per user" and returns 409 when the
        // question has already been answered. The clicked option must NOT be
        // highlighted as voted: the vote was not recorded and the chosen
        // option may not even be the one previously submitted. Just clear the
        // submitting state and inform the user.
        setState(() {
          _submittingAnswerIds.remove(answer.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.alreadyAnswered),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.statusCode == 401) {
        context.read<AuthController>().logout();
      } else {
        setState(() {
          _submittingAnswerIds.remove(answer.id);
        });
        final errorMessage = response.body.isNotEmpty
            ? response.body.toString()
            : l10n.serverError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorWithMessage(errorMessage)),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submittingAnswerIds.remove(answer.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.voteSubmitFailed(e.toString())),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.questionDetailsTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        color: colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        l10n.questionLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.question.text,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Answers section
            Text(
              l10n.possibleAnswers,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              )
            else if (_answers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.noAnswersAvailable,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._answers.map((answer) {
                final isSubmitting = _submittingAnswerIds.contains(answer.id);
                final isVoted = _votedAnswerIds.contains(answer.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: isSubmitting || isVoted
                          ? null
                          : () => _submitAnswer(answer),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isVoted
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.4,
                                )
                              : colorScheme.surface,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isVoted
                                    ? colorScheme.primary
                                    : colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    )
                                  : Icon(
                                      isVoted
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline,
                                      color: isVoted
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSecondaryContainer,
                                      size: 20,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                answer.text,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Icon(
                              isVoted
                                  ? Icons.how_to_vote
                                  : Icons.how_to_vote_outlined,
                              color: isVoted
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),

            // Statistics section
            Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.statistics,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              color: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: QuestionStatsWidget(
                  stats: _stats,
                  isLoading: _isLoadingStats,
                  errorMessage: _statsErrorMessage,
                  genderStats: _genders.map((gender) {
                    return GenderStats(
                      gender: gender,
                      label: gender == 'm'
                          ? l10n.genderMale
                          : gender == 'f'
                          ? l10n.genderFemale
                          : l10n.genderDiverse,
                      stats: _genderStats[gender] ?? [],
                      isLoading: _genderLoading[gender] ?? true,
                      errorMessage: _genderErrors[gender],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog that displays the currently logged-in user's profile details
/// (username, email, birth year, gender and nationality) and lets the user
/// edit the modifiable fields (email, gender and password) via `PATCH /me`.
///
/// Admin users additionally see their administrator status, which is hidden
/// from non-admin users.
class UserDetailsDialog extends StatefulWidget {
  const UserDetailsDialog({super.key, required this.authController});

  final AuthController authController;

  @override
  State<UserDetailsDialog> createState() => _UserDetailsDialogState();
}

class _UserDetailsDialogState extends State<UserDetailsDialog> {
  // Created once so the `/me` request is not re-issued on every rebuild
  // (e.g. when the controller notifies listeners).
  late final Future<bool> _detailsFuture;

  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _gender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _detailsFuture = widget.authController.loadUserDetails();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Switches the dialog into edit mode, pre-filling the fields with the
  /// currently stored values.
  void _startEditing() {
    final auth = widget.authController;
    _emailController.text = auth.email ?? '';
    _gender = const ['m', 'w', 'd'].contains(auth.gender) ? auth.gender : null;
    _passwordController.clear();
    _confirmPasswordController.clear();
    widget.authController.clearError();
    setState(() => _isEditing = true);
  }

  /// Validates the form and persists the changes through the auth controller.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text;
    final request = UpdateUserRequest(
      email: _emailController.text.trim(),
      gender: _gender,
      password: password.isEmpty ? null : password,
    );

    final success = await widget.authController.updateUser(request);
    if (success && mounted) {
      widget.authController.clearError();
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileUpdateSuccess),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<bool>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AlertDialog(
            content: SizedBox(
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        final auth = widget.authController;
        final notAvailable = l10n.notAvailable;

        final genderText = auth.gender == null
            ? notAvailable
            : switch (auth.gender!) {
                'm' => l10n.genderMale,
                'w' => l10n.genderFemale,
                'd' => l10n.genderDiverse,
                _ => auth.gender!,
              };

        Widget detailRow(IconData icon, String label, String value) {
          final theme = Theme.of(context);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(value, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (_isEditing) {
          return AlertDialog(
            title: Text(l10n.editUserDetailsTitle),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (auth.isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Chip(
                          avatar: const Icon(
                            Icons.admin_panel_settings,
                            size: 18,
                          ),
                          label: Text(l10n.isAdminLabel),
                        ),
                      ),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.emailRequired;
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return l10n.emailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: InputDecoration(
                        labelText: l10n.genderLabel,
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'm',
                          child: Text(l10n.genderMale),
                        ),
                        DropdownMenuItem(
                          value: 'w',
                          child: Text(l10n.genderFemale),
                        ),
                        DropdownMenuItem(
                          value: 'd',
                          child: Text(l10n.genderDiverse),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _gender = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.newPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (value.length < 8) {
                          return l10n.passwordChangeMinLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: l10n.newPasswordConfirmLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      validator: (value) {
                        if (_passwordController.text.isNotEmpty &&
                            value != _passwordController.text) {
                          return l10n.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer<AuthController>(
                      builder: (context, authCtl, _) {
                        if (authCtl.error == null) {
                          return const SizedBox.shrink();
                        }
                        final colorScheme = Theme.of(context).colorScheme;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  localizedAuthError(l10n, authCtl.error),
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  widget.authController.clearError();
                  setState(() => _isEditing = false);
                },
                child: Text(l10n.cancel),
              ),
              Consumer<AuthController>(
                builder: (context, authCtl, _) => FilledButton(
                  onPressed: authCtl.isLoading ? null : _save,
                  child: authCtl.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(l10n.userDetailsTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                detailRow(
                  Icons.person_outline,
                  l10n.usernameLabel,
                  auth.username ?? notAvailable,
                ),
                detailRow(
                  Icons.email_outlined,
                  l10n.emailLabel,
                  auth.email ?? notAvailable,
                ),
                detailRow(
                  Icons.cake_outlined,
                  l10n.birthYearLabel,
                  auth.birthYear?.toString() ?? notAvailable,
                ),
                detailRow(Icons.transgender, l10n.genderLabel, genderText),
                detailRow(
                  Icons.flag_outlined,
                  l10n.nationalityLabel,
                  auth.nationality ?? notAvailable,
                ),
                if (auth.isAdmin)
                  detailRow(
                    Icons.admin_panel_settings,
                    l10n.isAdminLabel,
                    l10n.yes,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
            FilledButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.edit),
            ),
          ],
        );
      },
    );
  }
}
