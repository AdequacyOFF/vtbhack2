# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-bank aggregator Flutter application for VTB Hack 2025. Connects to 3 OpenBanking APIs (VBank, ABank, SBank) to aggregate accounts, create smart financial products, and provide personalized news based on spending patterns.

**Tech Stack**: Flutter 3.9.2, Dart, Provider (state management), Yandex MapKit, PDF generation

## Development Commands

### Installation & Setup
```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run on specific device
flutter run -d <device-id>
```

### Testing & Analysis
```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Static analysis
flutter analyze

# Format code
flutter format lib/
```

### Building
```bash
# Debug APK
flutter build apk

# Release APK
flutter build apk --release

# App Bundle for Google Play
flutter build appbundle
```

### Debugging
```bash
# List available devices
flutter devices

# Run with verbose logging
flutter run -v

# Clear build cache (if encountering issues)
flutter clean && flutter pub get
```

## Architecture & Key Concepts

### Service Layer Pattern
The app follows a clean architecture with three main layers:
- **Services**: Business logic and API communication (auth, bank API, consent polling, notifications)
- **Providers**: State management using Provider pattern (account, product, transfer, news)
- **Screens**: UI components

### Critical Implementation Details

#### 1. Composite Balance Keys (`bankCode:accountId`)
**IMPORTANT**: Accounts use composite keys to prevent ID collisions across banks.

```dart
// Correct way to access balances
String balanceKey = '${account.bankCode}:${account.accountId}';
double balance = balances[balanceKey];

// Provider helper methods
double balance = accountProvider.getBalance(account);
double balance = accountProvider.getBalanceByIds(bankCode, accountId);
```

**Why**: Different banks can return accounts with identical IDs. Using composite keys prevents data corruption.

#### 2. Consent Management Lifecycle

Three consent types per bank:
- **Account Consent**: Access to accounts, balances, transactions
- **Payment Consent**: VRP (Variable Recurring Payments) for transfers
- **Product Agreement Consent**: Create/manage deposits, loans, cards

**Auto-approval behavior**:
- VBank & ABank: Auto-approved immediately
- SBank: Requires manual approval on bank website

**Status flow**:
- `pending` / `AwaitingAuthorization` → Waiting for approval
- `approved` / `active` / `Authorized` → Approved and usable
- `rejected` → Denied

#### 3. Consent Polling Service

`ConsentPollingService` automatically polls for consent status updates:
- Interval: Every 10 seconds
- Max attempts: 120 (20 minutes total)
- Auto-starts when pending consents exist
- Auto-stops when all approved or max attempts reached

**Usage in screens**:
```dart
final pollingService = context.read<ConsentPollingService>();

// Register callback for when consent approved
pollingService.onConsentApproved((bankCode) {
  // Refresh accounts or show success message
});

// Start polling
pollingService.startPolling();
```

#### 4. SBank API Quirks

SBank has different response formats:
- Uses `request_id` instead of `consent_id` in initial response
- When approved, consent ID changes from `req-*` to `consent-*`
- Requires `x-fapi-interaction-id` header with base team ID (e.g., `team201` from `team201-10`)

**Handled in**: `lib/services/bank_api_service.dart:330-406` (consent status checking)

#### 5. Client ID Format

- Format: `team<number>-<user_id>` (e.g., `team201-10`)
- Base team ID: `team<number>` (e.g., `team201`)
- Base team ID used for SBank's `x-fapi-interaction-id` header
- Stored in `shared_preferences` for persistence

#### 6. Automatic Data Loading

When user logs in, the app automatically:
1. Fetches bank tokens for all 3 banks
2. Creates account consents (if missing)
3. Loads all accounts from approved banks
4. Fetches balances for each account
5. Loads 365 days of transaction history
6. Generates personalized news based on spending categories

**Code**: `lib/providers/account_provider.dart:63-176` (fetchAllAccounts)

#### 7. News Personalization

ML service integration at `http://81.200.148.163:51000/news`:
- Analyzes transaction categories from spending history
- Sends top categories as topics
- Receives personalized news articles with base64 images

**Flow**: Transactions → Categories → ML Service → News Feed

#### 8. MCC Code Transaction Categorization

The app uses a **three-tier categorization system** for expense tracking:

**Priority 1: MCC Codes** (Merchant Category Codes)
- When transaction has `merchant.mccCode`, uses ISO 18245 standard mapping
- Most reliable method - standardized across all banks
- Example: MCC 5651 = "Family Clothing Stores" → Shopping category

**Priority 2: Merchant Category**
- Falls back to `merchant.category` from API if MCC unavailable
- Maps API categories (e.g., "clothing", "restaurant") to app categories

**Priority 3: Keyword Matching**
- Final fallback: analyzes `transactionInformation` for keywords
- Matches Russian and English terms in transaction descriptions

