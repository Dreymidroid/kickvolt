import '../../settings/domain/entities/app_settings.dart';

/// Ordered steps of the first-run editor coach marks (`Coach1`–`Coach3`, §4.3).
enum CoachMarkStep {
  waveform(
    stepLabel: '1 of 3',
    title: 'Your beats live here',
    body:
        'Pinch to zoom, drag to scrub. Lime lines are beats; the numbered ones '
        'are strong beats.',
    primaryButtonLabel: 'Next',
  ),
  tools(
    stepLabel: '2 of 3',
    title: 'Pick how you mark',
    body:
        'Auto finds every beat in seconds. Tap lets you play them in by feel. '
        'Edit fixes the ones that are off.',
    primaryButtonLabel: 'Next',
  ),
  exportPill(
    stepLabel: '3 of 3',
    title: 'Export when it looks right',
    body: 'You get the song plus a guide track, ready for CapCut or VN.',
    primaryButtonLabel: 'Got it',
  );

  const CoachMarkStep({
    required this.stepLabel,
    required this.title,
    required this.body,
    required this.primaryButtonLabel,
  });

  final String stepLabel;
  final String title;
  final String body;
  final String primaryButtonLabel;

  /// Next step, or `null` when this is the final step.
  CoachMarkStep? get next => switch (this) {
    CoachMarkStep.waveform => CoachMarkStep.tools,
    CoachMarkStep.tools => CoachMarkStep.exportPill,
    CoachMarkStep.exportPill => null,
  };
}

/// True when the app should launch into first-run onboarding instead of Home (§4.1).
bool shouldShowOnboarding(AppSettings settings) => !settings.onboardingDone;

/// True when the editor should display first-run coach marks (§4.3).
bool shouldShowCoachMarks(AppSettings settings) => !settings.coachMarksDone;

/// Returns a copy of [settings] with `onboardingDone: true`.
AppSettings completeOnboarding(AppSettings settings) =>
    settings.copyWith(onboardingDone: true);

/// Returns a copy of [settings] with `coachMarksDone: true`.
AppSettings completeCoachMarks(AppSettings settings) =>
    settings.copyWith(coachMarksDone: true);
