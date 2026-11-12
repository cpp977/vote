import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/controllers/configuration_controller.dart';
import 'package:vote/l10n/app_localizations.dart';
import 'package:vote/services/launcher_icon_service.dart';
import 'package:vote/widgets/configuration_menu.dart';

/// Method channel of `package_info_plus`, mocked so the About submenu can
/// render a version instead of a spinner.
const MethodChannel _packageInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/package_info',
);

/// Method channel of `url_launcher`, mocked so the privacy statement entry
/// runs against a platform that answers instead of the real one, which never
/// replies under the fake clock of a widget test.
const MethodChannel _urlLauncherChannel = MethodChannel(
  'plugins.flutter.io/url_launcher',
);

/// Marker text reported by [runWithVersionClient] for a backend that answered
/// an error status.
///
/// The status check inside the widget is unreachable from a test: the mock
/// client intercepts the request before the platform HTTP implementation
/// ever sees it, and `IOClient` rejects the development host, so both paths
/// end in the same catch branch.
const String _unavailable = 'unavailable';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_packageInfoChannel, null);
    messenger.setMockMethodCallHandler(_urlLauncherChannel, null);
  });

  group('top-level entries', () {
    testWidgets('lists the appearance and about sections', (tester) async {
      await pumpMenu(tester);

      await openMenu(tester);

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme Color'), findsOneWidget);
      expect(find.text('App Icon'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });
  });

  group('Theme Color', () {
    testWidgets('marks the current seed color with a check', (tester) async {
      await pumpMenu(tester, seedColor: Colors.red);

      await openSubMenu(tester, 'Theme Color');

      expect(isChecked(tester, 'Red'), isTrue);
      expect(isChecked(tester, 'Blue'), isFalse);
    });

    testWidgets('applies the picked color', (tester) async {
      final ConfigurationController controller = await pumpMenu(tester);

      await openSubMenu(tester, 'Theme Color');
      await tester.tap(find.text('Cyan'));
      await settlePersistence(tester);

      expect(controller.seedColor, Colors.cyan);
    });

    testWidgets('keeps the color when dismissed', (tester) async {
      final ConfigurationController controller = await pumpMenu(tester);

      await openSubMenu(tester, 'Theme Color');
      await dismissSubMenu(tester);

      expect(controller.seedColor, Colors.deepPurple);
    });
  });

  group('App Icon', () {
    testWidgets('lists one option per launcher icon', (tester) async {
      await pumpMenu(tester);

      await openSubMenu(tester, 'App Icon');

      // The icons are offered by the name of the theme color they belong to.
      expect(find.text('Deep Purple'), findsOneWidget);
      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Teal'), findsOneWidget);
      expect(find.text('Green'), findsNothing);
    });

    testWidgets('marks the icon matching the current seed color as active', (
      tester,
    ) async {
      await pumpMenu(tester, seedColor: Colors.blue);

      await openSubMenu(tester, 'App Icon');

      expect(isChecked(tester, 'Blue'), isTrue);
      expect(isChecked(tester, 'Deep Purple'), isFalse);
      expect(isChecked(tester, 'Teal'), isFalse);
    });

    testWidgets('picking an icon applies the matching seed color', (
      tester,
    ) async {
      final ConfigurationController controller = await pumpMenu(tester);

      expect(controller.seedColor, Colors.deepPurple);

      await openSubMenu(tester, 'App Icon');
      await tester.tap(find.text('Teal'));
      await settlePersistence(tester);

      expect(controller.seedColor, Colors.teal);
      expect(controller.activeLauncherIconAlias, LauncherIconService.aliasTeal);
    });

    testWidgets('keeps the icon when dismissed', (tester) async {
      final ConfigurationController controller = await pumpMenu(tester);

      await openSubMenu(tester, 'App Icon');
      await dismissSubMenu(tester);

      expect(
        controller.activeLauncherIconAlias,
        LauncherIconService.aliasDeepPurple,
      );
    });
  });

  group('View', () {
    testWidgets('marks the current theme mode', (tester) async {
      await pumpMenu(tester, themeMode: ThemeMode.dark);

      await openSubMenu(tester, 'View');

      expect(isChecked(tester, 'Dark'), isTrue);
      expect(isChecked(tester, 'System'), isFalse);
    });

    testWidgets('applies the picked theme mode', (tester) async {
      final ConfigurationController controller = await pumpMenu(tester);

      await openSubMenu(tester, 'View');
      await tester.tap(find.text('Light'));
      await settlePersistence(tester);

      expect(controller.themeMode, ThemeMode.light);
    });

    testWidgets('can go back to following the system', (tester) async {
      final ConfigurationController controller = await pumpMenu(
        tester,
        themeMode: ThemeMode.dark,
      );

      await openSubMenu(tester, 'View');
      await tester.tap(find.text('System'));
      await settlePersistence(tester);

      expect(controller.themeMode, ThemeMode.system);
    });

    testWidgets('keeps the mode when dismissed', (tester) async {
      final ConfigurationController controller = await pumpMenu(tester);

      await openSubMenu(tester, 'View');
      await dismissSubMenu(tester);

      expect(controller.themeMode, ThemeMode.system);
    });
  });

  group('Language', () {
    testWidgets('offers following the system plus each locale', (tester) async {
      await pumpMenu(tester);

      await openSubMenu(tester, 'Language');

      expect(isChecked(tester, 'System Language'), isTrue);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
    });

    testWidgets('applies the picked language', (tester) async {
      final ConfigurationController controller = await pumpMenu(tester);

      await openSubMenu(tester, 'Language');
      await tester.tap(find.text('German'));
      await settlePersistence(tester);

      expect(controller.locale, const Locale('de'));
    });

    testWidgets('resets to the system language', (tester) async {
      final ConfigurationController controller = await pumpMenu(
        tester,
        locale: const Locale('de'),
      );

      await openSubMenu(tester, 'Language');
      await tester.tap(find.text('System Language'));
      await settlePersistence(tester);

      expect(controller.locale, isNull);
    });

    testWidgets('keeps the language when dismissed', (tester) async {
      final ConfigurationController controller = await pumpMenu(
        tester,
        locale: const Locale('de'),
      );

      await openSubMenu(tester, 'Language');
      await dismissSubMenu(tester);

      expect(controller.locale, const Locale('de'));
      expect(find.text('Language'), findsNothing);
    });
  });

  group('About', () {
    testWidgets('shows the app version reported by package_info', (
      tester,
    ) async {
      mockPackageInfo('1.2.3');

      await pumpMenu(tester);
      await openSubMenu(tester, 'About');
      await tester.pump();

      expect(find.textContaining('1.2.3'), findsOneWidget);
    });

    testWidgets('shows the backend version when it is reachable', (
      tester,
    ) async {
      mockPackageInfo('1.2.3');

      await pumpMenu(tester);
      await runWithVersionClient(_okVersionClient('9.9.9'), () async {
        await openSubMenu(tester, 'About');
        await tester.pump();

        expect(find.textContaining('9.9.9'), findsOneWidget);
      });
    });

    testWidgets('falls back to unknown when the payload has no version', (
      tester,
    ) async {
      mockPackageInfo('1.2.3');

      await pumpMenu(tester);
      await runWithVersionClient(_okVersionClient(null), () async {
        await openSubMenu(tester, 'About');
        await tester.pump();

        expect(find.textContaining('unknown'), findsOneWidget);
      });
    });

    testWidgets('reports an unavailable backend when the request throws', (
      tester,
    ) async {
      mockPackageInfo('1.2.3');

      await pumpMenu(tester);
      await runWithVersionClient(_throwingClient(), () async {
        await openSubMenu(tester, 'About');
        await tester.pump();

        expect(find.textContaining(_unavailable), findsOneWidget);
      });
    });

    testWidgets('explains when no browser can open the privacy statement', (
      tester,
    ) async {
      mockPackageInfo('1.2.3');
      mockUrlLauncher();

      await pumpMenu(tester);
      await openSubMenu(tester, 'About');
      // Pumping one frame first matters: the tap below resolves through the
      // route being dismissed, so it must be the only one on the stack.
      await tester.pump();
      await openAboutEntry(tester, 'Privacy Statement');
      await settlePersistence(tester);

      expect(find.text('Privacy statement unavailable'), findsOneWidget);
    });

    testWidgets('explains when the privacy statement cannot be opened', (
      tester,
    ) async {
      mockPackageInfo('1.2.3');
      mockUrlLauncher(canLaunch: true, launched: false);

      await pumpMenu(tester);
      await openSubMenu(tester, 'About');
      await tester.pump();
      await openAboutEntry(tester, 'Privacy Statement');
      await settlePersistence(tester);

      expect(find.text('Privacy statement unavailable'), findsOneWidget);
    });

    testWidgets('opens the privacy statement without a message on success', (
      tester,
    ) async {
      mockPackageInfo('1.2.3');
      mockUrlLauncher(canLaunch: true, launched: true);

      await pumpMenu(tester);
      await openSubMenu(tester, 'About');
      await tester.pump();
      await openAboutEntry(tester, 'Privacy Statement');
      await settlePersistence(tester);

      expect(find.text('Privacy statement unavailable'), findsNothing);
    });

    testWidgets('re-opens the tutorial without throwing', (tester) async {
      mockPackageInfo('1.2.3');

      await pumpMenu(tester);
      await openSubMenu(tester, 'About');
      // No navigator is wired up in this harness, so the tutorial route is a
      // no-op; the entry must still be handled without an exception.
      await tester.pump();
      await openAboutEntry(tester, 'Show Introduction');
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('does nothing when dismissed', (tester) async {
      mockPackageInfo('1.2.3');

      await pumpMenu(tester);
      await openSubMenu(tester, 'About');
      await dismissSubMenu(tester);

      expect(find.text('Privacy statement unavailable'), findsNothing);
      expect(find.text('About'), findsNothing);
    });
  });
}

/// Answers `package_info_plus` with [version].
void mockPackageInfo(String version) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_packageInfoChannel, (
        MethodCall methodCall,
      ) async {
        return <String, String>{
          'appName': 'Vote4It',
          'packageName': 'com.dev.vote',
          'version': version,
          'buildNumber': '1',
        };
      });
}

/// Answers `url_launcher` as a device where [canLaunch] resolves to
/// [canLaunch] and a launch reports [launched].
void mockUrlLauncher({bool canLaunch = false, bool launched = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_urlLauncherChannel, (
        MethodCall methodCall,
      ) async {
        return switch (methodCall.method) {
          'canLaunch' => canLaunch,
          'launch' => launched,
          _ => null,
        };
      });
}

/// Runs [body] with [httpClient] serving the backend `/version` endpoint, so
/// the About submenu never touches the network.
///
/// The client is installed for the whole of [body] rather than only around
/// the pumps: the submenu builds its `/version` request as soon as it is
/// opened, and a client installed afterwards comes too late for it.
Future<void> runWithVersionClient(
  http.Client httpClient,
  Future<void> Function() body,
) {
  return http.runWithClient(body, () => httpClient);
}

/// An [http.Client] answering `/version` with status 200 and a body carrying
/// [version], or without a version field when it is `null`.
http.Client _okVersionClient(String? version) {
  return _statusClient(
    200,
    body: jsonEncode(<String, Object?>{'version': version}),
  );
}

/// An [http.Client] answering `/version` with [status] and [body].
http.Client _statusClient(int status, {String body = '{}'}) {
  return MockClient((http.Request request) async {
    return http.Response(body, status);
  });
}

/// An [http.Client] whose requests always fail.
http.Client _throwingClient() {
  return MockClient((http.Request request) async {
    throw Exception('no route to host');
  });
}

/// Taps the About submenu entry labelled [label].
Future<void> openAboutEntry(WidgetTester tester, String label) async {
  await tester.tap(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(PopupMenuItem<String>),
    ),
  );
}

