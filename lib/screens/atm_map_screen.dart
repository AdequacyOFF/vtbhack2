import 'package:flutter/material.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../config/api_config.dart';

// ATM locations for demonstration (Moscow area)
final Map<String, List<Point>> atmLocations = {
  'vbank': [ // VTB
    const Point(latitude: 55.7558, longitude: 37.6173), // Red Square area
    const Point(latitude: 55.7522, longitude: 37.6156),
    const Point(latitude: 55.7514, longitude: 37.6198),
  ],
  'abank': [ // T-Bank
    const Point(latitude: 55.7540, longitude: 37.6210),
    const Point(latitude: 55.7500, longitude: 37.6180),
    const Point(latitude: 55.7560, longitude: 37.6150),
  ],
  'sbank': [ // Sberbank
    const Point(latitude: 55.7530, longitude: 37.6190),
    const Point(latitude: 55.7510, longitude: 37.6170),
    const Point(latitude: 55.7545, longitude: 37.6200),
  ],
};

class AtmMapScreen extends StatefulWidget {
  const AtmMapScreen({super.key});

  @override
  State<AtmMapScreen> createState() => _AtmMapScreenState();
}

class _AtmMapScreenState extends State<AtmMapScreen> {
  late YandexMapController _mapController;
  final List<PlacemarkMapObject> _placemarks = [];

  @override
  void initState() {
    super.initState();
    _initPlacemarks();
  }

  void _initPlacemarks() {
    _placemarks.clear();

    atmLocations.forEach((bankCode, locations) {
      for (int i = 0; i < locations.length; i++) {
        _placemarks.add(
          PlacemarkMapObject(
            mapId: MapObjectId('${bankCode}_$i'),
            point: locations[i],
            opacity: 1,
            icon: PlacemarkIcon.single(
              PlacemarkIconStyle(
                image: BitmapDescriptor.fromAssetImage('assets/atm_icon.png'),
                scale: 0.5,
              ),
            ),
            text: PlacemarkText(
              text: ApiConfig.getBankName(bankCode),
              style: const PlacemarkTextStyle(
                size: 10,
                placement: TextStylePlacement.bottom,
              ),
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          YandexMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController.moveCamera(
                CameraUpdate.newCameraPosition(
                  const CameraPosition(
                    target: Point(latitude: 55.7530, longitude: 37.6190),
                    zoom: 14,
                  ),
                ),
              );
            },
            mapObjects: _placemarks,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Банкоматы партнеров',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...atmLocations.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${ApiConfig.getBankName(entry.key)} (${entry.value.length})',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
