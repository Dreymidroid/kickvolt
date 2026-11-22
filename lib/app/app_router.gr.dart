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
    String projectId = 'demo',
    List<PageRouteInfo>? children,
  }) : super(
         BeatEditorRoute.name,
         args: BeatEditorRouteArgs(key: key, projectId: projectId),
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
            BeatEditorRouteArgs(projectId: pathParams.getString('id', 'demo')),
      );
      return BeatEditorScreen(key: args.key, projectId: args.projectId);
    },
  );
}

class BeatEditorRouteArgs {
  const BeatEditorRouteArgs({this.key, this.projectId = 'demo'});

  final Key? key;

  final String projectId;

  @override
  String toString() {
    return 'BeatEditorRouteArgs{key: $key, projectId: $projectId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BeatEditorRouteArgs) return false;
    return key == other.key && projectId == other.projectId;
  }

  @override
  int get hashCode => key.hashCode ^ projectId.hashCode;
}

/// generated route for
/// [HomeScreen]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomeScreen();
    },
  );
}
