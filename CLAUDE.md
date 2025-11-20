# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-bank aggregator Flutter application for VTB Hack 2025. Connects to 4 OpenBanking APIs (VBank, ABank, SBank, Best ADOFF Bank) to aggregate accounts, create smart financial products, and provide personalized news based on spending patterns.

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
- **Services**: Business logic and API communication (auth, bank API, consent polling, notifications, expenses optimization, **secure storage**)
- **Providers**: State management using Provider pattern (account, product, transfer, news, virtual accounts)
- **Screens**: UI components

### Critical Implementation Details

#### 0. Secure Storage for Sensitive Data
**CRITICAL SECURITY**: All sensitive authentication data is encrypted at rest using `flutter_secure_storage`.

**Implementation** (`lib/services/secure_storage_service.dart`):
- Uses platform-specific hardware-backed encryption
- Android: KeyStore with EncryptedSharedPreferences
- iOS: Keychain with `first_unlock` accessibility

**Protected Data**:
- Bank access tokens (OAuth bearer tokens)
- Bank refresh tokens
- Account/Payment/Product consent IDs
- Client identification credentials

**Usage**:
```dart
final secureStorage = SecureStorageService();

// Save encrypted data
await secureStorage.saveTokens(tokensJson);
await secureStorage.saveClientId(clientId);

// Read encrypted data
final tokens = await secureStorage.readTokens();
final clientId = await secureStorage.readClientId();

// Secure deletion
await secureStorage.clearAllAuthData();
```

**IMPORTANT**:
- `AuthService` uses `SecureStorageService` for ALL token and consent storage
- Never store tokens or credentials in plain `SharedPreferences`
- News preferences (likes/dislikes) remain in SharedPreferences as they're non-sensitive

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
- VBank & ABank & Best ADOFF Bank: Auto-approved immediately
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
1. Fetches bank tokens for all 4 banks
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

#### 9. Virtual Accounts & Expense Budgeting

**Virtual Accounts** allow users to create budget categories and track spending against allocated amounts:
- **Create virtual accounts** for different expense categories (e.g., "Food Budget", "Transportation")
- **Allocate monthly amounts** to each virtual account
- **Track spending** by assigning real transactions to virtual accounts
- **Monitor remaining balance** in each budget category
- **Calculate potential earnings**: Last month's income minus total allocated budget

**Key Calculations:**
```dart
totalAllocated = sum of all virtual account allocations
totalSpent = sum of all assigned transaction amounts
totalRemaining = sum of remaining balances in each account
potentialEarnings = lastMonthIncome - totalAllocated
```

**Implementation:**
- `lib/providers/virtual_account_provider.dart`: State management for virtual accounts
- `lib/models/virtual_account.dart`: Virtual account data model
- Virtual accounts persisted to `shared_preferences`
- Income auto-calculated from previous month's credit transactions

#### 10. Expenses Optimization & ML Advice

**ExpensesOptimizationService** provides AI-powered spending advice via ML service:
- **Endpoint**: `http://5.129.212.83:51000/advice`
- **Analyzes last 30 days** of spending by category
- **Sends spending data** + income + user wishes to ML service
- **Receives personalized advice** on how to optimize expenses with AI justification

**Request format:**
```json
{
  "earnings": 100000,
  "wastes": {
    "meal": 15000.50,
    "transport": 3000.00,
    "shopping": 8500.00,
    ...
  },
  "wishes": "хочу денег"
}
```

**Response format:**
```json
{
  "earnings": 100000,
  "wastes": {
    "meal": 12000.00,
    "transport": 2500.00,
    "shopping": 7000.00,
    ...
  },
  "comment": "Пользователь хочет больше денег, что означает необходимость сократить расходы. Снижены траты на рестораны и транспорт, что позволяет сохранить часть дохода."
}
```

**Key Features:**
- **User Wishes Input**: Free-form text field for user preferences (e.g., "хочу накопить на отпуск")
- **AI Justification**: The `comment` field contains detailed neural network explanation
- **Expandable UI**: Comment displayed in expandable card with brain icon (🧠) for optional reading

**Category mapping (English ↔ Russian):**
- meal ↔ Еда
- transport ↔ Транспорт
- shopping ↔ Покупки
- entertainment ↔ Развлечения
- health ↔ Здоровье
- utilities ↔ Коммунальные услуги
- education ↔ Образование
- other ↔ Другое

**Flow**: Transactions → MCC Categorization → Monthly Aggregation + User Wishes → ML Service → Optimized Budget + AI Comment → Display with Expandable Justification

#### 11. News Personalization Service

**UPDATED API** (`http://5.129.212.83:51000/news`):
- Endpoint changed from old URL to new server
- Request format updated to new API specification

**Request format:**
```json
{
  "n": 3,
  "top_spend_categories": ["рестораны", "транспорт"],
  "disliked_titles": ["война"]
}
```

**Response format:**
```json
[
  {
    "source": "Финам",
    "title": "News title",
    "content": "Full article content",
    "original_url": "https://...",
    "image_base64": null
  }
]
```

**Key Features**:
- **Like/Dislike System**: Users can like (👍) or dislike (👎) news articles
- **Disliked Articles**: Automatically hidden and excluded from future requests
- **Persistence**: Liked/disliked titles saved in `SharedPreferences` (non-sensitive data)
- **Automatic Filtering**: `disliked_titles` array sent with every request

