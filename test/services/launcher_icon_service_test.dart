import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/configuration_controller.dart';
import 'package:vote/services/launcher_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LauncherIconService', () {
    test('declares exactly the aliases present in the Android manifest', () {
      expect(LauncherIconService.availableAliases, <String>[
        LauncherIconService.aliasDeepPurple,
        LauncherIconService.aliasBlue,
        LauncherIconService.aliasTeal,
      ]);
    });

    test('setter and getter are no-ops without a platform channel', () async {
      // Widget tests run on the host VM, where the channel has no native
      // implementation. The calls must complete instead of throwing
      // MissingPluginException.
      await expectLater(
        LauncherIconService.setLauncherIcon(LauncherIconService.aliasBlue),
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

  group('launcher icon selection', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('exposes one icon choice per distinct alias', () {
      final ConfigurationController controller = ConfigurationController();

      final List<ColorOption> icons = controller.availableLauncherIcons;

      expect(icons, hasLength(3));
      expect(
        icons.map((ColorOption o) => o.launcherIconAlias).toSet(),
        LauncherIconService.availableAliases.toSet(),
      );
    });

    test('defaults to the deep purple icon', () {
      final ConfigurationController controller = ConfigurationController();

      expect(
        controller.activeLauncherIconAlias,
        LauncherIconService.aliasDeepPurple,
      );
    });

    test('follows the seed color', () async {
      final ConfigurationController controller = ConfigurationController();

      await controller.setSeedColor(Colors.blue);

      expect(controller.activeLauncherIconAlias, LauncherIconService.aliasBlue);
    });

    test('falls back to the first icon for unmapped seed colors', () async {
      final ConfigurationController controller = ConfigurationController();

      await controller.setSeedColor(Colors.amber);

      expect(
        controller.activeLauncherIconAlias,
        LauncherIconService.aliasDeepPurple,
      );
    });

    test('reflects a seed color restored from the constructor', () {
      final ConfigurationController controller = ConfigurationController(
        initialSeedColor: Colors.teal,
      );

      expect(controller.activeLauncherIconAlias, LauncherIconService.aliasTeal);
    });

    test('reuses the closest icon for colors without a dedicated asset', () {
      final ConfigurationController controller = ConfigurationController();

      // Green has no dedicated asset and maps onto the teal icon.
      final ColorOption green = controller.availableColors.firstWhere(
        (ColorOption o) => o.name == 'Green',
      );

      expect(green.launcherIconAlias, LauncherIconService.aliasTeal);
    });
  });
}
