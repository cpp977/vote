import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tutorial_controller.dart';
import '../l10n/app_localizations.dart';

/// A single page of the first-run introduction carousel.
///
/// [asset] is an optional illustration path (unused when the matching
/// image asset is absent — falls back to an [icon]). [icon] is always
/// provided as a fallback visual.
@immutable
class IntroPageData {
  const IntroPageData({
    required this.icon,
    required this.title,
    required this.description,
    this.asset,
  });

  final IconData icon;
  final String title;
  final String description;

  /// Optional illustration asset; when `null` the [icon] is shown instead.
  final String? asset;
}

/// A full-screen, swipeable introduction carousel shown the first time a user
/// opens the app and (re-)triggerable from the configuration menu.
///
/// The carousel explains the three core workflows of Vote4It — browsing and
/// voting on questions, inspecting the resulting statistics, and submitting
/// one's own questions — before handing control back to the caller via
/// [onComplete].
///
/// [onComplete] is invoked exactly once the user is ready to enter the app,
/// whether they tapped "Get Started" or "Skip". Marking the tutorial as
/// completed is the caller's responsibility (see [TutorialController.complete]).
class IntroCarousel extends StatefulWidget {
  /// Builds the page list from localized strings.
  static List<IntroPageData> pages(AppLocalizations l10n) => [
    IntroPageData(
      icon: Icons.rocket_launch_outlined,
      title: l10n.introWelcomeTitle(l10n.appName),
      description: l10n.introWelcomeDesc,
    ),
    IntroPageData(
      icon: Icons.how_to_vote_outlined,
      title: l10n.introVoteTitle,
      description: l10n.introVoteDesc,
    ),
    IntroPageData(
      icon: Icons.bar_chart_rounded,
      title: l10n.introStatsTitle,
      description: l10n.introStatsDesc,
    ),
    IntroPageData(
      icon: Icons.post_add_outlined,
      title: l10n.introSubmitTitle,
      description: l10n.introSubmitDesc,
    ),
  ];

  /// Called when the user finishes the carousel, either by tapping "Get
  /// Started" on the last page or by tapping "Skip" anywhere.
  final Future<void> Function() onComplete;

  const IntroCarousel({super.key, required this.onComplete});

  @override
  State<IntroCarousel> createState() => _IntroCarouselState();
}

class _IntroCarouselState extends State<IntroCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Builds the localized page list fresh on every build so a runtime locale
  /// change is reflected immediately.
  List<IntroPageData> _buildPages(AppLocalizations l10n) =>
      IntroCarousel.pages(l10n);

  Future<void> _advance() async {
    final pages = _buildPages(AppLocalizations.of(context));
    if (_currentPage < pages.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else {
      await _finish();
    }
  }

  /// Marks the tutorial as completed and hands control back to the caller.
  Future<void> _finish() async {
    if (_isCompleting) return;
    _isCompleting = true;
    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<IntroPageData> pages = _buildPages(l10n);
    final bool isLastPage = _currentPage == pages.length - 1;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Use a plain Material background so the carousel looks identical in
      // both light and dark mode without depending on the app's
      // inversePrimary AppBar tint.
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // --- Skip button -------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isCompleting ? null : _finish,
                  child: Text(l10n.introSkip),
                ),
              ),
            ),
            // --- Pages -------------------------------------------------------
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _IntroPage(data: pages[index], colorScheme: colorScheme),
              ),
            ),
            // --- Dots indicator ---------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _PageIndicator(
                count: pages.length,
                index: _currentPage,
                colorScheme: colorScheme,
              ),
            ),
            // --- Footer (Next / Get Started) --------------------------------
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isCompleting ? null : _advance,
                  child: _isCompleting && isLastPage
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          isLastPage ? l10n.introGetStarted : l10n.introNext,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One illustrated page of the carousel.
class _IntroPage extends StatelessWidget {
  final IntroPageData data;
  final ColorScheme colorScheme;

  const _IntroPage({required this.data, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    // The illustration occupies roughly the top third; the text follows.
    final double illustrationSize = screenWidth * 0.30;

    // The page content is wrapped in a scrollable, vertically-centered
    // column so it can never overflow the viewport on small (e.g. test)
    // screens: on a cramped device the illustration/text simply scroll into
    // view instead of triggering a RenderOverflow that would crash the
    // layout pass.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Illustration (asset image when available, otherwise an icon).
                    SizedBox(
                      width: illustrationSize,
                      height: illustrationSize,
                      child: data.asset != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(
                                illustrationSize / 2,
                              ),
                              child: Image.asset(
                                data.asset!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : CircleAvatar(
                              radius: illustrationSize / 2,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                data.icon,
                                size: illustrationSize / 2.2,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A row of dots indicating the current page.
class _PageIndicator extends StatelessWidget {
  final int count;
  final int index;
  final ColorScheme colorScheme;

  const _PageIndicator({
    required this.count,
    required this.index,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          width: isActive ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

/// A full-screen route that hosts [IntroCarousel] and marks the tutorial as
/// completed (idempotently) when the user is done, then pops the route.
///
/// Used by the configuration menu's "Show Introduction" entry so users can
/// re-watch the intro after the first run.
class IntroCarouselPage extends StatelessWidget {
  const IntroCarouselPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TutorialController tutorial = context.read<TutorialController>();
    return IntroCarousel(
      onComplete: () async {
        // Mark as completed for good measure (idempotent) and return to the
        // previous route.
        await tutorial.complete();
        if (context.mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
  }
}
