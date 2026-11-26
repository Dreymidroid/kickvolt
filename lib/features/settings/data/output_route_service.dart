// audio_session 0.2.4 marks AudioDeviceType / getDevices / devicesStream as
// @experimental; these are the exact APIs specified in M5 §6.3.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';

import '../domain/entities/app_settings.dart';

/// Reports the current audio output route and (on iOS) the platform-reported
/// output latency (§6.3).
///
/// Uses only the verified `audio_session` 0.2.4 APIs:
/// - `AudioSession.instance` -> `getDevices(includeInputs: false)` &
///   `devicesStream`
/// - `AVAudioSession().outputLatency` on iOS only (Android has no getter).
///
/// Known limits of `audio_session` 0.2.4:
/// - On Android, `getDevices` returns all connected outputs rather than only
///   the active route, so Bluetooth detection means "Bluetooth output is
///   connected".
/// - Android BLE-audio device types are not mapped in 0.2.4 and arrive as
///   `AudioDeviceType.unknown`.
abstract interface class OutputRouteService {
  Future<OutputKind> currentOutputKind();

  Stream<OutputKind> get outputKindStream;

  /// Platform-reported output latency on iOS (`AVAudioSession.outputLatency`),
  /// or `null` on Android / unsupported platforms.
  Future<Duration?> reportedOutputLatency();
}

/// Classifies a set of `audio_session` [AudioDevice]s into an [OutputKind].
OutputKind classifyOutputDevices(Set<AudioDevice> devices) {
  final outputs = devices.where((d) => d.isOutput);
  var hasWired = false;
  var hasBuiltIn = false;

  for (final d in outputs) {
    switch (d.type) {
      case AudioDeviceType.bluetoothA2dp:
      case AudioDeviceType.bluetoothLe:
      case AudioDeviceType.bluetoothSco:
      case AudioDeviceType.hearingAid:
        return OutputKind.bluetooth;
      case AudioDeviceType.wiredHeadphones:
      case AudioDeviceType.wiredHeadset:
      case AudioDeviceType.usbAudio:
      case AudioDeviceType.lineAnalog:
      case AudioDeviceType.lineDigital:
      case AudioDeviceType.auxLine:
        hasWired = true;
      case AudioDeviceType.builtInSpeaker:
      case AudioDeviceType.builtInEarpiece:
      case AudioDeviceType.builtInSpeakerSafe:
        hasBuiltIn = true;
      default:
        break;
    }
  }
  if (hasWired) return OutputKind.wired;
  if (hasBuiltIn) return OutputKind.builtIn;
  return OutputKind.unknown;
}

class AudioSessionOutputRouteService implements OutputRouteService {
  AudioSessionOutputRouteService();

  StreamController<OutputKind>? _controller;
  StreamSubscription<Set<AudioDevice>>? _sub;

  @override
  Future<OutputKind> currentOutputKind() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices(includeInputs: false);
      return classifyOutputDevices(devices);
    } catch (_) {
      return OutputKind.unknown;
    }
  }

  @override
  Stream<OutputKind> get outputKindStream {
    _controller ??= StreamController<OutputKind>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _controller!.stream;
  }

  void _startListening() {
    unawaited(
      AudioSession.instance
          .then((session) {
            if (_controller == null || !_controller!.hasListener) return;
            _sub = session.devicesStream.listen((devices) {
              if (_controller != null && !_controller!.isClosed) {
                _controller!.add(classifyOutputDevices(devices));
              }
            }, onError: (_) {});
          })
          .catchError((_) {}),
    );
  }

  void _stopListening() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  @override
  Future<Duration?> reportedOutputLatency() async {
    if (!Platform.isIOS) return null;
    try {
      return await AVAudioSession().outputLatency;
    } catch (_) {
      return null;
    }
  }
}

/// Human-readable label for the current audio output (§7.6).
String outputKindLabel(OutputKind kind) => switch (kind) {
  OutputKind.builtIn => 'Phone speaker',
  OutputKind.wired => 'Wired headphones',
  OutputKind.bluetooth => 'Bluetooth headphones connected',
  OutputKind.unknown => 'Audio output',
};

/// Whether the Bluetooth mismatch warning should be shown (§7.3, §7.6).
///
/// Shown when the current output is Bluetooth and calibration was NOT done on
/// Bluetooth (including never calibrated), or when calibration WAS done on
/// Bluetooth and the current output is not Bluetooth (and known).
bool shouldShowBluetoothWarning({
  required OutputKind currentOutput,
  required OutputKind? calibratedOn,
}) {
  if (currentOutput == OutputKind.bluetooth) {
    return calibratedOn != OutputKind.bluetooth;
  }
  if (calibratedOn == OutputKind.bluetooth &&
      currentOutput != OutputKind.unknown) {
    return true;
  }
  return false;
}
