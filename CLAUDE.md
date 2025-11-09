# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Multi-Bank Aggregation App** - A Flutter application that aggregates accounts from multiple banking services (VBank, ABank, SBank) through OpenBanking APIs. Built for VTB Hack 2025.

### Key Features
1. Multi-bank account aggregation across 3 banks
2. Smart savings account creation (auto-selects best interest rates)
3. Smart loan application (auto-selects lowest interest rates)
4. Inter-bank and intra-bank transfers
5. Smart payment selection (highest cashback)
6. ATM locator with Yandex Maps integration
7. PDF account statement generation
8. Transaction analytics for ML export
9. Consent management (auto and manual approval)
10. **Automatic consent polling** - Detects when bank-side approvals complete (10s intervals)
11. **In-app notifications** - Real-time user notifications with unread count badges

### Tech Stack
- Flutter SDK: ^3.9.2
- State Management: Provider
- API Client: HTTP & Dio
- Maps: Yandex MapKit
- PDF Generation: pdf + printing packages
- Local Storage: shared_preferences

## Development Commands

### Running the Application
```bash
# Install dependencies first
flutter pub get

# Run on Android emulator/device
flutter run

# Run with specific entry point
flutter run lib/main.dart

# Run in release mode
flutter run --release
```

### API Configuration
The app uses credentials from `lib/config/api_config.dart`:
- Client ID: `team201`
- Client Secret: (configured in api_config.dart)
- Bank URLs:
  - VBank: https://vbank.open.bankingapi.ru
  - ABank: https://abank.open.bankingapi.ru
  - SBank: https://sbank.open.bankingapi.ru

### Linting & Analysis
```bash
# Analyze code for issues
flutter analyze

# Check for outdated packages
flutter pub outdated
```

### Testing
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run a single test file
flutter test test/widget_test.dart
```

### Building
```bash
# Build Android APK (debug)
flutter build apk

# Build Android APK (release)
flutter build apk --release

# Build Android App Bundle
flutter build appbundle
```

## Architecture

### Directory Structure
```
lib/
├── config/           # Configuration files (API, theme)
├── models/           # Data models (BankAccount, Transaction, Product, Consent)
├── services/         # Business logic services
│   ├── auth_service.dart              # Authentication & consent management
│   ├── bank_api_service.dart          # Banking API client
│   ├── consent_polling_service.dart   # Auto-polls pending consent statuses
│   ├── notification_service.dart      # In-app notification system
│   ├── pdf_service.dart               # PDF generation
│   └── analytics_service.dart         # Transaction analysis
├── providers/        # State management providers
│   ├── account_provider.dart      # Account aggregation state
│   ├── product_provider.dart      # Products & best rate selection
│   └── transfer_provider.dart     # Money transfer logic
├── screens/          # UI screens
│   ├── login_screen.dart
│   ├── home_screen.dart                   # Dashboard with aggregated accounts
│   ├── accounts_screen.dart               # Account details & transactions
│   ├── products_screen.dart               # Deposits, loans, cards
│   ├── transfer_screen.dart               # Inter-bank transfers
│   ├── atm_map_screen.dart                # ATM locations on map
│   ├── notifications_screen.dart          # In-app notifications center
│   ├── consent_management_screen.dart     # Manual consent management
│   └── profile_screen.dart                # User profile & settings
└── main.dart         # App entry point
```

### Key Components

#### 1. Authentication Flow
- User enters Client ID (format: `team201-10`)
- System fetches bank tokens from all 3 banks
- Creates consents for account access, payments, and product management
- Stores tokens and consents in SharedPreferences

#### 2. Account Aggregation
`AccountProvider` fetches accounts from all banks in parallel:
```dart
// Fetches accounts from vbank, abank, sbank
await accountProvider.fetchAllAccounts();
```

#### 3. Smart Product Selection
`ProductProvider` compares products across banks:
```dart
// Get best deposit rate
final bestDeposit = productProvider.getBestDeposit(amount: 50000);

