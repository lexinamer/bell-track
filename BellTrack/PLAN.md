# BellTrack Redesign Plan

## Design Decisions (from your input)
- **Dark-only theme** — always dark gray, like Linear
- **4 tabs** — Training, History, Insights, Settings (Exercises moves into Settings)
- **Consolidate Exercises/Complexes** — merge into one unified list (no segmented picker)
- **Softer purple accent** — lighten to ~#7C5CFC for better dark-mode contrast

---

## Phase 1: Theme System (Dark-Only Foundation)

### 1a. Update all 6 color assets in Assets.xcassets
Remove light/dark variants — single universal values:
- **Background**: `#1A1A1E` (near-black gray)
- **Surface**: `#2A2A2E` (card/elevated surface)
- **TextPrimary**: `#F5F5F7` (bright white-ish)
- **TextSecondary**: `#8E8E93` (muted gray)
- **Border**: `#3A3A3E` (subtle dark border)
- **AccentColor**: `#7C5CFC` (softer purple)

### 1b. Update Colors.swift
- Update block palette for dark backgrounds (brighter, more vibrant purples)
- Update `unassignedWorkoutColor` for dark context
- Add new semantic colors: `surfaceSecondary`, `destructive`, `success`

### 1c. Update Theme.swift
- No structural changes needed, spacing/fonts are fine
- Add `Theme.Font.statValue` and `Theme.Font.statLabel` for BlockDetailView stats

### 1d. Force dark mode in BellTrackApp.swift
- Add `.preferredColorScheme(.dark)` to the WindowGroup

---

## Phase 2: Navigation Restructure

### 2a. ContentView.swift — 4 tabs
- Remove Exercises tab
- Tabs: Training, History, Insights, Settings

### 2b. SettingsView.swift — Add Exercises link
- Add "Exercises" NavigationLink row that pushes to ExercisesView
- Keep feedback, logout, delete account, version

### 2c. ExercisesView.swift — Consolidate exercises + complexes
- Remove the segmented picker (`ExerciseTab` enum)
- Show a single flat list: exercises first, then complexes (with a "Complexes" section header)
- Keep all existing CRUD, context menus, navigation destinations

---

## Phase 3: View-by-View Dark Mode Cleanup

### 3a. Replace all hardcoded colors
Across all views, replace:
- `Color(.systemBackground)` → `Color.brand.surface`
- `Color(.systemGray6)` → `Color.brand.surface` or new `surfaceSecondary`
- `Color(.systemGray5)` → `Color.brand.border`
- `Color(.systemGray4)` → `Color.brand.border`
- `Color(.secondarySystemBackground)` → `Color.brand.surface`
- `Color(.systemGroupedBackground)` → `Color.brand.background`
- `Color(.tertiarySystemFill)` → `Color.brand.surface`
- `Color.black.opacity(...)` shadows → `Color.black.opacity(0.3)` (stronger for dark)
- `.foregroundColor(.primary)` → `Color.brand.textPrimary`
- `.foregroundColor(.secondary)` → `Color.brand.textSecondary`

### 3b. Replace hardcoded font sizes with Theme.Font tokens
- BlockDetailView: `.font(.system(size: 28, weight: .bold))` → `Theme.Font.pageTitle`
- BlockDetailView stat items: `.font(.system(size: 20, weight: .semibold))` → new `Theme.Font.statValue`
- BlockFormView duration chips: `.font(.system(size: 14, ...))` → `Theme.Font.cardCaption`
- LoginView: `.font(.system(size: 28, weight: .bold))` → `Theme.Font.pageTitle`

### 3c. Replace hardcoded spacing with Theme.Space tokens
- WorkoutFormView: `spacing: 32` → `Theme.Space.xl`
- WorkoutFormView: `padding(.horizontal, 16)` → `Theme.Space.md`
- WorkoutFormView: `padding(.vertical, 12)` → `Theme.Space.smp`
- BlockFormView: `spacing: 4` → `Theme.Space.xs`
- WorkoutCard: `spacing: 2` → `Theme.Space.xs`

---

## Phase 4: Component Polish

### 4a. WorkoutCard
- Background: `Color.brand.surface` instead of `Color(.systemBackground)`
- Expanded section: `Color.brand.background` instead of `Color(.systemGray6).opacity(0.3)`
- Shadow: adjust for dark mode (more subtle or remove)

### 4b. BlockCard
- Keep colored backgrounds — they pop well on dark
- Adjust shadow opacity for dark context

### 4c. WorkoutFormView
- Form field backgrounds: `Color.brand.surface`
- Input field backgrounds: `Color.brand.background` (recessed look)
- Overall background: `Color.brand.background`

### 4d. BlockFormView
- Ensure Form styling works with dark theme
- `.scrollContentBackground(.hidden)` + `.background(Color.brand.background)`

### 4e. LoginView
- Background: `Color.brand.background`
- Input fields: `Color.brand.surface` with `Color.brand.border` stroke
- Already mostly uses Color.brand — just needs asset updates

### 4f. InsightsView
- Bar backgrounds: `Color.brand.surface` instead of `Color(.systemGray5)`
- Filter chips: `Color.brand.surface` instead of `Color(.systemGray4)` stroke

---

## Phase 5: Auth Views
- LoginView, SignupView, PasswordResetView — update any remaining system colors
- These are already mostly using Color.brand, so mainly benefit from the asset updates

---

## Files Modified (estimated)
1. `Assets.xcassets/` — 6 colorset Contents.json files
2. `Theme/Colors.swift`
3. `Theme/Theme.swift`
4. `BellTrackApp.swift`
5. `Views/ContentView.swift`
6. `Views/Tabs/SettingsView.swift`
7. `Views/Pages/ExercisesView.swift`
8. `Views/Components/WorkoutCard.swift`
9. `Views/Components/BlockCard.swift`
10. `Views/Tabs/TrainingView.swift`
11. `Views/Tabs/HistoryView.swift`
12. `Views/Tabs/InsightsView.swift`
13. `Views/Pages/BlockDetailView.swift`
14. `Views/Forms/WorkoutFormView.swift`
15. `Views/Forms/BlockFormView.swift`
16. `Views/Forms/ExerciseFormView.swift`
17. `Views/Auth/LoginView.swift`
18. `Views/Auth/SignupView.swift`
19. `Views/Auth/PasswordResetView.swift`

## Files NOT Modified
- `Models/Models.swift` — no changes needed
- `Services/` — no changes needed
- `ViewModels/` — no changes needed (logic stays the same)
- `Views/Components/MuscleTags.swift`
- `Views/Components/SimpleCard.swift`
- `Views/Forms/ComplexFormView.swift`
- `Views/Forms/WorkoutTemplateFormView.swift`
- `Views/Pages/ExerciseDetailView.swift`
