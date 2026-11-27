import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_router.dart';
import '../../../../shared/shared.dart';
import '../../bloc/onboarding_cubit.dart';
import '../widgets/onboarding_illustrations.dart';

/// First-run 3-screen onboarding (`Main`, `Onboarding2`, `Onboarding3`, M8 §4.2).
@RoutePage()
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.cubit, this.onCompleted});

  final OnboardingCubit? cubit;
  final VoidCallback? onCompleted;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => cubit ?? OnboardingCubit(),
      child: _OnboardingView(onCompleted: onCompleted),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView({this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialPage = context.read<OnboardingCubit>().state.pageIndex;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return BlocConsumer<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        if (state.completed) {
          if (widget.onCompleted != null) {
            widget.onCompleted!();
          } else {
            context.router.replaceAll([HomeRoute()]);
          }
          return;
        }
        if (_pageController.hasClients &&
            _pageController.page?.round() != state.pageIndex) {
          _pageController.jumpToPage(state.pageIndex);
        }
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingCubit>();
        return Scaffold(
          backgroundColor: kv.background,
          body: SafeArea(
            child: PageView(
              controller: _pageController,
              onPageChanged: cubit.setPage,
              children: [
                _OnboardingPage1(onNext: cubit.nextPage, onSkip: cubit.skip),
                _OnboardingPage2(
                  onBack: cubit.previousPage,
                  onNext: cubit.nextPage,
                  onSkip: cubit.skip,
                ),
                _OnboardingPage3(
                  isSubmitting: state.isSubmitting,
                  onBack: cubit.previousPage,
                  onAllowAccess: cubit.allowAccess,
                  onNotNow: cubit.notNow,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPage1 extends StatelessWidget {
  const _OnboardingPage1({required this.onNext, required this.onSkip});

  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: kv.volt,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: kv.volt.withValues(alpha: 0.45),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: KvIcon(KvIcons.bolt, size: 16, color: kv.onVolt),
                ),
                const SizedBox(width: 8),
                Text('KickVolt', style: KvText.heading(size: 18)),
                const Spacer(),
                _SkipButton(onPressed: onSkip),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProblemComparisonCard(),
                  const SizedBox(height: 28),
                  Text(
                    'CapCut misses your beats.',
                    style: KvText.heading(size: 36).copyWith(height: 1.08),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Auto-beat guesses. On fast drops, half-time hooks and '
                    'quiet intros it guesses wrong, so you end up tapping '
                    'beats in by hand. Every. Single. Edit.',
                    style: KvText.ui(size: 16, color: kv.text2, height: 1.45),
                  ),
                ],
              ),
            ),
          ),
          _OnboardingFooter(activeIndex: 0, onNext: onNext),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OnboardingPage2 extends StatelessWidget {
  const _OnboardingPage2({
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-8, 0),
                  child: KvIconButton(
                    icon: KvIcons.chevronLeft,
                    tooltip: 'Back',
                    onPressed: onBack,
                  ),
                ),
                const Spacer(),
                _SkipButton(onPressed: onSkip),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BeatPackIllustrationCard(),
                  const SizedBox(height: 24),
                  Text(
                    'Mark once. Export a beat pack.',
                    style: KvText.heading(size: 32).copyWith(height: 1.08),
                  ),
                  const SizedBox(height: 20),
                  const _StepRow(
                    number: '1',
                    title: 'Mark the beats',
                    subtitle:
                        'Auto-detect, then fine-tune any beat that’s off.',
                  ),
                  const SizedBox(height: 16),
                  const _StepRow(
                    number: '2',
                    title: 'Export a beat pack',
                    subtitle:
                        'The song plus a silent guide track with a click on '
                        'every beat.',
                  ),
                  const SizedBox(height: 16),
                  const _StepRow(
                    number: '3',
                    title: 'Run Auto Beats in CapCut or VN',
                    subtitle:
                        'The clicks show up as sharp spikes, so it catches '
                        'every one. Then mute the guide.',
                  ),
                ],
              ),
            ),
          ),
          _OnboardingFooter(activeIndex: 1, onNext: onNext),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _OnboardingPage3 extends StatelessWidget {
  const _OnboardingPage3({
    required this.isSubmitting,
    required this.onBack,
    required this.onAllowAccess,
    required this.onNotNow,
  });

  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onAllowAccess;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: KvIconButton(
                  icon: KvIcons.chevronLeft,
                  tooltip: 'Back',
                  onPressed: isSubmitting ? null : onBack,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: kv.surface1,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: kv.border),
                      boxShadow: [
                        BoxShadow(
                          color: kv.volt.withValues(alpha: 0.18),
                          blurRadius: 60,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: KvIcon(
                      KvIcons.music,
                      size: 44,
                      color: kv.volt,
                      strokeWidth: 1.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Let KickVolt reach your music.',
                    style: KvText.heading(size: 32).copyWith(height: 1.08),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'We need access to pick songs and save your beat packs '
                    'where CapCut and VN can find them.',
                    style: KvText.ui(size: 16, color: kv.text2, height: 1.45),
                  ),
                  const SizedBox(height: 28),
                  const _PermissionInfoCard(
                    icon: KvIcons.folder,
                    title: 'Files & music',
                    subtitle: 'Import songs, save beat packs to Files.',
                  ),
                  const SizedBox(height: 12),
                  const _PermissionInfoCard(
                    icon: KvIcons.video,
                    title: 'Photos & videos',
                    badge: 'Optional',
                    subtitle:
                        'Pull the audio out of a clip in your camera roll.',
                  ),
                ],
              ),
            ),
          ),
          KvPrimaryButton(
            label: 'Allow access',
            onPressed: isSubmitting ? null : onAllowAccess,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: isSubmitting ? null : onNotNow,
              child: Text(
                'Not now',
                style: KvText.ui(
                  size: 15,
                  weight: FontWeight.w600,
                  color: kv.text2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Semantics(
      button: true,
      label: 'Skip',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'Skip',
                style: KvText.ui(
                  size: 15,
                  weight: FontWeight.w600,
                  color: kv.text2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: kv.volt.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: KvText.mono(
              size: 13,
              weight: FontWeight.w700,
              color: kv.volt,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: KvText.ui(
                  size: 16,
                  weight: FontWeight.w600,
                  color: kv.text1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: KvText.ui(size: 14, color: kv.text2, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionInfoCard extends StatelessWidget {
  const _PermissionInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final KvIcons icon;
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: kv.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kv.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kv.volt.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: KvIcon(icon, size: 22, color: kv.volt),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: KvText.ui(
                          size: 16,
                          weight: FontWeight.w600,
                          color: kv.text1,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kv.border),
                        ),
                        child: Text(
                          badge!,
                          style: KvText.ui(
                            size: 11,
                            weight: FontWeight.w600,
                            color: kv.text2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: KvText.ui(size: 14, color: kv.text2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({required this.activeIndex, required this.onNext});

  final int activeIndex;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final kv = context.kv;
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Container(
                  width: i == activeIndex ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == activeIndex ? kv.volt : kv.surface3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(
            width: 170,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: kv.primaryGlow,
              ),
              child: Material(
                color: kv.volt,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onNext,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: KvText.ui(
                          size: 17,
                          weight: FontWeight.w600,
                          color: kv.onVolt,
                        ),
                      ),
                      const SizedBox(width: 8),
                      KvIcon(KvIcons.chevronRight, size: 20, color: kv.onVolt),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
