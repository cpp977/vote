import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/services/tutorial_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorialController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    group('defaults (before load)', () {
      test('is not yet initialized', () {
        final TutorialController controller = TutorialController();

        expect(controller.isInitialized, isFalse);
      });

      test('reports the tutorial as not completed', () {
        final TutorialController controller = TutorialController();

        expect(controller.isCompleted, isFalse);
        expect(controller.shouldShowTutorial, isTrue);
      });
    });

    group('load', () {
      test('marks the controller as initialized and shows the tutorial '
          'when nothing was stored', () async {
        final TutorialController controller = TutorialController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.load();

        expect(controller.isInitialized, isTrue);
        expect(controller.shouldShowTutorial, isTrue);
        // Loading flips the initialized flag, so listeners fire once.
        expect(notifications, 1);
      });

      test('restores a completed flag from storage', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'tutorial_completed': true,
        });
        final TutorialController controller = TutorialController();

        await controller.load();

        expect(controller.isCompleted, isTrue);
        // Completed before revisions were tracked counts as revision 1, so
        // the tour (now at revision 2) is shown again once.
        expect(controller.seenRevision, 1);
        expect(controller.shouldShowTutorial, isTrue);
      });

      test('reads the stored revision', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'tutorial_completed': true,
          'tutorial_revision': 2,
        });
        final TutorialController controller = TutorialController();

        await controller.load();

        expect(controller.seenRevision, 2);
      });

      test('treats a completed intro without a stored revision as '
          'revision 1', () async {
        // Users who completed the intro before revisions were tracked get
        // revision 1 (the original tour), so they only replay newer pages.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'tutorial_completed': true,
        });
        final TutorialController controller = TutorialController();

        await controller.load();

        expect(controller.seenRevision, 1);
      });

      test('defaults the revision to 0 for a fresh install', () async {
        final TutorialController controller = TutorialController();

        await controller.load();

        expect(controller.seenRevision, 0);
      });

      test('is a no-op when called twice', () async {
        final TutorialController controller = TutorialController();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.load();
        await controller.load();

        expect(controller.isInitialized, isTrue);
        expect(notifications, 1);
      });
    });

    group('complete', () {
      test('marks the tutorial as completed and notifies listeners', () async {
        final TutorialController controller = TutorialController();
        await controller.load();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.complete();

        expect(controller.isCompleted, isTrue);
        expect(controller.shouldShowTutorial, isFalse);
        expect(notifications, 1);
      });

      test('persists the completed flag', () async {
        final TutorialController controller = TutorialController();
        await controller.load();

        await controller.complete();

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('tutorial_completed'), isTrue);
      });

      test('persists the current revision', () async {
        final TutorialController controller = TutorialController();
        await controller.load();

        await controller.complete();

        expect(controller.seenRevision, TutorialController.currentRevision);
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getInt('tutorial_revision'),
          TutorialController.currentRevision,
        );
      });

      test('hides the tutorial after completing the current revision '
          '(even when it was shown again for an update)', () async {
        // A returning user who was shown the tour because of a revision bump
        // must not see it again after completing it.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'tutorial_completed': true,
          'tutorial_revision': 1,
        });
        final TutorialController controller = TutorialController();
        await controller.load();
        expect(controller.shouldShowTutorial, isTrue);

        await controller.complete();

        expect(controller.shouldShowTutorial, isFalse);
      });

      test('is a no-op when already completed', () async {
        final TutorialController controller = TutorialController();
        await controller.load();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.complete();
        await controller.complete();

        expect(controller.isCompleted, isTrue);
        expect(notifications, 1);
      });
    });

    group('reset', () {
      test('clears a completed flag so the tutorial shows again', () async {
        final TutorialController controller = TutorialController();
        await controller.load();

        await controller.complete();
        await controller.reset();

        expect(controller.isCompleted, isFalse);
        expect(controller.shouldShowTutorial, isTrue);
      });

      test('persists the reset', () async {
        final TutorialController controller = TutorialController();
        await controller.load();

        await controller.complete();
        await controller.reset();

        final SharedPreferences prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('tutorial_completed'), isFalse);
      });

      test('is a no-op when already not completed', () async {
        final TutorialController controller = TutorialController();
        await controller.load();
        int notifications = 0;
        controller.addListener(() => notifications++);

        await controller.reset();

        expect(controller.isCompleted, isFalse);
        expect(notifications, 0);
      });
    });
  });
}
