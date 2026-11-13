import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A launcher icon the user can pick, and the Android alias that provides it.
///
/// [id] is the suffix of the alias and of the generated mipmap resources (see
/// `tool/generate_launcher_icons.py`), so it must stay lowercase ASCII.
@immutable
class LauncherIcon {
  /// Creates a launcher icon option.
  const LauncherIcon(this.id, this.background, this.foreground);

  /// Resource suffix of the icon, e.g. `deep_purple`.
  final String id;

  /// The icon's background color, matching `ic_launcher_background_<id>`.
  final Color background;

  /// The glyph color drawn on [background], matching the generated
  /// `ic_launcher_foreground_<id>` asset.
  final Color foreground;

  /// The fully-qualified `<activity-alias>` name Android enables for this icon.
  String get alias => '${LauncherIconService._prefix}$id';

  @override
  String toString() => 'LauncherIcon($id)';
}

/// A service for interacting with the Android launcher icon.
///
/// The launcher icon is implemented via `<activity-alias>` entries in
/// AndroidManifest.xml. Each alias references a different set of mipmap
/// resources (a distinct drawable). Toggling the `android:enabled` state of
/// these aliases through [MethodChannel] makes Android swap the launcher
/// icon without requiring an app restart.
///
/// The set of icons is declared in [icons], which is the single source of
/// truth for what the user can pick: it drives the configuration menu and the
/// alias names. Adding an icon there additionally requires the generated
/// assets (`python3 tool/generate_launcher_icons.py`) and a matching
/// `<activity-alias>` in the manifest.
///
/// All calls are no-ops on platforms other than Android, including host
/// environments such as unit tests where the platform channel has no native
/// implementation.
class LauncherIconService {
  static const MethodChannel _channel = MethodChannel(
    'com.dev.vote/launcher_icons',
  );

  /// Package prefix shared by every `<activity-alias>` declared for an icon.
  static const String _prefix = 'com.dev.vote.ic_launcher_';

  /// The launcher icons the app ships, in the order they are offered.
  ///
  /// The colors mirror the Material 500 tone of the matching theme seed color
  /// so an icon reads as the theme it is named after, with a light tint of the
  /// same color as its glyph.
  static const List<LauncherIcon> icons = <LauncherIcon>[
    LauncherIcon('deep_purple', Color(0xFF673AB7), Color(0xFFEDE7F6)),
    LauncherIcon('blue', Color(0xFF2196F3), Color(0xFFE3F2FD)),
    LauncherIcon('teal', Color(0xFF009688), Color(0xFFE0F2F1)),
    LauncherIcon('green', Color(0xFF4CAF50), Color(0xFFE8F5E9)),
    LauncherIcon('orange', Color(0xFFFF9800), Color(0xFFFFF3E0)),
    LauncherIcon('red', Color(0xFFF44336), Color(0xFFFFEBEE)),
    LauncherIcon('pink', Color(0xFFE91E63), Color(0xFFFCE4EC)),
    LauncherIcon('cyan', Color(0xFF00BCD4), Color(0xFFE0F7FA)),
    LauncherIcon('indigo', Color(0xFF3F51B5), Color(0xFFE8EAF6)),
    LauncherIcon('amber', Color(0xFFFFC107), Color(0xFFFF8F00)),
  ];

  /// The icon used when the user has not picked one, or when a stored choice
  /// is no longer shipped.
  static const LauncherIcon defaultIcon = LauncherIcon(
    'deep_purple',
    Color(0xFF673AB7),
    Color(0xFFEDE7F6),
  );

  /// All known launcher icon alias names.
  static List<String> get availableAliases =>
      icons.map((LauncherIcon icon) => icon.alias).toList(growable: false);

  /// Returns the icon with [alias], or `null` when no icon uses it.
  static LauncherIcon? iconForAlias(String alias) {
    for (final LauncherIcon icon in icons) {
      if (icon.alias == alias) return icon;
    }
    return null;
  }

  /// Returns the icon identified by [id], or `null` for unknown ids.
  static LauncherIcon? iconForId(String id) {
    for (final LauncherIcon icon in icons) {
      if (icon.id == id) return icon;
    }
    return null;
  }

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
    if (!_isAndroid || !availableAliases.contains(alias)) return;
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