// Get best loan (lowest rate)
final bestLoan = productProvider.getBestLoan(amount: 100000);
```

#### 4. Inter-Bank Transfers
`TransferProvider` handles transfers with automatic consent:
```dart
await transferProvider.transferMoney(
  fromAccount: account1,  // Can be from any bank
  toAccount: account2,    // Can be to any bank
  amount: 1000.0,
);
```

#### 5. Consent Management
Three types of consents:
- **Account Consent**: Read accounts, balances, transactions
- **Payment Consent**: VRP (Variable Recurring Payments)
- **Product Agreement Consent**: Open/close products

Banks handle consent differently:
- VBank & ABank: Auto-approve
- SBank: Requires manual user approval

#### 6. Consent Polling Service
`ConsentPollingService` automatically checks pending consent statuses:
```dart
// Polls every 10 seconds (max 20 minutes = 120 attempts)
// Automatically starts when pending consents are detected
// Triggers callbacks when consents are approved
pollingService.onConsentApproved((bankCode) {
  // Handle approval notification
});
```

**Critical Implementation Details**:
- **SBank uses `request_id`** instead of `consent_id` in responses
- **Status checks require base team ID** in header: `x-fapi-interaction-id: team201` (NOT `team201-10`)
- Code automatically extracts base team ID from full client ID

#### 7. Notification System
`NotificationService` manages in-app notifications:
```dart
// Add notification
notificationService.addNotification(
  title: 'Transfer Complete',
  message: 'Successfully sent 1000 RUB',
  type: NotificationType.success,
);

// Check unread count (displayed in UI badge)
final unreadCount = notificationService.unreadCount;
```

Consent refresh methods in `AuthService`:
```dart
// Refresh single consent type for a bank
await authService.refreshAccountConsentStatus('sbank');
await authService.refreshPaymentConsentStatus('sbank');
await authService.refreshProductConsentStatus('sbank');

// Refresh all consents for a specific bank
await authService.refreshAllConsentsForBank('sbank');

// Refresh all consents for all banks
await authService.refreshAllConsents();

// Check consent status
final hasPending = authService.hasPendingConsents;
final pendingBanks = authService.banksWithPendingConsents;
```

### Banking API Integration

#### Authentication
```dart
POST /auth/bank-token
  ?client_id=team201
  &client_secret=SECRET
```

#### Fetching Accounts
```dart
GET /accounts?client_id=team201-10
Headers:
  Authorization: Bearer TOKEN
  x-consent-id: CONSENT_ID
  x-requesting-bank: team201
```

#### Creating Payment
```dart
POST /payments?client_id=team201-10
Headers:
  Authorization: Bearer TOKEN
  x-payment-consent-id: CONSENT_ID
Body: {
  "data": {
    "initiation": {
      "debtorAccount": { "identification": "..." },
      "creditorAccount": {
        "identification": "...",
        "bank_code": "vbank"  // For inter-bank
      }
    }
  }
}
```

### State Management Pattern

Using Provider with ChangeNotifierProxy:
```dart
MultiProvider(
  providers: [
    Provider<AuthService>(),
    ChangeNotifierProvider<NotificationService>(),
    ProxyProvider<AuthService, ConsentPollingService>(),
    ChangeNotifierProxyProvider<AuthService, AccountProvider>(
      // Also receives NotificationService
    ),
    ChangeNotifierProxyProvider<AuthService, ProductProvider>(),
    ChangeNotifierProxyProvider<AuthService, TransferProvider>(),
  ],
)
```

**Provider Pattern Notes**:
- `NotificationService` is a standalone `ChangeNotifierProvider`
- Account, Product, and Transfer providers receive both `AuthService` and `NotificationService`
- `ConsentPollingService` is disposed automatically when app closes

### UI Theme

VTB-inspired design with:
- Primary Blue: `#0028FF`
- Dark Blue: `#002882`
- Cards with rounded corners (16px)
- Elevation and shadows for depth
- Clean, modern layout

## Common Tasks

### Adding a New Bank
1. Add bank code to `ApiConfig.supportedBanks`
2. Add base URL to `ApiConfig`
3. Update bank name mapping
4. Add ATM locations in `atm_map_screen.dart`

### Adding New API Endpoint
1. Add method to `BankApiService`
2. Update corresponding Provider if needed
3. Call from UI screen

### Debugging API Issues
```dart
// Enable HTTP logging
import 'package:dio/dio.dart';
dio.interceptors.add(LogInterceptor(
  requestBody: true,
  responseBody: true,
));
```

