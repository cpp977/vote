import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller for managing the first-run introduction state.
///
/// Holds whether the introduction carousel has already been shown and
/// notifies listeners when that flag changes. The flag is persisted via
/// [shared_preferences] so it survives app restarts; once completed the
/// intro is not shown again automatically, but it can be re-triggered from
/// the configuration menu (which pushes a dedicated route).
class TutorialController extends ChangeNotifier {
  static const String _completedKey = 'tutorial_completed';

  bool _initialized = false;
  bool _completed = false;

  /// Whether the persisted completion flag has been loaded from storage.
  ///
  /// Until this is `true` the controller is in an indeterminate "loading"
  /// state; UI that gates on the tutorial should render a splash instead of
  /// racing a premature decision.
  bool get isInitialized => _initialized;

  /// Whether the introduction has already been shown (and thus should not be
  /// displayed again automatically on first launch).
  bool get isCompleted => _completed;

  /// The inverse of [isCompleted]: `true` while the introduction should
  /// still be shown, either because it was never completed or because the
  /// user explicitly reset it.
  ///
  /// Only meaningful once [isInitialized] is `true`.
  bool get shouldShowTutorial => !_completed;

  /// Loads the persisted completion flag from storage.
  ///
  /// Safe to call multiple times; only the first call (from an
  /// uninitialized state) performs any work.
  Future<void> load() async {
    if (_initialized) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _completed = prefs.getBool(_completedKey) ?? false;
    _initialized = true;
    // Notify listeners so that any waiting gate widget rebuilds now that the
    // answer is known.
    notifyListeners();
  }

  /// Marks the introduction as completed and persists the decision so it is
  /// not shown again on subsequent launches.
  Future<void> complete() async {
    if (_completed) return;
    _completed = true;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
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
