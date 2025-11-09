# Multi-Bank Aggregation App

A comprehensive Flutter mobile application for VTB Hack 2025 that aggregates banking accounts across multiple institutions and provides intelligent financial services.

## Features

### 1. Multi-Bank Account Aggregation
- Connects to **3 banks**: VBank, ABank, and SBank
- Displays all accounts from all banks in a unified dashboard
- Real-time balance updates
- Transaction history for each account

### 2. Smart Product Selection
**Savings Accounts:**
- Automatically compares deposit interest rates across all banks
- Recommends the bank with the best rate
- Allows manual bank selection if desired

**Loans:**
- Compares loan interest rates across all banks
- Automatically selects the bank with lowest rate
- Supports manual override for bank selection

### 3. Universal Transfer System
- Transfer money between any accounts (same bank or cross-bank)
- Automatic consent management
- Support for inter-bank transfers
- Real-time payment status tracking

### 4. Smart Payment Selection
- Analyzes available payment accounts
- Selects account with highest cashback for payments
- Optimizes payment routing

### 5. ATM Locator
- Integrated Yandex Maps showing all partner bank ATMs
- Real-time location display for:
  - VBank locations
  - ABank locations
  - SBank locations

### 6. Account Statement Generation
- Generate comprehensive PDF statements
- Includes all accounts and transactions
- Export and share functionality

### 7. ML Analytics Export
- Analyzes transaction patterns by category
- Exports transaction frequency data
- Prepares data for neural network analysis
- Category-wise spending breakdown

### 8. Social Media Integration (Placeholder)
- Link social media accounts for easy transfers
- Transfer money to friends by social media username
- Requires both sender and receiver to link accounts

### 9. Intelligent Consent Management
- Automatic consent creation for all banks
- Handles auto-approval (VBank, ABank)
- Supports manual approval workflow (SBank)
- Persistent consent storage

## Technical Stack

- **Framework**: Flutter 3.9.2
- **Language**: Dart
- **State Management**: Provider
- **HTTP Client**: http + dio
- **Maps**: Yandex MapKit
- **PDF**: pdf + printing packages
- **Storage**: shared_preferences

## Architecture

### Clean Architecture Pattern
```
lib/
├── config/          # Configuration (API endpoints, theme)
├── models/          # Data models
├── services/        # Business logic
├── providers/       # State management
├── screens/         # UI screens
└── main.dart        # App entry point
```

### Key Services
- **AuthService**: Authentication & consent management
- **BankApiService**: Banking API client for each bank
- **PdfService**: Statement generation
- **AnalyticsService**: Transaction analysis

## Getting Started

### Prerequisites
- Flutter SDK 3.9.2 or higher
- Android Studio / VS Code
- Android device or emulator

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd vtbhack2
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure API credentials**
Edit `lib/config/api_config.dart` with your team credentials:
```dart
static const String clientId = 'team201';
static const String clientSecret = 'YOUR_SECRET';
```

4. **Run the application**
```bash
flutter run
```

### First Launch

1. Enter your Client ID (e.g., `team201-10`)
2. App will automatically:
   - Fetch bank tokens
   - Create necessary consents
   - Load accounts from all banks

## API Integration

### Banking APIs
The app integrates with three OpenBanking APIs:
- **VBank**: https://vbank.open.bankingapi.ru
- **ABank**: https://abank.open.bankingapi.ru
- **SBank**: https://sbank.open.bankingapi.ru

### Authentication Flow
1. Get bank token: `POST /auth/bank-token`
2. Create consents: `POST /account-consents/request`
3. Fetch accounts: `GET /accounts`
4. Fetch balances: `GET /accounts/{id}/balances`
5. Fetch transactions: `GET /accounts/{id}/transactions`

### Key Headers
- `Authorization`: Bearer token
- `x-consent-id`: Consent identifier
- `x-requesting-bank`: Team ID

## Features Implementation Status

✅ Multi-bank account aggregation
✅ Smart savings account creation
✅ Smart loan application
✅ Inter-bank transfers
✅ ATM map integration
✅ PDF statement generation
✅ Transaction analytics for ML
✅ Consent management
⚠️ Social media linking (placeholder)
⚠️ Smart cashback selection (placeholder)

## UI Design

The app features a VTB-inspired design:
- Primary color: VTB Blue (#0028FF)
- Clean, modern card-based layout
- Intuitive navigation with bottom bar
- Smooth animations and transitions

## Screens

1. **Login Screen**: Enter Client ID
2. **Home/Dashboard**: View all accounts aggregated
3. **Account Details**: View transactions for specific account
4. **Products**: Browse deposits, loans, and cards
5. **Transfer**: Send money between accounts
6. **ATM Map**: Find nearby ATMs
7. **Profile**: Export statements, analytics, settings

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Building

```bash
# Debug APK
flutter build apk

# Release APK
flutter build apk --release

# App Bundle for Play Store
flutter build appbundle
```

## Known Limitations

1. Social media integration is a UI placeholder
2. Cashback calculation requires bank API support
3. ATM locations are hardcoded for demonstration
4. Limited to 3 partner banks

## Future Enhancements

- Real-time notifications for transactions
- Bill payment integration
- Investment products
- Multi-currency support
- Biometric authentication
- Dark mode

## Troubleshooting

**Issue**: Consents not approved
**Solution**: Check if using correct client_id format (e.g., team201-10)

**Issue**: Accounts not loading
**Solution**: Verify internet connection and API endpoints

**Issue**: Maps not showing
**Solution**: Check Yandex Maps API key and Android permissions

## License

This project was created for VTB Hack 2025.

## Contact

For questions or issues, please contact the development team.
