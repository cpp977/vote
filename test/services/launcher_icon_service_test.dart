import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/configuration_controller.dart';
import 'package:vote/services/launcher_icon_service.dart';

/// The launcher icon densities Android rasterizes mipmaps for, as named by
/// the `mipmap-<density>` folders.
const List<String> _densities = <String>[
  'mdpi',
  'hdpi',
  'xhdpi',
  'xxhdpi',
  'xxxhdpi',
];

/// Returns [color] as the upper-case `RRGGBB` the generated drawables spell it
/// out in.
String _rgb(Color color) {
  final int value = color.toARGB32();
  return (value & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LauncherIconService', () {
    test('declares exactly the aliases present in the Android manifest', () {
      expect(LauncherIconService.availableAliases, <String>[
        'com.dev.vote.ic_launcher_deep_purple',
        'com.dev.vote.ic_launcher_blue',
        'com.dev.vote.ic_launcher_teal',
        'com.dev.vote.ic_launcher_green',
        'com.dev.vote.ic_launcher_orange',
        'com.dev.vote.ic_launcher_red',
        'com.dev.vote.ic_launcher_pink',
        'com.dev.vote.ic_launcher_cyan',
        'com.dev.vote.ic_launcher_indigo',
        'com.dev.vote.ic_launcher_amber',
      ]);
    });

    test('gives every icon a distinct background and glyph', () {
      final Set<int> backgrounds = <int>{};
      final Set<int> foregrounds = <int>{};

      for (final LauncherIcon icon in LauncherIconService.icons) {
        backgrounds.add(icon.background.toARGB32());
        foregrounds.add(icon.foreground.toARGB32());
      }

      expect(backgrounds, hasLength(LauncherIconService.icons.length));
      expect(foregrounds, hasLength(LauncherIconService.icons.length));
    });

    test('ships the resources each alias points at', () {
      final String res = 'android/app/src/main/res';
      final String manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        RegExp(r'android:name="\.ic_launcher_(\w+)"').allMatches(manifest),
        hasLength(LauncherIconService.icons.length),
        reason: 'every icon needs an activity-alias in the manifest',
      );

      for (final LauncherIcon icon in LauncherIconService.icons) {
        final List<File> required = <File>[
          // Adaptive icon plus the background color it draws.
          File('$res/mipmap-anydpi-v26/ic_launcher_${icon.id}.xml'),
          File('$res/drawable/ic_launcher_background_${icon.id}.xml'),
          // Legacy square icon and adaptive foreground, per density.
          for (final String density in _densities) ...<File>[
            File('$res/mipmap-$density/ic_launcher_${icon.id}.png'),
            File('$res/mipmap-$density/ic_launcher_foreground_${icon.id}.png'),
          ],
        ];

        for (final File asset in required) {
          expect(
            asset.existsSync(),
            isTrue,
            reason:
                'missing ${asset.path}; run '
                'python3 tool/generate_launcher_icons.py',
          );
          expect(asset.lengthSync(), isPositive, reason: 'empty ${asset.path}');
        }
      }
    });

    test('draws every background drawable in its own color', () {
      const String drawables = 'android/app/src/main/res/drawable';

      for (final LauncherIcon icon in LauncherIconService.icons) {
        final String xml = File(
          '$drawables/ic_launcher_background_${icon.id}.xml',
        ).readAsStringSync();

        expect(
          xml,
          contains('#${_rgb(icon.background)}'),
          reason: '${icon.id} does not use its own background color',
        );
      }
    });

    test('resolves an alias and an id back to the same icon', () {
      const LauncherIcon icon = LauncherIconService.defaultIcon;

      expect(LauncherIconService.iconForAlias(icon.alias), same(icon));
      expect(LauncherIconService.iconForId(icon.id), same(icon));
    });

    test('resolves unknown aliases and ids to null', () {
      expect(
        LauncherIconService.iconForAlias('com.dev.vote.ic_launcher_nope'),
        isNull,
      );
      expect(LauncherIconService.iconForId('nope'), isNull);
    });

    test('setter and getter are no-ops without a platform channel', () async {
      // Widget tests run on the host VM, where the channel has no native
      // implementation. The calls must complete instead of throwing
      // MissingPluginException.
      await expectLater(
        LauncherIconService.setLauncherIcon(LauncherIconService.icons[1].alias),
        completes,
      );
      await expectLater(LauncherIconService.getLauncherIcon(), completes);
    });

    test('ignores aliases it does not know about', () async {
      await expectLater(
        LauncherIconService.setLauncherIcon('com.dev.vote.no_such_icon'),
        completes,
      );
    });
  });

  group('launcher icon setting', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to the deep purple icon', () {
      final ConfigurationController controller = ConfigurationController();

      expect(controller.launcherIcon, LauncherIconService.defaultIcon);
    });

    test('is independent of the seed color', () async {
      final ConfigurationController controller = ConfigurationController();

      await controller.setSeedColor(Colors.blue);

      expect(controller.seedColor, Colors.blue);
      expect(controller.launcherIcon, LauncherIconService.defaultIcon);
    });

    test('changing the icon leaves the seed color alone', () async {
      final ConfigurationController controller = ConfigurationController(
        initialSeedColor: Colors.teal,
      );
      final LauncherIcon green = LauncherIconService.icons[3];

      await controller.setLauncherIcon(green);

      expect(controller.launcherIcon, same(green));
      expect(controller.seedColor, Colors.teal);
    });

    test('persists the picked icon by id', () async {
      final ConfigurationController controller = ConfigurationController();
      final LauncherIcon amber = LauncherIconService.icons[9];

      await controller.setLauncherIcon(amber);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('launcher_icon'), amber.id);
    });

    test('notifies once per change and stays quiet when unchanged', () async {
      final ConfigurationController controller = ConfigurationController();
      int notifications = 0;
      controller.addListener(() => notifications++);
      final LauncherIcon teal = LauncherIconService.icons[2];

      await controller.setLauncherIcon(teal);
      expect(notifications, 1);

      await controller.setLauncherIcon(teal);
      expect(notifications, 1);
    });

    test('offers one entry per shipped icon', () {
      final ConfigurationController controller = ConfigurationController();

      expect(
        controller.availableLauncherIcons,
        same(LauncherIconService.icons),
      );
    });

    test('reflects an icon restored from the constructor', () {
      final ConfigurationController controller = ConfigurationController(
        initialLauncherIcon: LauncherIconService.icons[5],
      );

      expect(controller.launcherIcon, LauncherIconService.icons[5]);
    });

    test('restores the persisted icon', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'launcher_icon': 'cyan',
      });
      final ConfigurationController controller = ConfigurationController();

      await controller.loadSavedConfiguration();

      expect(controller.launcherIcon, LauncherIconService.icons[7]);
    });

    test(
      'falls back to the default for an icon that is no longer shipped',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'launcher_icon': 'chartreuse',
        });
        final ConfigurationController controller = ConfigurationController();

        await controller.loadSavedConfiguration();

        expect(controller.launcherIcon, LauncherIconService.defaultIcon);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('launcher_icon'), isNull);
      },
    );

    test('restores the seed color without touching the icon', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'theme_seed_color': Colors.orange.toARGB32(),
      });
      final ConfigurationController controller = ConfigurationController();

      await controller.loadSavedConfiguration();

      // `Colors.orange` is a MaterialColor, whose identity differs from the
      // plain Color the controller rebuilds from the stored value.
      expect(controller.seedColor, Color(Colors.orange.toARGB32()));
      expect(controller.launcherIcon, LauncherIconService.defaultIcon);
    });
  });
}
