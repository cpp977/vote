import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/configuration_controller.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/services/launcher_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigurationController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('defaults', () {
      test('use deep purple seed color and system theme mode', () {
        final ConfigurationController controller = ConfigurationController();

        expect(controller.seedColor, Colors.deepPurple);
        expect(controller.themeMode, ThemeMode.system);
      });

      test('can be overridden via constructor arguments', () {
        final ConfigurationController controller = ConfigurationController(
          initialSeedColor: Colors.teal,
          initialThemeMode: ThemeMode.light,
        );

        expect(controller.seedColor, Colors.teal);
        expect(controller.themeMode, ThemeMode.light);
      });
    });

    group('setSeedColor', () {
      test('updates the seed color and notifies listeners', () async {
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.setSeedColor(Colors.teal);

        expect(controller.seedColor, Colors.teal);
        expect(notifications, 1);
      });

      test('persists the seed color', () async {
        final ConfigurationController controller = ConfigurationController();

        await controller.setSeedColor(Colors.teal);

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('theme_seed_color'), Colors.teal.toARGB32());
      });

      test('does not notify when the seed color is unchanged', () async {
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.setSeedColor(Colors.deepPurple);

        expect(notifications, 0);
      });
    });

    group('setThemeMode', () {
      test('updates the theme mode and notifies listeners', () async {
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.setThemeMode(ThemeMode.dark);

        expect(controller.themeMode, ThemeMode.dark);
        expect(notifications, 1);
      });

      test('persists the theme mode by name', () async {
        final ConfigurationController controller = ConfigurationController();

        await controller.setThemeMode(ThemeMode.dark);

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('theme_mode'), ThemeMode.dark.name);
      });

      test('does not notify when the theme mode is unchanged', () async {
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.setThemeMode(ThemeMode.system);

        expect(notifications, 0);
      });
    });

    group('setLocale', () {
      test('defaults to null so the system locale is used', () {
        final ConfigurationController controller = ConfigurationController();

        expect(controller.locale, isNull);
      });

      test('updates the locale and notifies listeners', () async {
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.setLocale(const Locale('de'));

        expect(controller.locale, const Locale('de'));
        expect(notifications, 1);
      });

      test('persists the language code', () async {
        final ConfigurationController controller = ConfigurationController();

        await controller.setLocale(const Locale('de'));

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('locale'), 'de');
      });

      test(
        'removes the stored value when resetting to the system locale',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'locale': 'de',
          });
          final ConfigurationController controller = ConfigurationController(
            initialLocale: const Locale('de'),
          );
          int notifications = 0;
          controller.addListener(() => notifications++);

          await controller.setLocale(null);

          expect(controller.locale, isNull);
          expect(notifications, 1);
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('locale'), isNull);
        },
      );

      test('does not notify when the locale is unchanged', () async {
        final ConfigurationController controller = ConfigurationController(
          initialLocale: const Locale('de'),
        );
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.setLocale(const Locale('de'));

        expect(notifications, 0);
      });
    });

    group('currentLanguageCode', () {
      setUp(() {
        ConfigurationController.resetAppConfiguration();
      });
      tearDown(() {
        ConfigurationController.resetAppConfiguration();
      });

      test('falls back to the platform locale when nothing is registered', () {
        expect(ConfigurationController.currentLanguageCode, 'en');
      });

      test('uses the language of a registered instance with a selection', () {
        final ConfigurationController controller = ConfigurationController(
          initialLocale: const Locale('de'),
        )..registerAsAppConfiguration();

        expect(ConfigurationController.currentLanguageCode, 'de');
        // The instance itself is not leaked into the assertion; only its
        // registered state matters.
        expect(controller.locale, const Locale('de'));
      });

      test('falls back to the platform locale for a registered instance '
          'without a selection', () {
        ConfigurationController().registerAsAppConfiguration();

        expect(ConfigurationController.currentLanguageCode, 'en');
      });
    });

    group('colorOptions and availableColors', () {
      test('offer one entry per available seed color', () {
        final ConfigurationController controller = ConfigurationController();

        final List<ColorOption> options = controller.colorOptions(_l10nStub());

        expect(
          options.map((ColorOption option) => option.color),
          controller.availableColors,
        );
        expect(options.map((ColorOption option) => option.name), _stubNames);
      });

      test('label every launcher icon', () {
        final ConfigurationController controller = ConfigurationController();

        final List<String> labels = LauncherIconService.icons
            .map(
              (LauncherIcon icon) => controller.iconLabel(_l10nStub(), icon.id),
            )
            .toList();

        expect(labels, _stubNames);
      });

      test('fall back to the id for an unknown launcher icon', () {
        final ConfigurationController controller = ConfigurationController();

        expect(controller.iconLabel(_l10nStub(), 'chartreuse'), 'chartreuse');
      });
    });

    group('loadSavedConfiguration', () {
      test('restores a persisted seed color and theme mode', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'theme_seed_color': Colors.green.toARGB32(),
          'theme_mode': ThemeMode.dark.name,
        });
        final ConfigurationController controller = ConfigurationController();

        await controller.loadSavedConfiguration();

        expect(controller.seedColor.toARGB32(), Colors.green.toARGB32());
        expect(controller.themeMode, ThemeMode.dark);
      });

      test(
        'notifies once when a stored value differs from the default',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'theme_mode': ThemeMode.dark.name,
          });
          final ConfigurationController controller = ConfigurationController();
          int notifications = 0;
          controller.addListener(() => notifications++);

          await controller.loadSavedConfiguration();

          expect(controller.themeMode, ThemeMode.dark);
          expect(notifications, 1);
        },
      );

      test(
        'falls back to the default for unknown stored theme modes',
        () async {
          SharedPreferences.setMockInitialValues(<String, Object>{
            'theme_mode': 'midnight',
          });
          final ConfigurationController controller = ConfigurationController();

          await controller.loadSavedConfiguration();

          expect(controller.themeMode, ThemeMode.system);
        },
      );

      test('keeps defaults and stays silent when storage is empty', () async {
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.loadSavedConfiguration();

        expect(controller.seedColor, Colors.deepPurple);
        expect(controller.themeMode, ThemeMode.system);
        expect(notifications, 0);
      });

      test('restores a persisted supported locale', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'locale': 'de',
        });
        final ConfigurationController controller = ConfigurationController();

        await controller.loadSavedConfiguration();

        expect(controller.locale, const Locale('de'));
      });

      test('ignores a persisted unsupported locale', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'locale': 'fr',
        });
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.loadSavedConfiguration();

        expect(controller.locale, isNull);
        expect(notifications, 0);
      });

      test('restores a persisted launcher icon', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'launcher_icon': 'cyan',
        });
        final ConfigurationController controller = ConfigurationController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.loadSavedConfiguration();

        expect(controller.launcherIcon.id, 'cyan');
        expect(notifications, 1);
      });

      test('does not derive the launcher icon from the seed color', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'theme_seed_color': Colors.amber.toARGB32(),
        });
        final ConfigurationController controller = ConfigurationController();

        await controller.loadSavedConfiguration();

        expect(
          controller.launcherIcon,
          LauncherIconService.defaultIcon,
          reason: 'the home screen icon is its own setting',
        );
      });
    });
  });
}

/// Names `_stubNames` returns, in the order the controller reads them.
const List<String> _stubNames = <String>[
  'color0',
  'color1',
  'color2',
  'color3',
  'color4',
  'color5',
  'color6',
  'color7',
  'color8',
  'color9',
];

/// A localizations instance whose color and icon names are predictable.
///
/// The real strings are translations a test must not duplicate, so every name
/// getter is answered from [_stubNames].
AppLocalizations _l10nStub() => _StubLocalizations();

/// Answers the color name getters of [AppLocalizations] from [_stubNames].
class _StubLocalizations implements AppLocalizations {
  @override
  String get colorDeepPurple => _stubNames[0];

  @override
  String get colorBlue => _stubNames[1];

  @override
  String get colorTeal => _stubNames[2];

  @override
  String get colorGreen => _stubNames[3];

  @override
  String get colorOrange => _stubNames[4];

  @override
  String get colorRed => _stubNames[5];

  @override
  String get colorPink => _stubNames[6];

  @override
  String get colorCyan => _stubNames[7];

  @override
  String get colorIndigo => _stubNames[8];

  @override
  String get colorAmber => _stubNames[9];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unexpected lookup: ${invocation.memberName}');
}
