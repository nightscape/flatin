# Fastlane Setup Guide

This guide will help you set up automated deployment to Google Play Store and Apple App Store using Fastlane.

## Prerequisites

1. **Install Fastlane**:
   ```bash
   # macOS (using Homebrew)
   brew install fastlane

   # Or using RubyGems
   sudo gem install fastlane

   # Or using Bundler (recommended)
   bundle install
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

## Android Setup (Google Play Store)

### Project Organization

**Best Practice**: Create **one Google Cloud project per Android app** for better isolation, security, and billing clarity. You can reuse the same service account across multiple apps by linking it in each app's Play Console settings.

### 1. Create a Google Play Service Account

**Part A: Google Cloud Console Setup**

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
   - **Recommendation**: Create one project per app (see project organization notes below)
   - Project name: e.g., "Latin Practice App"
3. Enable **Google Play Android Developer API**:
   - Go to APIs & Services → Library
   - Search for "Google Play Android Developer API"
   - Click Enable
4. Create a **Service Account**:
   - Go to IAM & Admin → Service Accounts
   - Click "Create Service Account"
   - Name: e.g., `latin-practice-service`
   - Grant role: **Service Account User** (or leave blank, permissions are granted in Play Console)
   - Click "Done"
5. Create a JSON key for the service account:
   - Click on the created service account
   - Go to "Keys" tab → "Add Key" → "Create new key"
   - Choose JSON format
   - Download and save securely (e.g., `~/.android/google-play-service-account.json`)

**Part B: Google Play Console Setup (Account-Level)**

6. **Important**: This step is done in **Google Play Console** (not Google Cloud Console). In the current Play Console UI, service accounts are managed through the **"Users and permissions"** page:

   **Steps to Link Service Account:**
   - Go to [Google Play Console](https://play.google.com/console/)
   - In the left sidebar, click **"Users and permissions"**
   - Click the **"Invite new users"** button (top right of the users section)
   - In the "Email address" field, enter your **service account email address**:
     - Format: `service-account-name@project-id.iam.gserviceaccount.com`
     - Example: `latin-practice-service@latin-practice-app.iam.gserviceaccount.com`
   - Under **"Permissions"**, choose how to grant access:
     - **Option A: Account permissions** (recommended for API access)
       - Click the **"Account permissions"** tab
       - Grant: **"Release apps to production"** and **"Release apps to testing tracks"**
     - **Option B: App permissions** (if you want to limit to specific apps)
       - Click **"Add app"** and select your app(s)
       - Grant permissions: **"Release to production"**, **"Release to testing tracks"**
   - Click **"Invite user"** to complete the process

   **Note**: The service account will appear in your users list once invited. You can manage its permissions later by clicking the "Manage" button next to the service account in the users list.

   **Direct URL**: `https://play.google.com/console/u/0/developers/[YOUR_ACCOUNT_ID]/users-and-permissions`
   - Replace `[YOUR_ACCOUNT_ID]` with your developer account ID (found in the URL)

### 2. Configure Android Fastlane

1. Place your service account JSON key file in a secure location (e.g., `~/.android/google-play-service-account.json`)
   - **Important**: This file is already in `.gitignore` and will NOT be committed to Git

2. The `android/fastlane/Appfile` uses environment variables (safe for Git):
   ```ruby
   json_key_file(ENV["GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH"] || "")
   package_name("dev.mauch.flatin")
   ```

