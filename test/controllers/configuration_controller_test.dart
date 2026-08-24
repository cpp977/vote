import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/configuration_controller.dart';

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
    });
  });
}
