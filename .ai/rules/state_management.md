# Kickvolt — State Management

Adapted from the Wavezio mobile app rules.

Stack: `flutter_bloc` + `freezed`, with `flutter_hooks` for widget-level
state (controllers, focus nodes) inside screens.

## Cubit vs Bloc

| Scenario | Use |
|----------|-----|
| Simple state transitions | `Cubit` |
| Form validation | `Cubit` |
| Event-driven complex flows (auth, checkout) | `Bloc` |
| Search / API calls needing debouncing | `Bloc` with `debounceTransformer` |

## States and Events

Use Freezed unions for every state and event. Files live in
`features/<feature>/bloc/`.

```dart
part 'team_state.freezed.dart';

// freezed 4: unions are `sealed class`, single-case data is `abstract class`.
@freezed
sealed class TeamState with _$TeamState {
  const factory TeamState.initial() = _Initial;
  const factory TeamState.loading() = _Loading;
  const factory TeamState.loaded(List<TeamEntity> teams) = _Loaded;
  const factory TeamState.error({required String error}) = _Error;
}
```

```dart
@freezed
sealed class AuthEvent with _$AuthEvent {
  const factory AuthEvent.login(String email, String password) = _Login;
  const factory AuthEvent.logout() = _Logout;
}
```

## Repository Injection

Inject the repository through the constructor, defaulting to the service
locator so tests can pass a mock:

```dart
class TeamCubit extends Cubit<TeamState> {
  TeamCubit({TeamRepository? repository})
      : _repository = repository ?? locator<TeamRepository>(),
        super(const TeamState.initial());

  final TeamRepository _repository;
}
```

## Emission and Error Handling

- Always wrap repository calls in `try`/`catch`.
- Emit loading before the call, success/loaded with the data after.
- Catch `APIException` specifically and emit its message; catch other
  exceptions and emit a generic or stringified error.

```dart
Future<void> getTeams() async {
  emit(const TeamState.loading());
  try {
    final teams = await _repository.getTeams();
    emit(TeamState.loaded(teams));
  } on APIException catch (e) {
    emit(TeamState.error(error: e.message));
  } catch (e) {
    emit(TeamState.error(error: e.toString()));
  }
}
```

Bloc version:

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({AuthRepository? repository})
      : _repository = repository ?? locator<AuthRepository>(),
        super(const AuthState.initial()) {
    on<_Login>(_onLogin);
    on<_Logout>(_onLogout);
  }

  final AuthRepository _repository;

  Future<void> _onLogin(_Login event, Emitter<AuthState> emit) async {
    emit(const AuthState.loading());
    try {
      final user = await _repository.login(event.email, event.password);
      emit(AuthState.success(user));
    } on APIException catch (e) {
      emit(AuthState.error(error: e.message));
    } catch (e) {
      emit(AuthState.error(error: e.toString()));
    }
  }

  Future<void> _onLogout(_Logout event, Emitter<AuthState> emit) async {
    await _repository.logout();
    emit(const AuthState.initial());
  }
}
```

Debounced events:

```dart
on<_Search>(
  _onSearch,
  transformer: debounceTransformer(const Duration(milliseconds: 500)),
);
```

## Repository Contract (what Blocs rely on)

- Abstract `XRepository` interface + `XRepositoryImpl` in
  `data/repositories/`, with the Retrofit `XClient` injected.
- Catch `DioException` and rethrow `e.error` as an `APIException`
  (default `APIException()` if null); wrap other exceptions as
  `APIException(message: e.toString())`.
- Check for status `200`/`201` and return typed models/entities — never raw
  JSON — to the Bloc layer.

## Using State in the UI

- Provide Cubits/Blocs with `BlocProvider` at app or route level.
- `BlocBuilder` for UI, `BlocListener` for side effects (snackbars,
  navigation, dialogs), `BlocConsumer` when both are needed.
- Use `buildWhen` / `listenWhen` to limit rebuilds.
- Read states with Freezed pattern matching (`when` / `whenOrNull` /
  `maybeWhen`, or Dart `switch` on the sealed type).

```dart
BlocListener<TeamCubit, TeamState>(
  listener: (context, state) {
    state.whenOrNull(
      error: (error) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error))),
    );
  },
  child: const TeamView(),
)
```

## Testing

- Test Cubits/Blocs with `bloc_test`; mock repositories with `mocktail`.
- Tests mirror `lib/`: `test/features/<feature>/bloc/<file>_test.dart`.

```dart
class MockTeamRepository extends Mock implements TeamRepository {}
```

## After Changing States, Events or Models

Run code generation, then analyze:

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```