**Implementation**:
- `NewsService`: Handles API calls with disliked titles
- `NewsProvider`: Manages like/dislike state and article visibility
- `NewsScreen`: UI with like/dislike buttons and confirmation dialogs

**Model Mapping** (`lib/models/news.dart`):
```dart
// API fields → Internal properties
source → agency
content → summary
original_url → url
```

**Parameter names**: Use `n` and `categories` (not `topN` or `topics`)

#### 12. One-Click Deposit Creation (Best ADOFF Bank Integration)

**CRITICAL**: After receiving expense optimization recommendations, users can create a deposit in Best ADOFF Bank with one click for the savings amount.

**Implementation** (`expenses_optimization_screen.dart`):
- Automatically calculates savings: `currentSpending - optimizedSpending`
- Fetches all Best ADOFF Bank products
- Selects best deposit (highest interest rate) matching the savings amount
- Requires source account from **Best ADOFF Bank only** (same-bank requirement)
- Creates deposit with 12-month term by default

**Important constraints:**
```dart
// Must use babank account as source
final babankAccounts = accounts.where((acc) => acc.bankCode == 'babank').toList();

// Validates min/max deposit limits
final validDeposits = babankDeposits.where((p) {
  final minAmount = p.minAmountValue;
  final maxAmount = p.maxAmountValue;
  if (minAmount != null && savings < minAmount) return false;
  if (maxAmount != null && savings > maxAmount) return false;
  return true;
}).toList();
```

**UI behavior:**
- Green gradient card only appears when `savings > 0`
- Shows exact savings amount
- Loading state while creating deposit
- Success message includes interest rate

**Error scenarios:**
- No Best ADOFF Bank accounts → Prompt to create account
- Insufficient balance → Shows required vs available with transfer suggestion
- No valid deposits → Amount doesn't match deposit limits
- Product consent missing → Automatically creates if needed

## API Configuration

### Bank API Base URLs
- VBank: `https://vbank.open.bankingapi.ru`
- ABank: `https://abank.open.bankingapi.ru`
- SBank: `https://sbank.open.bankingapi.ru`
- Best ADOFF Bank: `https://bank.ad-off.digital`

### ML Service Endpoints
- News Personalization: `http://5.129.212.83:51000/news`
- Expenses Optimization: `http://5.129.212.83:51000/advice`

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
1. Add bank config to `lib/config/api_config.dart`:
   - Add `<bankCode>BaseUrl` constant
   - Add `<bankCode>Code` constant
   - Add to `bankNames` map
   - Add to `bankAutoApproval` map
   - Update `getBankBaseUrl()` switch statement
2. Add to `supportedBanks` list in `AuthService._initializeBankServices()`
3. Update `ProductProvider._getBankName()` for display names
4. Add ATM locations to `atm_map_screen.dart`:
   - Add locations to `atmLocations` map
   - Update `_getBankInitial()` for marker labels
   - Update `_getBankMarkerAsset()` for custom marker
   - Update `_getBankOpacity()` for fallback opacity
5. Add marker asset: `assets/atm_<bankCode>.png`

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

## ATM Map Implementation

**Bank-specific colored markers**: Each bank uses its own marker icon from assets.

**Required marker assets** (place in `assets/` folder):
- `atm_vbank.png` - VBank marker (Blue)
- `atm_abank.png` - ABank marker (Green)
- `atm_sbank.png` - SBank marker (Red/Orange)
- `atm_babank.png` - Best ADOFF Bank marker (Purple/Gold)
- `atm_default.png` - Fallback marker (Gray)

**Marker configuration:**
```dart
// Auto-scales to 15% of original size
placemark.setIconStyle(IconStyle(scale: 0.15));
```

**Location distribution**: ATM locations spread ~10-15km apart across Moscow to simulate city-wide coverage.

**Fallback behavior**: If marker asset not found, uses default map pin with bank-specific opacity (1.0, 0.8, 0.9, 0.85).

## Known Issues & Limitations

1. **ATM locations**: Static coordinates distributed across Moscow for demo
2. **Cashback calculation**: Requires bank API support (not fully implemented)
3. **Yandex Maps API key**: Stored in `api_config.dart`, update if expired
4. **Scoped Storage**: Android 10+ requires special permissions for PDF saving
5. **Deposit creation**: Requires source account from same bank (Best ADOFF Bank for deposit feature)

## Important Files to Review

- `lib/config/api_config.dart` - Team credentials, bank URLs, API keys
- `lib/services/auth_service.dart` - Central auth & consent management
- `lib/services/bank_api_service.dart` - All bank API calls with retry logic
- `lib/services/consent_polling_service.dart` - Automatic consent approval polling
- `lib/services/expenses_optimization_service.dart` - ML-powered spending advice
- `lib/services/mcc_category_service.dart` - MCC code to category mapping
- `lib/providers/account_provider.dart` - Account/balance/transaction state (`accounts` not `allAccounts`)
- `lib/providers/product_provider.dart` - Product management and deposit/loan creation
- `lib/providers/virtual_account_provider.dart` - Virtual budgeting accounts
- `lib/screens/expenses_optimization_screen.dart` - ML recommendations + one-click deposit
- `lib/screens/atm_map_screen.dart` - Yandex Maps integration with bank markers
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
- Bank codes: Always lowercase (`vbank`, `abank`, `sbank`, `babank`)
