import '../models/virtual_account.dart';

/// Service to map MCC (Merchant Category Code) to expense categories
/// Based on ISO 18245 standard MCC codes
class MccCategoryService {
  /// Map MCC code to expense category
  static String? mapMccToCategory(String? mccCode) {
    if (mccCode == null) return null;

    final code = int.tryParse(mccCode);
    if (code == null) return null;

    // Food & Restaurants (5411-5499, 5811-5815)
    if ((code >= 5411 && code <= 5499) || // Grocery stores, supermarkets, convenience
        (code >= 5811 && code <= 5815)) {  // Restaurants, fast food, bars
      return ExpenseCategory.food;
    }

    // Transport (3000-3299 Airlines, 3351-3441 Car Rental, 4111-4789 Transport Services, 5511-5599 Auto)
    if ((code >= 3000 && code <= 3299) ||  // Airlines
        (code >= 3351 && code <= 3441) ||  // Car rental
        (code == 4111) ||                   // Railroads, local transport
        (code == 4112) ||                   // Passenger railways
        (code == 4121) ||                   // Taxis and limousines
        (code == 4131) ||                   // Bus lines
        (code >= 4511 && code <= 4582) ||  // Airlines, airports
        (code >= 5511 && code <= 5599) ||  // Auto dealers, gas stations, service
        (code == 4789)) {                   // Transportation services
      return ExpenseCategory.transport;
    }

    // Shopping & Clothing (5200-5399 General Retail, 5611-5699 Clothing, 5712-5735 Home goods)
    if ((code >= 5200 && code <= 5399) ||  // Department stores, wholesale, discount
        (code >= 5611 && code <= 5699) ||  // Clothing and accessories
        (code >= 5712 && code <= 5735) ||  // Furniture, electronics, appliances
        (code >= 5931 && code <= 5999) ||  // Specialty retail
        (code >= 5013 && code <= 5099)) {  // Durable goods wholesale
      return ExpenseCategory.shopping;
    }

    // Entertainment (7800-7999 Recreation, 7911-7999 Entertainment)
    if ((code >= 7800 && code <= 7999) ||  // Entertainment, recreation, sports
        (code == 7922) ||                   // Theatrical producers, tickets
        (code == 7929) ||                   // Bands, orchestras, entertainers
        (code == 7932) ||                   // Billiard and pool
        (code == 7933) ||                   // Bowling alleys
        (code == 7941) ||                   // Sports clubs, promoters
        (code >= 7991 && code <= 7998)) {  // Tourist attractions, golf, amusement
      return ExpenseCategory.entertainment;
    }

    // Health (5912 Pharmacies, 5975-5977 Medical supplies, 8011-8099 Medical services)
    if ((code == 5912) ||                   // Pharmacies
        (code >= 5975 && code <= 5977) ||  // Medical supplies, prosthetics
        (code >= 8011 && code <= 8099)) {  // Doctors, dentists, hospitals, medical
      return ExpenseCategory.health;
    }

    // Utilities (4812-4899 Telecommunications, 4900 Utilities)
    if ((code >= 4812 && code <= 4899) ||  // Telecom, cable, internet
        (code == 4900)) {                   // Electric, gas, water utilities
      return ExpenseCategory.utilities;
    }

    // Education (5192-5193 Books/periodicals, 5942-5943 Books/stationery, 8211-8299 Schools)
    if ((code == 5192) ||                   // Books, periodicals, newspapers
        (code == 5942) ||                   // Book stores
        (code == 5943) ||                   // Stationery, office supplies
        (code >= 8211 && code <= 8299)) {  // Schools, universities, vocational
      return ExpenseCategory.education;
    }

    // Hotels (3501-3816)
    if (code >= 3501 && code <= 3816) {
      return ExpenseCategory.other; // Or create a separate "Travel/Hotels" category
    }

    // Default to Other
    return ExpenseCategory.other;
  }

  /// Get category description from MCC code
  static String getMccDescription(String mccCode) {
    // This is a subset of common MCC codes
    // Full mapping available in mccCodes.txt
    final descriptions = {
      // Food & Dining
      '5411': 'Grocery Stores, Supermarkets',
      '5812': 'Eating places and Restaurants',
      '5814': 'Fast Food Restaurants',
      '5813': 'Bars, Taverns, Nightclubs',

      // Transport
      '5541': 'Service Stations',
      '5542': 'Automated Fuel Dispensers',
      '4121': 'Taxicabs and Limousines',
      '4131': 'Bus Lines',
      '3000': 'Airlines',

      // Shopping
      '5651': 'Family Clothing Stores',
      '5311': 'Department Stores',
      '5941': 'Sporting Goods Stores',
      '5732': 'Electronic Sales',

      // Entertainment
      '7832': 'Motion Picture Theaters',
      '7941': 'Commercial Sports, Professional Sport Clubs',
      '7996': 'Amusement Parks, Carnivals, Circuses',

      // Health
      '5912': 'Drug Stores and Pharmacies',
      '8011': 'Doctors and Physicians',
      '8062': 'Hospitals',

      // Utilities
      '4814': 'Telecommunication Services',
      '4900': 'Electric, Gas, Sanitary and Water Utilities',

      // Education
      '5942': 'Book Stores',
      '8211': 'Elementary and Secondary Schools',
      '8220': 'Colleges, Universities',
    };

    return descriptions[mccCode] ?? 'Other';
  }
}
