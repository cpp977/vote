import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A service for interacting with the Android launcher icon.
///
/// The launcher icon is implemented via `<activity-alias>` entries in
/// AndroidManifest.xml. Each alias references a different set of mipmap
/// resources (a distinct drawable). Toggling the `android:enabled` state of
/// these aliases through [MethodChannel] makes Android swap the launcher
/// icon without requiring an app restart.
///
/// All calls are no-ops on platforms other than Android, including host
/// environments such as unit tests where the platform channel has no native
/// implementation.
class LauncherIconService {
  static const MethodChannel _channel = MethodChannel(
    'com.dev.vote/launcher_icons',
  );

  /// The fully-qualified alias name for the Deep Purple launcher icon.
  static const String aliasDeepPurple = 'com.dev.vote.ic_launcher_deep_purple';

  /// The fully-qualified alias name for the Blue launcher icon.
  static const String aliasBlue = 'com.dev.vote.ic_launcher_blue';

  /// The fully-qualified alias name for the Teal launcher icon.
  static const String aliasTeal = 'com.dev.vote.ic_launcher_teal';

  /// All known launcher icon alias names.
  static const List<String> _allAliases = <String>[
    aliasDeepPurple,
    aliasBlue,
    aliasTeal,
  ];

  /// All known launcher icon alias names, in display order.
  @visibleForTesting
  static List<String> get availableAliases =>
      List<String>.unmodifiable(_allAliases);

  /// Returns `true` when running on Android with a real platform channel.
  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sets the active launcher icon by enabling the corresponding activity
  /// alias and disabling all others.
  ///
  /// [alias] must be one of the known alias names. On non-Android platforms
  /// or in unit tests where the platform channel is unavailable, this is a
  /// no-op.
  static Future<void> setLauncherIcon(String alias) async {
    if (!_isAndroid || !_allAliases.contains(alias)) return;
    try {
      await _channel.invokeMethod<void>('setLauncherIcon', <String, String>{
        'alias': alias,
      });
    } on PlatformException catch (e) {
      debugPrint(
        'LauncherIconService: failed to set launcher icon: '
        '${e.message}',
      );
    } on MissingPluginException {
      // No native implementation (e.g. in unit tests); safe to ignore.
    }
  }

  /// Returns the currently active launcher icon alias, or `null` when the
  /// platform channel is unavailable or an error occurs.
  static Future<String?> getLauncherIcon() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getLauncherIcon');
    } on PlatformException catch (e) {
      debugPrint(
        'LauncherIconService: failed to get launcher icon: '
        '${e.message}',
      );
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
