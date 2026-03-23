# Vocabulary Battle (User App)

Flutter client for players in the Vocabulary Battle game ecosystem.
Players can join active sessions, create question sets, battle opponents, and practice with AI-generated challenges.

## Core Features

- Google sign-in with Firebase Auth
- Real-time game session sync from Cloud Firestore
- Question creation workflow (manual + AI-assisted)
- Practice vs AI mode
- Multiplayer battle mode with timer and per-letter categories
- Results and progress summary
- Push notification support (Firebase Messaging)

## Game Modes

| Mode | Total Questions | Breakdown |
| --- | ---: | --- |
| Quick | 15 | 3 x 4 + 3 random |
| Normal | 23 | 3 x 6 + 5 random |
| Challenge | 35 | 3 x 10 + 5 random |

## Tech Stack

- Flutter + Dart
- Firebase Auth, Firestore, Realtime Database, Cloud Messaging
- Riverpod for state management
- Dio for HTTP
- Hive for local persistence

## Project Setup

### 1. Prerequisites

- Flutter SDK (Dart SDK `^3.6.0`)
- Xcode (for iOS/macOS builds)
- Android Studio and Android SDK (for Android builds)
- A Firebase project configured for this app

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure environment variables

Copy the example env file and fill in values:

```bash
cp .env.example .env
```

Required keys:

- `ALLE_AI_API_KEY` - used for AI question generation requests
- `OPENAI_API_KEY` - reserved for additional AI integration

### 4. Firebase config

This app expects Firebase platform config files and generated options:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`

If you rotate Firebase projects, regenerate platform configs and `firebase_options.dart`.

### 5. Run the app

```bash
flutter run
```

## Useful Commands

```bash
flutter analyze
flutter test
```

## High-Level Structure

```text
lib/
  core/          # constants and AI configuration
  models/        # domain models (users, sessions, questions, modes)
  providers/     # Riverpod providers
  screens/       # app screens (home, battle, profile, AI mode)
  services/      # firebase/auth/ai/notification logic
  widgets/       # reusable UI components
```

## Notes

- `.env` files are intentionally git-ignored.
- `.env.example` is committed for onboarding.
- The app currently sends AI requests through the Alle AI endpoint (`https://api.alle-ai.com/api/v1`).
