import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart' hide Icon, TextStyle;
import 'package:yandex_maps_mapkit/mapkit.dart' hide Animation, Map;
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:yandex_maps_mapkit/image.dart' as image_provider;
import '../config/api_config.dart';

// ATM locations for demonstration (Moscow area)
final Map<String, List<Point>> atmLocations = {
  'vbank': [ // VBank
    const Point(latitude: 55.7558, longitude: 37.6173), // Red Square area
    const Point(latitude: 55.7522, longitude: 37.6156),
    const Point(latitude: 55.7514, longitude: 37.6198),
  ],
  'abank': [ // ABank
    const Point(latitude: 55.7540, longitude: 37.6210),
    const Point(latitude: 55.7500, longitude: 37.6180),
    const Point(latitude: 55.7560, longitude: 37.6150),
  ],
  'sbank': [ // SBank
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
  MapWindow? _mapWindow;
  late final AppLifecycleListener _lifecycleListener;
  bool _isMapkitActive = false;

  @override
  void initState() {
    super.initState();

    _startMapkit();

    // Setup app lifecycle listener for proper resource management
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        _startMapkit();
        _applyMapTheme();
      },
      onInactive: () {
        _stopMapkit();
      },
    );
  }

  void _startMapkit() {
    if (!_isMapkitActive) {
      _isMapkitActive = true;
      mapkit.onStart();
    }
  }

  void _stopMapkit() {
    if (_isMapkitActive) {
      _isMapkitActive = false;
      mapkit.onStop();
    }
  }

  void _applyMapTheme() {
    if (_mapWindow == null) return;

    // Apply theme based on system brightness
    final brightness = flutter.Theme.of(context).brightness;
    _mapWindow!.map.nightModeEnabled = brightness == Brightness.dark;
  }

  void _onMapCreated(MapWindow mapWindow) {
    setState(() {
      _mapWindow = mapWindow;
    });

    // Configure logo position
    _mapWindow!.map.logo.setAlignment(
      const LogoAlignment(
        LogoHorizontalAlignment.Left,
        LogoVerticalAlignment.Bottom,
      ),
    );

    // Apply initial theme
    _applyMapTheme();

    // Set initial camera position to Moscow center
    _mapWindow!.map.move(
      CameraPosition(
        const Point(latitude: 55.7530, longitude: 37.6190),
        zoom: 14.0,
        azimuth: 0.0,
        tilt: 0.0,
      ),
    );

    // Create ATM placemarks
    _createAtmPlacemarks();
  }

  void _createAtmPlacemarks() {
    if (_mapWindow == null) return;

    final mapObjects = _mapWindow!.map.mapObjects;

    // Create a collection for ATM markers
    final collection = mapObjects.addCollection();

    atmLocations.forEach((bankCode, locations) {
      for (int i = 0; i < locations.length; i++) {
        final placemark = collection.addPlacemark();
        placemark.geometry = locations[i];

        // Set bank-specific colored markers with text
        final bankInitial = _getBankInitial(bankCode);

        // Add bank name as text below the marker
        placemark.setText(bankInitial);
        placemark.setTextStyle(
          const TextStyle(
            placement: TextStylePlacement.Bottom,
            offset: 0.0,
            size: 10.0,
            color: Colors.black,
            outlineColor: Colors.white,
          ),
        );

        // Try to use custom asset icon, otherwise use default with opacity based on bank
        try {
          placemark.setIcon(
            image_provider.ImageProvider.fromImageProvider(
              const AssetImage('assets/atm_icon.png'),
            ),
          );
          placemark.setIconStyle(
            IconStyle(
              scale: 0.2,
            ),
          );
        } catch (e) {
          // Use default pin marker with bank-specific styling
          // The default pin will be used, and we differentiate by text label
          placemark.opacity = _getBankOpacity(bankCode);
        }

        // Add tap listener to show ATM details
        final atmLocation = locations[i];
        final atmBankCode = bankCode;
        placemark.addTapListener(_AtmTapListener(
          onTap: () => _showAtmDetails(atmBankCode, atmLocation),
        ));
      }
    });
  }

  String _getBankInitial(String bankCode) {
    switch (bankCode) {
      case 'vbank':
        return 'VTB';
      case 'abank':
        return 'T-Bank';
      case 'sbank':
        return 'СБ';
      default:
        return 'ATM';
    }
  }

  double _getBankOpacity(String bankCode) {
    // Use different opacity levels to distinguish banks when using default pins
    switch (bankCode) {
      case 'vbank':
        return 1.0; // Full opacity
      case 'abank':
        return 0.8;
      case 'sbank':
        return 0.9;
      default:
        return 0.7;
    }
  }

  void _showAtmDetails(String bankCode, Point location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ApiConfig.getBankName(bankCode),
              style: const flutter.TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Банкомат',
              style: flutter.TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const flutter.Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Координаты: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Add navigation to ATM
                },
                icon: const flutter.Icon(Icons.directions),
                label: const Text('Построить маршрут'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopMapkit();
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Yandex Map Widget
          SafeArea(
            top: false,
            child: YandexMap(
              onMapCreated: _onMapCreated,
              platformViewType: PlatformViewType.Hybrid,
            ),
          ),

          // ATM Legend Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Банкоматы партнеров',
                      style: flutter.TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...atmLocations.entries.map((entry) {
                      Color markerColor;
                      switch (entry.key) {
                        case 'vbank':
                          markerColor = Colors.blue;
                          break;
                        case 'abank':
                          markerColor = Colors.yellow.shade700;
                          break;
                        case 'sbank':
                          markerColor = Colors.green;
                          break;
                        default:
                          markerColor = Colors.red;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: markerColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${ApiConfig.getBankName(entry.key)} (${entry.value.length})',
                            ),
                          ],
                        ),
                      );
                    }),
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

// Tap listener implementation for ATM markers
final class _AtmTapListener implements MapObjectTapListener {
  final VoidCallback onTap;

  const _AtmTapListener({required this.onTap});

  @override
  bool onMapObjectTap(MapObject mapObject, Point point) {
    onTap();
    return true;
  }
}
