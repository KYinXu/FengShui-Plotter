# Feng Shui Plotter - App Structure

This Flutter app follows a conventional directory structure for better organization and maintainability.

## Directory Structure

```
lib/
├── main.dart                 # App entry point
├── constants/
│   └── app_constants.dart    # App-wide constants (colors, text, spacing)
├── models/
│   └── grid_model.dart       # Data models
├── screens/
│   └── home_screen.dart      # Main screen widgets
├── widgets/
│   ├── grid_input_form.dart  # Reusable form widget
│   └── grid_widget.dart      # Reusable grid display widget
├── services/                 # Business logic and API calls
└── utils/                    # Utility functions and helpers
```

## Key Files to Program In

### 1. **`lib/main.dart`** - App Entry Point
- Configure app theme, routes, and initial screen
- Keep this file minimal

### 2. **`lib/screens/`** - Screen Widgets
- Create new screen files here (e.g., `settings_screen.dart`, `detail_screen.dart`)
- Each screen should be a separate file

### 3. **`lib/widgets/`** - Reusable Components
- Create reusable UI components here
- Keep widgets focused and single-purpose

### 4. **`lib/models/`** - Data Models
- Define your data structures here
- Use classes to represent your app's data

### 5. **`lib/constants/`** - App Constants
- Store colors, text, spacing, and other constants
- Makes it easy to maintain consistent styling

### 6. **`lib/services/`** - Business Logic
- API calls, database operations, calculations
- Keep business logic separate from UI

### 7. **`lib/utils/`** - Helper Functions
- Utility functions, extensions, and helpers
- Common functionality used across the app

## Best Practices

1. **Single Responsibility**: Each file should have one clear purpose
2. **Import Organization**: Use relative imports for files in the same project
3. **Naming Conventions**: Use snake_case for files and camelCase for classes
4. **Separation of Concerns**: Keep UI, business logic, and data separate

## Adding New Features

1. Create models in `lib/models/`
2. Add constants to `lib/constants/`
3. Create widgets in `lib/widgets/`
4. Build screens in `lib/screens/`
5. Add services in `lib/services/` if needed
6. Update `main.dart` to include new screens/routes 