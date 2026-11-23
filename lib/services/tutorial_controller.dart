import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller for managing the first-run introduction state.
///
/// Holds whether the introduction carousel has already been shown and
/// notifies listeners when that flag changes. The flag is persisted via
/// [shared_preferences] so it survives app restarts; once completed the
/// intro is not shown again automatically, but it can be re-triggered from
/// the configuration menu (which pushes a dedicated route).
///
/// The tour is additionally versioned: [currentRevision] is bumped whenever
/// the carousel's pages change, and a completed intro whose stored revision
/// is older than [currentRevision] is shown again — starting at the first
/// page the user has not seen yet (see
/// `IntroCarousel.startPageForSeenRevision`). This makes the tour double as
/// a "what's new" mechanism without re-showing it on every app update.
class TutorialController extends ChangeNotifier {
  static const String _completedKey = 'tutorial_completed';
  static const String _revisionKey = 'tutorial_revision';

  /// Content revision of the introduction tour.
  ///
  /// Bumped whenever pages are added or changed: the tour then shows again
  /// once on the next launch, at the first page that is new to the user.
  static const int currentRevision = 2;

  bool _initialized = false;
  bool _completed = false;

  /// Revision of the tour the user last completed; `0` when never recorded.
  int _seenRevision = 0;

  /// Whether the persisted completion flag has been loaded from storage.
  ///
  /// Until this is `true` the controller is in an indeterminate "loading"
  /// state; UI that gates on the tutorial should render a splash instead of
  /// racing a premature decision.
  bool get isInitialized => _initialized;

  /// Whether the introduction has been shown in its current revision (and
  /// thus should not be displayed again automatically on launch).
  bool get isCompleted => _completed;

  /// Revision of the tour the user last completed (`0` when unknown).
  int get seenRevision => _seenRevision;

  /// The inverse of "seen in the current revision": `true` while the
  /// introduction should still be shown — either because it was never
  /// completed, or because the tour gained pages since the user last saw it.
  ///
  /// Only meaningful once [isInitialized] is `true`.
  bool get shouldShowTutorial => !_completed || _seenRevision < currentRevision;

  /// Loads the persisted completion flag and revision from storage.
  ///
  /// Safe to call multiple times; only the first call (from an
  /// uninitialized state) performs any work. A completed intro without a
  /// stored revision predates the revision tracking and counts as revision
  /// `1` (the original tour), so those users replay only the pages added
  /// since.
  Future<void> load() async {
    if (_initialized) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _completed = prefs.getBool(_completedKey) ?? false;
    final int? stored = prefs.getInt(_revisionKey);
    _seenRevision = stored ?? (_completed ? 1 : 0);
    _initialized = true;
    // Notify listeners so that any waiting gate widget rebuilds now that the
    // answer is known.
    notifyListeners();
  }

  /// Marks the introduction as completed (in the current [currentRevision])
  /// and persists the decision so it is not shown again until the tour
  /// changes.
  Future<void> complete() async {
    if (_completed && _seenRevision >= currentRevision) return;
    _completed = true;
    _seenRevision = currentRevision;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
    await prefs.setInt(_revisionKey, currentRevision);
  }

  /// Un-marks the introduction as completed, persisting the change so that
  /// the introduction will be shown again on the next launch (and can be
  /// re-triggered immediately from the configuration menu).
  Future<void> reset() async {
    if (!_completed) return;
    _completed = false;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, false);
  }
}
