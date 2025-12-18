# VAVI - Voice Assistant for Visually Impaired

An indoor navigation application for visually impaired users built with Flutter.

## Features

- **Accessible UI**: High contrast colors, large touch targets, screen reader support
- **Voice Input**: Speech-to-text for selecting nodes via voice commands
- **Audio Feedback**: Text-to-speech for all interactions
- **Node Selection**: Dropdown menus for source and target node selection
- **Path Finding**: Shortest path calculation (placeholder implementation)

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── node.dart            # Node data model
├── screens/
│   └── landing_screen.dart  # Main landing/navigation setup screen
└── services/
    └── accessibility_service.dart  # TTS and accessibility services
```

## Accessibility Features

- **Semantics Widgets**: All interactive elements have proper semantic labels
- **Screen Reader Support**: Full support for TalkBack (Android) and VoiceOver (iOS)
- **High Contrast**: Color scheme optimized for visually impaired users
- **Large Touch Targets**: Minimum 48x48dp touch targets
- **Text-to-Speech**: Audio feedback for all user interactions
- **Haptic Feedback**: Vibration feedback for important actions

## TODO

- [ ] Integrate with graph engine for actual path calculation
- [ ] Connect to backend API for node data
- [ ] Implement fuzzy matching for voice recognition
- [ ] Add path visualization screen
- [ ] Support multiple languages
- [ ] Add voice customization options
- [ ] Implement actual indoor navigation with AR/beacon support

## License

This project is part of a senior project.