### Testing Consent Flow
1. Login with client ID
2. App auto-creates consents
3. Polling starts automatically for pending consents
4. For SBank, manual approval needed in bank UI
5. Within 10 seconds of bank approval, app detects change
6. Notification appears confirming approval

### Adding Notifications to Features
When implementing new features, integrate notifications:
```dart
final notificationService = context.read<NotificationService>();

// On success
notificationService.addNotification(
  title: 'Success',
  message: 'Operation completed',
  type: NotificationType.success,
);

// On error
notificationService.addNotification(
  title: 'Error',
  message: error.toString(),
  type: NotificationType.error,
);
```

### Handling Pending Consents (SBank)
When consents require manual approval:
1. Consent is created with status `pending` or `awaiting_authorization`
2. User must visit bank website to approve consent
3. After bank-side approval, use `refreshAccountConsentStatus(bankCode)` to update local status
4. Check `authService.hasPendingConsents` to detect banks needing approval
5. Get list with `authService.banksWithPendingConsents`

## Important Notes

- Always check consent approval before API calls
- Handle token expiration (tokens valid for 24 hours)
- Inter-bank transfers require `bank_code` in creditor account
- PDF generation requires storage permissions on Android
- Yandex Maps requires API key initialization

### SBank API Quirks (Critical!)
- **Uses `request_id` not `consent_id`**: Extract with fallback chain: `consent_id` → `consentId` → `request_id`
- **Status check header**: Must send `x-fapi-interaction-id: team201` (base team ID, not `team201-10`)
- **Code handles this automatically**: Extracts base ID from full client ID before API calls

### Consent Status Management
- Approved consent states: `approved` or `active`
- Pending consent states: `pending` or `awaiting_authorization`
- Use `refreshAccountConsentStatus(bankCode)` to poll consent status from bank
- SBank requires manual approval - poll status after user approves on bank website
- Consent IDs are extracted from both flat and nested response structures

**Important: SBank uses `request_id` instead of `consent_id`**
- SBank returns `request_id` field (e.g., "req-4de5076a2382") in consent creation responses
- Other banks (VBank, ABank) return `consent_id`
- The code handles both by checking: `consent_id` → `consentId` → `request_id`
- The `request_id` is used for all subsequent status checks

### API Retry Mechanism
- All bank API calls use exponential backoff retry (3 attempts by default)
- Initial delay: 2 seconds, doubles on each retry
- Handles: SocketException, TimeoutException, HttpException
- 30-second timeout per request

## Troubleshooting

### Issue: "Consent not approved"
**Solution**: Check if bank requires manual approval (SBank). For auto-approved banks, verify client_id format.

### Issue: "Failed to fetch accounts"
**Solution**: Ensure tokens are valid and consents exist. Call `authService.initialize()` on app start.

### Issue: Maps not showing
**Solution**: Verify Yandex Maps API key in `api_config.dart` and check Android permissions.

### Issue: PDF generation fails
**Solution**: Ensure storage permissions granted. Check Android API level for scoped storage.

### Issue: SBank consent status check returns 400
**Solution**: Verify the `x-fapi-interaction-id` header is using base team ID (`team201`), not full client ID (`team201-10`). Check console logs for "Base team ID for x-fapi-interaction-id" to confirm extraction.

### Issue: SBank consent ID is empty
**Solution**: Response likely contains `request_id` instead of `consent_id`. Check console logs for "Using request_id from SBank". Code should handle this automatically with fallback chain.

### Issue: Consent polling doesn't detect approval
**Solution**:
1. Check console for polling logs (`[ConsentPolling] Poll attempt X/120`)
2. Verify consent was approved on bank website
3. Ensure polling service is started (check for `Starting polling for banks`)
4. Manual trigger: Use "Check Status" button in Consent Management screen

### Issue: Consent approved on bank website but app shows "pending"
**Solution**: The app needs to poll the bank API to refresh consent status. Call `authService.refreshAccountConsentStatus(bankCode)` or `authService.refreshAllConsentsForBank(bankCode)` after user approves on bank website. Consider implementing periodic polling or a manual "Refresh" button in the UI.

### Issue: Empty consent_id in response
**Solution**: Check API response structure. The code handles both nested (`data.consent_id`) and flat (`consent_id`) structures. If consent_id is empty, the bank may not have returned it properly - check response body in logs.
