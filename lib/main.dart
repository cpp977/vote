import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'controllers/auth_controller.dart';
import 'services/auth_middleware.dart';
import 'pages/login_page.dart';

void main() {
  runApp(const MyApp());
}

class Question {
  final int id;
  final String text;
  final int categoryId;
  final String categoryName;
  final String language;
  final int minAge;
  final String createdAt;

  Question({
    required this.id,
    required this.text,
    required this.categoryId,
    required this.categoryName,
    required this.language,
    required this.minAge,
    required this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      text: json['text'] as String,
      categoryId: json['category_id'] as int,
      categoryName: json['category_name'] as String? ?? 'Uncategorized',
      language: json['language'] as String? ?? 'en',
      minAge: json['min_age'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
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

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    debugPrint('Fetching questions...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final languageCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final preAuth = context.read<AuthController>();
    final preBirthYear = preAuth.birthYear;
    debugPrint('Fetching questions for language: $languageCode');

    try {
      final response = await _authMiddleware.get(
        'http://127.0.0.1:8848/questions/lang/$languageCode',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final currentYear = DateTime.now().year;
        final userAge = preBirthYear != null
            ? currentYear - preBirthYear
            : null;

        setState(() {
          _questions = data
              .map((e) => Question.fromJson(e as Map<String, dynamic>))
              .where((q) =>
                  userAge == null || q.minAge <= userAge)
              .toList();
          _isLoading = false;
        });
        debugPrint('Loaded ${_questions.length} questions');
      } else if (response.statusCode == 401) {
        // Token refresh failed, user needs to login again
        if (mounted) {
          context.read<AuthController>().logout();
        }
      } else {
        setState(() {
          _errorMessage = 'Server returned an error';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching questions: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to connect: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    final authController = context.read<AuthController>();
    await authController.logout();
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

  @override
  Widget build(BuildContext context) {
    final groupedQuestions = _groupQuestionsByCategory();
    final authController = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          // User menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                authController.username?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  authController.username ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _isLoading ? null : _fetchQuestions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
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
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedQuestions.length,
              itemBuilder: (context, index) {
                final categoryName = groupedQuestions.keys.elementAt(index);
                final questions = groupedQuestions[categoryName]!;
                return CategorySection(
                  categoryName: categoryName,
                  questions: questions,
                  onQuestionTap: _navigateToDetails,
                );
              },
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
                    categoryName,
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

class QuestionStatsWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            tabs: const [
              Tab(text: 'Overall'),
              Tab(text: 'By Gender'),
            ],
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: TabBarView(
              children: [
                _buildStatsTab(
                  context,
                  colorScheme,
                  stats,
                  isLoading,
                  errorMessage,
                ),
                _buildGenderTab(context, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderTab(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    if (genderStats.every((g) => g.isLoading)) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: genderStats.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: genderStats
                .map((g) => Tab(text: g.label))
                .toList(),
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: genderStats
                  .map((g) => _buildStatsTab(
                        context,
                        colorScheme,
                        g.stats,
                        g.isLoading,
                        g.errorMessage,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(
    BuildContext context,
    ColorScheme colorScheme,
    List<AnswerStats> stats,
    bool isLoading,
    String? errorMessage,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      final error = errorMessage;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (stats.isEmpty) {
      return Center(
        child: Text(
          'No votes yet.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    // Sort by count descending
    final sortedStats = List<AnswerStats>.from(stats)
      ..sort((a, b) => b.count.compareTo(a.count));

    return ListView.builder(
      itemCount: sortedStats.length,
      itemBuilder: (context, index) {
        final stat = sortedStats[index];
        return _StatRow(stat: stat);
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final AnswerStats stat;

  const _StatRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = stat.percent.clamp(0.0, 100.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  stat.answerText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${stat.count} vote${stat.count != 1 ? 's' : ''} (${percent.toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
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
    _fetchAnswers();
    _fetchStats();
    for (final gender in _genders) {
      _fetchStatsForGender(gender);
    }
  }

  Future<void> _fetchAnswers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authMiddleware.get(
        'http://127.0.0.1:8848/questions/${widget.question.id}/answers',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
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
          _errorMessage = 'Question not found';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Server returned an error';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to connect: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoadingStats = true;
      _statsErrorMessage = null;
    });

    try {
      final response = await _authMiddleware.get(
        'http://127.0.0.1:8848/questions/${widget.question.id}/stats',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
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
          _statsErrorMessage = 'Statistics not available';
          _isLoadingStats = false;
        });
      } else {
        setState(() {
          _statsErrorMessage = 'Failed to load statistics';
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      setState(() {
        _statsErrorMessage = 'Failed to connect: $e';
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _fetchStatsForGender(String gender) async {
    setState(() {
      _genderLoading[gender] = true;
      _genderErrors[gender] = null;
    });

    try {
      final uri = Uri.parse(
        'http://127.0.0.1:8848/questions/${widget.question.id}/stats',
      ).replace(queryParameters: {
        'tagKey': 'gender',
        'tagValue': gender,
      });
      final response = await _authMiddleware.get(uri.toString());

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
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
          _genderErrors[gender] = 'Statistics not available';
          _genderLoading[gender] = false;
        });
      } else {
        setState(() {
          _genderErrors[gender] = 'Failed to load statistics';
          _genderLoading[gender] = false;
        });
      }
    } catch (e) {
      setState(() {
        _genderErrors[gender] = 'Failed to connect: $e';
        _genderLoading[gender] = false;
      });
    }
  }

  Future<void> _submitAnswer(AnswerOption answer) async {
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

      final body = jsonEncode({
        'question_id': widget.question.id,
        'answer_id': answer.id,
        if (tags.isNotEmpty) 'tags': jsonEncode(tags),
      });

      final response = await _authMiddleware.post(
        'http://127.0.0.1:8848/useranswers',
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
            content: Text('Vote for "${answer.text}" submitted!'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
            ? response.body
            : 'Failed to submit vote';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
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
          content: Text('Failed to submit vote: $e'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Question Details'),
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
                        'Question',
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
              'Possible Answers',
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
                  'No answers available for this question.',
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
                              ? colorScheme.primaryContainer.withValues(alpha: 0.4)
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
                                      isVoted ? Icons.check_circle : Icons.check_circle_outline,
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
                              isVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined,
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
            Text(
              'Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QuestionStatsWidget(
                  stats: _stats,
                  isLoading: _isLoadingStats,
                  errorMessage: _statsErrorMessage,
                  genderStats: _genders.map((gender) {
                    return GenderStats(
                      gender: gender,
                      label: gender == 'm' ? 'Male' : gender == 'f' ? 'Female' : 'Diverse',
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