3. Set the environment variable for local development:
   ```bash
   # Add to your ~/.zshrc or ~/.bashrc
   export GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH="$HOME/.android/google-play-service-account.json"

   # Or set it for the current session
   export GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_PATH="~/.android/google-play-service-account.json"
   ```

   **Note**: The `Appfile` will be committed to Git (it's safe - it only references environment variables). The actual JSON key file stays on your local machine and in CI/CD secrets.

### 3. Set Up App Signing

**IMPORTANT**: You're currently using debug signing. For production:

1. Generate a keystore:
   ```bash
   keytool -genkey -v -keystore ~/android-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias latin-practice
   ```

2. Create `android/key.properties`:
   ```properties
   storePassword=<your-password>
   keyPassword=<your-password>
   keyAlias=latin-practice
   storeFile=/path/to/android-keystore.jks
   ```

3. Update `android/app/build.gradle.kts` to use the keystore (see Android signing docs)

### 4. Deploy to Play Store

```bash
# Build and upload to Internal Testing
cd android
fastlane internal

# Or upload to Alpha
fastlane alpha

# Or upload to Beta
fastlane beta

# Or upload to Production
fastlane release
```

## iOS Setup (Apple App Store)

### 1. Set Up App Store Connect API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to Users and Access → Keys
3. Create a new API key with **App Manager** or **Admin** role
4. Download the `.p8` key file
5. Note the Key ID and Issuer ID

### 2. Configure iOS Fastlane

1. Update `ios/fastlane/Appfile`:
   ```ruby
   app_identifier("dev.mauch.latin-practice")
   apple_id("your-apple-id@example.com")
   team_id("YOUR_TEAM_ID")
   ```

2. Set environment variables (or use Match for certificates):
   ```bash
   export APP_STORE_CONNECT_API_KEY_KEY_ID="your-key-id"
   export APP_STORE_CONNECT_API_KEY_ISSUER_ID="your-issuer-id"
   export APP_STORE_CONNECT_API_KEY_KEY_FILEPATH="/path/to/AuthKey_XXXXX.p8"
   ```

### 3. Set Up Code Signing

**Option A: Automatic (Recommended)**
- Fastlane will handle certificates automatically
- Make sure you have Xcode installed

**Option B: Manual**
- Use `fastlane match` for shared certificates
- Or manually manage certificates in Xcode

### 4. Deploy to App Store

```bash
# Build and upload to TestFlight
cd ios
fastlane beta

# Or upload to App Store (Production)
fastlane release
```

## CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Stores

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.2'
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true
      - name: Install dependencies
        run: |
          flutter pub get
          bundle install
      - name: Deploy to Play Store
        env:
          GOOGLE_PLAY_SERVICE_ACCOUNT_JSON: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON }}
        run: |
          echo "$GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" > ~/google-play-service-account.json
          cd android
          bundle exec fastlane release

  deploy-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.2'
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true
      - name: Install dependencies
        run: |
          flutter pub get
          bundle install
      - name: Deploy to App Store
        env:
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY_KEY }}
        run: |
          cd ios
          bundle exec fastlane release
```

## Security Best Practices

1. **Never commit**:
   - Service account JSON keys
   - Keystore files and passwords
   - App Store Connect API keys
   - `.env` files with secrets

2. **Use environment variables** or secrets management:
   - GitHub Secrets
   - CI/CD platform secrets
   - `.env` files (gitignored)

3. **Use Match** (for iOS):
   ```bash
   fastlane match development
   fastlane match appstore
   ```

## Common Commands

```bash
# Android
cd android
fastlane build              # Build APK
fastlane build_bundle       # Build AAB
fastlane internal           # Deploy to Internal Testing
fastlane alpha              # Deploy to Alpha
fastlane beta               # Deploy to Beta
fastlane release            # Deploy to Production

# iOS
cd ios
fastlane build              # Build IPA
fastlane beta               # Deploy to TestFlight
fastlane release            # Deploy to App Store
```

## Troubleshooting

- **Android**: Make sure your service account has proper permissions in Play Console
- **iOS**: Ensure your API key has correct permissions and your Team ID is correct
- **Signing**: Verify your signing configuration matches your certificates
- **Flutter**: Run `flutter clean` if you encounter build issues

## Additional Resources

- [Fastlane Documentation](https://docs.fastlane.tools/)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment)
- [Google Play Console](https://play.google.com/console/)
- [App Store Connect](https://appstoreconnect.apple.com/)