/// Pumps [ConfigurationMenu] in an [AppBar], matching how the menu is
/// embedded in the real app shell, and returns the backing controller.
///
/// The controller is seeded through its constructor rather than
/// [ConfigurationController.setSeedColor], because persistence needs a real
/// async round trip that the widget test's fake clock cannot complete.
Future<ConfigurationController> pumpMenu(
  WidgetTester tester, {
  Color? seedColor,
  ThemeMode themeMode = ThemeMode.system,
  Locale? locale,
}) async {
  final ConfigurationController controller = ConfigurationController(
    initialSeedColor: seedColor,
    initialThemeMode: themeMode,
    initialLocale: locale,
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<ConfigurationController>.value(
      value: controller,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(actions: const <Widget>[ConfigurationMenu()]),
        ),
      ),
    ),
  );

  return controller;
}

/// Opens the top-level configuration menu.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(ConfigurationMenu));
  await tester.pumpAndSettle();
}

/// Opens the top-level configuration menu and picks [label], which opens the
/// corresponding submenu.
Future<void> openSubMenu(WidgetTester tester, String label) async {
  await openMenu(tester);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Drains the mocked platform-channel replies of a persistence round trip.
Future<void> settlePersistence(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Taps outside the open submenu so [showMenu] resolves with `null`.
///
/// The tap lands just above the bottom edge of the test surface, which is
/// outside the top-anchored submenu for every entry, while staying inside the
/// surface so the hit test reaches the modal route that dismisses it.
Future<void> dismissSubMenu(WidgetTester tester) async {
  final Offset outside =
      tester.getBottomLeft(find.byType(Scaffold)) - const Offset(2, 2);
  await tester.tapAt(outside);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Whether the submenu entry labelled [label] shows its "selected" marker.
///
/// Theme colors are marked with a check that is only built for the active
/// entry, while the radio-style submenus always build an icon.
bool isChecked(WidgetTester tester, String label) {
  final Finder text = find.text(label);
  if (text.evaluate().isEmpty) return false;

  final Finder row = find.ancestor(of: text, matching: find.byType(Row)).first;
  final Finder marker = find.descendant(of: row, matching: find.byType(Icon));
  if (marker.evaluate().isEmpty) return false;

  final IconData? icon = tester.widget<Icon>(marker).icon;
  return icon == Icons.check || icon == Icons.radio_button_checked;
}
