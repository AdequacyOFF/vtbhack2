class Merchant {
  final String merchantId;
  final String name;
  final String? mccCode;
  final String? category;
  final String? city;
  final String? country;
  final String? address;

  Merchant({
    required this.merchantId,
    required this.name,
    this.mccCode,
    this.category,
    this.city,
    this.country,
    this.address,
  });

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      merchantId: json['merchantId'] ?? '',
      name: json['name'] ?? '',
      mccCode: json['mccCode'],
      category: json['category'],
      city: json['city'],
      country: json['country'],
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantId': merchantId,
      'name': name,
      if (mccCode != null) 'mccCode': mccCode,
      if (category != null) 'category': category,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (address != null) 'address': address,
    };
  }
}
