import 'package:freezed_annotation/freezed_annotation.dart';

part 'beat.freezed.dart';

enum BeatType { beat, strong, drop, downbeat }

@freezed
abstract class Beat with _$Beat {
  const factory Beat({
    required int sample,
    @Default(BeatType.beat) BeatType type,
  }) = _Beat;
}
