import 'package:flutter_test/flutter_test.dart';
import 'package:kickvolt/features/onboarding/onboarding.dart';
import 'package:kickvolt/features/settings/settings.dart';

void main() {
  group('First-run onboarding and coach-mark state', () {
    test('defaults show both onboarding and coach marks on first run', () {
      const settings = AppSettings();
      expect(settings.onboardingDone, isFalse);
      expect(settings.coachMarksDone, isFalse);
      expect(shouldShowOnboarding(settings), isTrue);
      expect(shouldShowCoachMarks(settings), isTrue);
    });

    test(
      'completeOnboarding marks onboardingDone without touching other keys',
      () {
        const initial = AppSettings(
          hapticsEnabled: false,
          defaultSensitivity: 0.75,
          coachMarksDone: false,
        );
        final after = completeOnboarding(initial);
        expect(after.onboardingDone, isTrue);
        expect(shouldShowOnboarding(after), isFalse);
        expect(after.coachMarksDone, isFalse);
        expect(shouldShowCoachMarks(after), isTrue);
        expect(after.hapticsEnabled, isFalse);
        expect(after.defaultSensitivity, 0.75);
      },
    );

    test('CoachMarkStep progresses 1 -> 2 -> 3 -> null and exposes copy', () {
      expect(CoachMarkStep.values.length, 3);

      expect(CoachMarkStep.waveform.stepLabel, '1 of 3');
      expect(CoachMarkStep.waveform.title, 'Your beats live here');
      expect(CoachMarkStep.waveform.primaryButtonLabel, 'Next');
      expect(CoachMarkStep.waveform.next, CoachMarkStep.tools);

      expect(CoachMarkStep.tools.stepLabel, '2 of 3');
      expect(CoachMarkStep.tools.title, 'Pick how you mark');
      expect(CoachMarkStep.tools.primaryButtonLabel, 'Next');
      expect(CoachMarkStep.tools.next, CoachMarkStep.exportPill);

      expect(CoachMarkStep.exportPill.stepLabel, '3 of 3');
      expect(CoachMarkStep.exportPill.title, 'Export when it looks right');
      expect(CoachMarkStep.exportPill.primaryButtonLabel, 'Got it');
      expect(CoachMarkStep.exportPill.next, isNull);
    });

    test(
      'completeCoachMarks marks coachMarksDone without resetting onboarding',
      () {
        const initial = AppSettings(
          onboardingDone: true,
          coachMarksDone: false,
        );
        final after = completeCoachMarks(initial);
        expect(after.coachMarksDone, isTrue);
        expect(shouldShowCoachMarks(after), isFalse);
        expect(after.onboardingDone, isTrue);
      },
    );
  });
}
