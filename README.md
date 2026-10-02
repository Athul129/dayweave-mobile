# Dayweave Mobile

Dayweave is a calm daily planning and productivity workspace. This repository contains the native Flutter mobile application for Android and iOS.

## About

The mobile client is designed as a native Dayweave experience. It shares the product’s visual language with the web application while using Flutter-native screens, navigation, state management, and platform integration.

## Current Features

- Supabase authentication
- Email login and sign up
- Session restoration and reactive authentication state
- Sign out
- Native Today experience
- Daily intention loading and editing
- Today task state and local-date handling
- Morning, Midday, and Afternoon task grouping
- Progress tracking and remaining-duration summaries
- Task selection
- Task completion and uncompletion
- Up Next derivation
- Native bottom navigation for Today, Week, Notes, and History destinations
- Riverpod state management
- Supabase-backed repositories and services

The Week, Notes, and History destinations currently contain foundation or placeholder experiences. Task creation and editing, Brain Dump, search, filters, Later, Focus Mode, reflection, offline synchronization, and sharing are planned work.

## Tech Stack

- Flutter
- Dart
- `flutter_riverpod`
- `supabase_flutter`
- Supabase services backed by PostgreSQL
- Android and iOS platform runners

## Project Structure

```text
lib/
├── app.dart                         App shell and authentication gate
├── core/                            Theme, configuration, routing, dates, errors
├── features/
│   ├── auth/                        Authentication state and screens
│   ├── shell/                       Authenticated navigation shell
│   └── today/                       Today state, controllers, and presentation
├── models/                           Domain models and task model
├── repositories/                     Supabase-backed data access boundaries
├── services/                         Supabase and authentication services/providers
└── widgets/                          Shared placeholder widgets

assets/
├── fonts/                            Fraunces and DM Sans font assets
└── images/                           Dayweave marks and supporting artwork

test/                                  Focused auth, Today, and widget tests
android/                               Android platform project
ios/                                   iOS platform project
```

## Architecture

The app uses a feature-oriented Flutter structure with Riverpod providers and controllers. Services wrap Supabase access, repositories define data operations, and feature controllers coordinate state and mutations. Date-only product values use the local `LocalDate` abstraction so Today behavior follows the user’s local calendar date.

Authentication is initialized before the app starts. The root authentication gate selects the loading, signed-out, signed-in, or error experience from reactive auth state.

## Setup

Requirements:

- Flutter SDK with Android or iOS tooling as appropriate
- A Supabase project configured for the Dayweave application

```bash
git clone <repository-url>
cd mobile
flutter pub get
```

The app reads its Supabase configuration from build-time defines. Supply the project URL and public publishable key when running the app:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Only the public/publishable client key belongs in the mobile application. Never place a service-role key or other private credential in source, local configuration committed to Git, or an app build.

## Build

Build a debug Android APK with:

```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Generated APKs are local build artifacts and should not be committed. Release signing configuration and signing keys must remain private unless a deliberate release workflow is added.

Run on a connected Android device or emulator with `flutter run`. Run on iOS with `flutter run` from macOS with Xcode and an available iOS target.

## Testing

```bash
flutter analyze
flutter test
```

The current project validation passes with no analyzer issues and all existing tests passing.

## Design

The mobile UI uses a warm paper background, pale blue Morning Check-in surface, sage Up Next surface, marigold accents, dark ink typography, and native mobile-first interaction. Fraunces is used for editorial and display headings, while DM Sans is used for body and interface text.

The visual language is inspired by the broader Dayweave product. The mobile client is implemented with native Flutter widgets and is not a WebView or a copied web implementation.

## Status

### Implemented

Authentication, session handling, the native Today experience, daily intention state, task completion and selection, progress derivation, Up Next state, repositories, and the authenticated navigation shell.

### In progress

The mobile product foundation is being expanded beyond Today. Some navigation destinations remain placeholders while their feature phases are developed.

### Planned

Task creation and editing, Brain Dump, search and filters, Later, Focus Mode, reflection, offline support, and advanced task interactions.

## Security

- Never commit Supabase service-role credentials or private keys.
- Never commit local secrets or dart-define files containing credentials.
- Client configuration uses only the public/publishable Supabase key.
- Android and iOS signing keys must remain private.

## Contributing

Keep changes focused on the mobile application. Before committing:

```bash
flutter analyze
flutter test
```

Do not commit generated build output, `.dart_tool/`, local SDK settings, APK/AAB files, signing keys, or private configuration.
