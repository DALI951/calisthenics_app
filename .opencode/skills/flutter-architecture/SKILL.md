# Flutter Architecture

Rules for this repo's Flutter code. Do not deviate without a documented reason.

- Feature-first layout: `lib/features/<feature>/{data,domain,presentation}` + `lib/app/{router,theme,configuration}` + `lib/core/{constants,errors,widgets,services}`.
- State: Riverpod (flutter_riverpod 3.x) + riverpod_annotation + riverpod_generator. Providers live in `data/` next to their repositories.
- Models: Freezed + json_serializable. Never raw `Map<String, dynamic>` in UI. Maps allowed only at Firebase boundaries, converted immediately.
- Widgets contain NO business logic. Repositories are the only data source. ViewModels (Notifier/AsyncNotifier) coordinate.
- Domain logic must be testable without widgets — pure Dart classes, unit-tested.
- Immutable state. No global mutable state.
- Riverpod 3 API notes: `AsyncValue.value` is nullable (no `.valueOrNull`); codegen providers export base classes from riverpod_annotation (no flutter_riverpod import needed in provider-only files).
- Codegen: `dart run build_runner build` after adding freezed/riverpod-annotated files. Generated `*.g.dart`/`*.freezed.dart` are gitignored and regenerated in CI — never hand-edit, never commit manually.

## Non-negotiables
- Every screen: loading, success, empty, error + retry states.
- Every list needs an intentional empty state.
- No dead buttons — unimplemented features are visibly marked "coming in Phase N".
- No raw colors/dims in widgets — use theme tokens (app_colors/app_spacing/app_radius) and design-system components in core/widgets.