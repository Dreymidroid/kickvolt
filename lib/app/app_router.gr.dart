// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AnalyzingScreen]
class AnalyzingRoute extends PageRouteInfo<AnalyzingRouteArgs> {
  AnalyzingRoute({
    Key? key,
    required PickedSource source,
    ImportCubit? cubit,
    List<PageRouteInfo>? children,
  }) : super(
         AnalyzingRoute.name,
         args: AnalyzingRouteArgs(key: key, source: source, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'AnalyzingRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AnalyzingRouteArgs>();
      return AnalyzingScreen(
        key: args.key,
        source: args.source,
        cubit: args.cubit,
      );
    },
  );
}

class AnalyzingRouteArgs {
  const AnalyzingRouteArgs({this.key, required this.source, this.cubit});

  final Key? key;

  final PickedSource source;

  final ImportCubit? cubit;

  @override
  String toString() {
    return 'AnalyzingRouteArgs{key: $key, source: $source, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnalyzingRouteArgs) return false;
    return key == other.key && source == other.source && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ source.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [BeatEditorScreen]
class BeatEditorRoute extends PageRouteInfo<BeatEditorRouteArgs> {
  BeatEditorRoute({
    Key? key,
    required String projectId,
    BeatEditorCubit? cubit,
    List<PageRouteInfo>? children,
  }) : super(
         BeatEditorRoute.name,
         args: BeatEditorRouteArgs(
           key: key,
           projectId: projectId,
           cubit: cubit,
         ),
         rawPathParams: {'id': projectId},
         initialChildren: children,
       );

  static const String name = 'BeatEditorRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<BeatEditorRouteArgs>(
        orElse: () =>
            BeatEditorRouteArgs(projectId: pathParams.getString('id')),
      );
      return BeatEditorScreen(
        key: args.key,
        projectId: args.projectId,
        cubit: args.cubit,
      );
    },
  );
}

class BeatEditorRouteArgs {
  const BeatEditorRouteArgs({this.key, required this.projectId, this.cubit});

  final Key? key;

  final String projectId;

  final BeatEditorCubit? cubit;

  @override
  String toString() {
    return 'BeatEditorRouteArgs{key: $key, projectId: $projectId, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BeatEditorRouteArgs) return false;
    return key == other.key &&
        projectId == other.projectId &&
        cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ projectId.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [ExportScreen]
class ExportRoute extends PageRouteInfo<ExportRouteArgs> {
  ExportRoute({
    Key? key,
    required String projectId,
    ExportCubit? cubit,
    List<PageRouteInfo>? children,
  }) : super(
         ExportRoute.name,
         args: ExportRouteArgs(key: key, projectId: projectId, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'ExportRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ExportRouteArgs>();
      return ExportScreen(
        key: args.key,
        projectId: args.projectId,
        cubit: args.cubit,
      );
    },
  );
}

class ExportRouteArgs {
  const ExportRouteArgs({this.key, required this.projectId, this.cubit});

  final Key? key;

  final String projectId;

  final ExportCubit? cubit;

  @override
  String toString() {
    return 'ExportRouteArgs{key: $key, projectId: $projectId, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExportRouteArgs) return false;
    return key == other.key &&
        projectId == other.projectId &&
        cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ projectId.hashCode ^ cubit.hashCode;
}

/// generated route for
/// [HomeScreen]
class HomeRoute extends PageRouteInfo<HomeRouteArgs> {
  HomeRoute({
    Key? key,
    ProjectsCubit? projectsCubit,
    SourcePickerCubit? pickerCubit,
    List<PageRouteInfo>? children,
  }) : super(
         HomeRoute.name,
         args: HomeRouteArgs(
           key: key,
           projectsCubit: projectsCubit,
           pickerCubit: pickerCubit,
         ),
         initialChildren: children,
       );

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeRouteArgs>(
        orElse: () => const HomeRouteArgs(),
      );
      return HomeScreen(
        key: args.key,
        projectsCubit: args.projectsCubit,
        pickerCubit: args.pickerCubit,
      );
    },
  );
}

class HomeRouteArgs {
  const HomeRouteArgs({this.key, this.projectsCubit, this.pickerCubit});

  final Key? key;

  final ProjectsCubit? projectsCubit;

  final SourcePickerCubit? pickerCubit;

  @override
  String toString() {
    return 'HomeRouteArgs{key: $key, projectsCubit: $projectsCubit, pickerCubit: $pickerCubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HomeRouteArgs) return false;
    return key == other.key &&
        projectsCubit == other.projectsCubit &&
        pickerCubit == other.pickerCubit;
  }

  @override
  int get hashCode =>
      key.hashCode ^ projectsCubit.hashCode ^ pickerCubit.hashCode;
}

/// generated route for
/// [LatencyCalibrationScreen]
class LatencyCalibrationRoute
    extends PageRouteInfo<LatencyCalibrationRouteArgs> {
  LatencyCalibrationRoute({
    Key? key,
    LatencyCalibrationCubit? cubit,
    List<PageRouteInfo>? children,
  }) : super(
         LatencyCalibrationRoute.name,
         args: LatencyCalibrationRouteArgs(key: key, cubit: cubit),
         initialChildren: children,
       );

  static const String name = 'LatencyCalibrationRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LatencyCalibrationRouteArgs>(
        orElse: () => const LatencyCalibrationRouteArgs(),
      );
      return LatencyCalibrationScreen(key: args.key, cubit: args.cubit);
    },
  );
}

class LatencyCalibrationRouteArgs {
  const LatencyCalibrationRouteArgs({this.key, this.cubit});

  final Key? key;

  final LatencyCalibrationCubit? cubit;

  @override
  String toString() {
    return 'LatencyCalibrationRouteArgs{key: $key, cubit: $cubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LatencyCalibrationRouteArgs) return false;
    return key == other.key && cubit == other.cubit;
  }

  @override
  int get hashCode => key.hashCode ^ cubit.hashCode;
}