**Implementation:**
- `lib/models/merchant.dart`: Merchant data model with mccCode field
- `lib/models/transaction.dart`: BankTransaction.category getter with 3-tier logic
- `lib/services/mcc_category_service.dart`: MCC → Category mapping service
- `mccCodes.txt`: Complete ISO 18245 MCC code reference (981 codes)

**Category Mappings:**
- Еда (Food): MCC 5411-5499, 5811-5815 (grocery, restaurants, fast food)
- Транспорт (Transport): MCC 3000-3299, 3351-3441, 4111+, 5511-5599 (airlines, car rental, gas)
- Покупки (Shopping): MCC 5200-5399, 5611-5699 (retail, clothing, department stores)
- Развлечения (Entertainment): MCC 7800-7999 (movies, sports, recreation)
- Здоровье (Health): MCC 5912, 5975-5977, 8011-8099 (pharmacies, doctors, hospitals)
- Коммунальные услуги (Utilities): MCC 4812-4899, 4900 (telecom, utilities)
- Образование (Education): MCC 5192, 5942-5943, 8211-8299 (books, schools)
- Другое (Other): All other MCC codes

**Debug Logging:**
The expenses optimization service logs MCC codes and merchant data for each transaction:
```
[ExpensesOptimization] Transaction #1: 28519.78 ₽,
  Category: "Покупки", MCC: "5651", Merchant: "Спортмастер"
```

## API Configuration

### Base URLs
- VBank: `https://vbank.open.bankingapi.ru`
- ABank: `https://abank.open.bankingapi.ru`
- SBank: `https://sbank.open.bankingapi.ru`

### Authentication Headers
```dart
'Authorization': 'Bearer ${token.accessToken}'
'x-consent-id': consentId  // For account/transaction endpoints
'x-requesting-bank': ApiConfig.clientId  // Team ID (e.g., 'team201')
'x-fapi-interaction-id': baseTeamId  // Base team ID for SBank status checks
```

### Retry Logic

All API calls in `BankApiService` use exponential backoff retry:
- Max retries: 3
- Initial delay: 2 seconds
- Timeout per request: 30 seconds
- Handles: `SocketException`, `TimeoutException`, `HttpException`

## Common Tasks

### Adding a New Bank
1. Add bank config to `lib/config/api_config.dart`
2. Add to `supportedBanks` list in `AuthService`
3. Update consent creation logic to handle bank-specific quirks

### Modifying Consent Logic
- **Creation**: `lib/services/bank_api_service.dart:113-327`
- **Status checking**: `lib/services/bank_api_service.dart:330-528`
- **Storage/retrieval**: `lib/services/auth_service.dart`
- **Polling**: `lib/services/consent_polling_service.dart`

### Working with Transactions
- Transactions auto-load with accounts (365 days)
- Categorization happens in `lib/services/analytics_service.dart`
- Format: ISO 8601 strings, converted to DateTime for sorting/display

### PDF Generation
Uses `pdf` and `printing` packages:
- **Service**: `lib/services/pdf_service.dart`
- Generates statement with all accounts and transactions
- Includes bank logos, transaction tables, summary stats

## Known Issues & Limitations

1. **Hardcoded ATM locations**: ATM map uses static coordinates for demo
2. **3-bank limit**: Architecture supports exactly 3 banks (vbank, abank, sbank)
3. **Cashback calculation**: Requires bank API support (not fully implemented)
4. **Yandex Maps API key**: Stored in `api_config.dart`, update if expired
5. **Scoped Storage**: Android 10+ requires special permissions for PDF saving

## Important Files to Review

- `lib/config/api_config.dart` - Team credentials, bank URLs, API keys
- `lib/services/auth_service.dart` - Central auth & consent management
- `lib/services/bank_api_service.dart` - All bank API calls with retry logic
- `lib/services/consent_polling_service.dart` - Automatic consent approval polling
- `lib/providers/account_provider.dart` - Account/balance/transaction state
- `lib/main.dart` - App initialization and provider setup

## Testing

When testing consent flows:
1. Clear app data to reset all consents: `flutter run --clear`
2. For SBank testing, manually approve at bank portal (consent ID in logs)
3. Check polling status with debug prints: `[ConsentPolling]` prefix
4. Verify composite keys: `[bankCode:accountId]` format in balance maps

## Error Handling Patterns

### Consent Errors
```dart
try {
  final consent = await authService.getAccountConsent(bankCode);
  if (!consent.isApproved) {
    // Handle pending/rejected state
  }
} catch (e) {
  if (e.toString().contains('CONSENT_REQUIRED')) {
    // Create new consent
  }
}
```

### Network Errors
All handled automatically by `_executeWithRetry` in `BankApiService`. Throws after 3 failed attempts with exponential backoff.

## Code Style Notes

- Use underscore prefix for private members: `_balances`, `_fetchData()`
- Prefer `debugPrint()` over `print()` for logging
- Notification types: `success`, `info`, `warning`, `error`
- Date format: ISO 8601 strings from API, convert to DateTime for display
- Bank codes: Always lowercase (`vbank`, `abank`, `sbank`)
