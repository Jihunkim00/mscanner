import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:mscanner/l10n/gen_l10n/app_localizations.dart';

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String restaurantName;

  MapScreen({
    required this.latitude,
    required this.longitude,
    required this.restaurantName,
  });

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    isDarkMode = AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        title: Text(
          'Map View',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareLocation,
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.latitude, widget.longitude),
          zoom: 14.0,
        ),
        markers: {
          Marker(
            markerId: MarkerId('restaurant_marker'),
            position: LatLng(widget.latitude, widget.longitude),
            infoWindow: InfoWindow(
              title: widget.restaurantName,
              snippet: AppLocalizations.of(context)?.shareLocation ?? 'Share location',
              onTap: _shareLocation,
            ),
          ),
        },
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) async {
    mapController = controller;

    if (isDarkMode) {
      String darkMapStyle = await rootBundle.loadString('assets/map_styles/dark_mode.json');
      mapController.setMapStyle(darkMapStyle);
    } else {
      mapController.setMapStyle(null); // 기본 맵 스타일 적용
    }
  }

  void _shareLocation() {
    final locationUrl =
        'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}';
    final message = 'Mscanner: ${widget.restaurantName}\n\nLocation: $locationUrl';

    Share.share(message);
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}
