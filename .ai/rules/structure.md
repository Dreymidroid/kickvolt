# Kickvolt — Project Structure

Adapted from the Wavezio mobile app rules. Kickvolt has no verticals:
features live directly under `lib/features/`.

## Directory Organization

```
lib/
├── app/                    # App-level config and routing
│   ├── app.dart
│   ├── app_config.dart
│   ├── app_constants.dart
│   ├── app_router.dart
│   ├── app_theme.dart
│   ├── app_bloc_observer.dart
│   └── flavors/            # main_qa.dart, main_prod.dart
│
├── core/                   # Cross-app infrastructure
│   ├── di/                 # GetIt locators
│   ├── api_client/         # Retrofit clients
│   ├── interceptors/       # Dio interceptors (auth, errors, parsing)
│   ├── models/             # Shared API models
│   ├── storage/            # Hive via AppStorage
│   ├── session_manager/
│   └── core.dart           # Barrel export
│
├── features/               # Feature modules
│   ├── auth/
│   ├── <feature>/
│   └── features.dart       # Barrel export
│
├── shared/                 # Reusable UI components
│   ├── widgets/
│   ├── styles/             # Text styles, colors, spacing
│   └── shared.dart         # Barrel export
│
├── utils/                  # Extensions, validators, guards
├── env/                    # Envied environment config
├── gen/                    # FlutterGen assets (do not edit)
└── i10n/                   # Localization ARB files
```

## Feature Module Structure

Each feature follows Clean Architecture:

```
features/<feature>/
├── bloc/                   # or cubit/
│   ├── <feature>_bloc.dart     # or <feature>_cubit.dart
│   ├── <feature>_event.dart    # Bloc only
│   └── <feature>_state.dart
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   └── remote/
│   ├── models/             # Freezed + json_serializable
│   ├── mappers/            # JSON/model → entity (when needed)
│   └── repositories/
│       └── <feature>_repository.dart
├── domain/
│   ├── entities/
│   └── usecases/           # Optional — use when logic is reusable
├── presentation/
│   ├── pages/
│   ├── widgets/
│   └── views/
└── <feature>.dart          # Barrel export
```

## Naming Conventions

| Element | Convention | Examples |
|---------|-----------|----------|
| Directories | `snake_case` | `match_details`, `my_teams` |
| Dart files | `snake_case.dart` | `my_teams_cubit.dart` |
| Classes | `PascalCase` | `MyTeamsCubit`, `TeamRepository` |
| States | `*State` (Freezed union) | `MyTeamsState` |
| Events | `*Event` (Freezed union) | `AuthEvent` |
| Cubits | `*Cubit` | `ProfileCubit` |
| Blocs | `*Bloc` | `AuthBloc` |
| Repositories | `*Repository` / `*RepositoryImpl` | `TeamRepository` |
| Datasources | `*RemoteDataSource` / `*LocalDataSource` | `AuthRemoteDataSource` |
| API clients | `*Client` | `AuthClient` |
| Pages | `*Screen` or `*Page` | `LoginScreen` |
| Widgets | `*Widget` or `Custom*` | `CustomButton` |
| Models | `*Model` (data layer) | `TeamModel` |
| Entities | `*Entity` (domain layer) | `TeamEntity` |
| Constants / storage keys | `UPPER_SNAKE_CASE` | `AUTH_TOKEN` |
| Test files | `<file>_test.dart` | `my_teams_cubit_test.dart` |

## Architecture Layers

```
Presentation (UI → Bloc/Cubit)
        ↓
Domain (Entities & Use Cases)
        ↓
Data (Repositories & Datasources)
        ↓
External APIs & Local Storage
```

**Rule:** Never bypass layers. UI never calls a repository or API client
directly; Blocs/Cubits always go through repositories.

## Barrel Exports

Every feature, plus `core/`, `shared/` and `features/`, has a barrel file:

```dart
// features/my_teams/my_teams.dart
export 'bloc/my_teams_cubit.dart';
export 'data/repositories/my_teams_repository.dart';
export 'domain/entities/team_entity.dart';
export 'presentation/pages/my_teams_screen.dart';
```

Import via barrel:

```dart
import 'package:kickvolt/features/my_teams/my_teams.dart';
```

**When creating a new file (screen, widget, model, cubit), always export it
from the appropriate barrel** so it resolves across the app and for code
generators like auto_route.

## Models

- Feature-specific API models live in `data/models/`
- Shared cross-feature models live in `core/models/`
- Use **Freezed** + **json_serializable** for immutable models
- Map models → entities in the repository or a dedicated mapper class

## Dependency Injection

GetIt service locator (`locator`) split across `core/di/`:

- `external_locator.dart` — Dio, Hive, etc.
- `client_locator.dart` — Retrofit API clients
- `repository_locator.dart` — Repository implementations

Cubits/Blocs are provided at app or route level via `BlocProvider`, not
registered as singletons.

## Routing

- Use **auto_route** with `@RoutePage()` annotations
- Register all routes in `app/app_router.dart`
- Navigate with typed routes: `context.router.push(MyTeamsRoute())`
- Protected routes: `AutoRoute(page: XRoute.page, guards: [AuthGuard()])`

## UI & Assets

- Import Material from `package:material_ui/material_ui.dart`, not
  `package:flutter/material.dart` (Material moved out of the SDK; mixing the
  two gives "TextTheme can't be assigned to TextTheme?" errors)
- Theme tokens: `context.kv` (`KvColors` ThemeExtension); fonts via `KvText`
- Reuse components from `shared/` before creating new ones
- Feature-specific widgets stay in the feature's `presentation/widgets/`
- Use `flutter_gen` (`AppAssets.*`) — never raw asset paths
- Network images: `cached_network_image`
- Long lists: `ListView.builder`

## Tests

Unit tests in `test/` mirror `lib/`, e.g.
`test/features/my_teams/bloc/my_teams_cubit_test.dart`.
