# Craft Stash

A mobile app for managing fabric inventory, tracking store events, and discovering creative project ideas.

Built with Flutter and Firebase.

## Features

- **Calendar**: Browse upcoming events and classes with filtering by price
- **Inventory**: Manage your personal fabric and supply inventory with Firebase sync
- **Ideas**: Browse creative project ideas
- **Account Management**: Create accounts, log in, and manage your profile

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Platforms**: Android, iOS, Web

## Getting Started

### Prerequisites

- Flutter SDK (^3.5.4)
- Firebase project (see setup below)

### Setup

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd craft_stash
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Set up Firebase:
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Run `flutterfire configure` to generate `lib/firebase_options.dart`
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to their respective directories

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
  main.dart                 # App entry point and navigation
  firebase_options.dart     # Firebase configuration
  screens/                  # App screens
    home_page.dart          # Home screen with menu grid
    calendar_page.dart      # Events calendar
    inventory_page.dart     # Inventory management
    ideas_page.dart         # Project ideas
    login_page.dart         # User login
    create_account_page.dart # Account registration
    account_page.dart       # User profile
    shop_page.dart          # Shop page
    consignment_page.dart   # Consignment page
    newsletter_page.dart    # Newsletter page
    request_class_page.dart # Class request form
  widgets/
    main_nav_bar.dart       # Bottom navigation bar
```

## License

This project is for portfolio demonstration purposes.