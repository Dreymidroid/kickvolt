// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

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
