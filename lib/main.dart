import 'dart:async';
import 'dart:convert';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import 'custom_navigation_bar.dart';
import 'database_helper.dart';

final logger = Logger();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  late GoogleMapController mapController;

  final LatLng defaultLocation = const LatLng(37.4878198, 139.9296658);

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  LatLng? _currentPosition;
  final TextEditingController _searchController = TextEditingController();

  Set<Marker> _markers = {};
  final int _selectedIndex = 0;
  double _currentZoom = 15.0;

  bool _isMapReady = false;
  bool _hasLocationPermission = false;
  bool _isCheckingLocation = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _initLocationService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();

    if (_isMapReady) {
      mapController.dispose();
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationAfterResume();
    }
  }

  // Check location services and request permission when needed.
  Future<void> _initLocationService() async {
    if (_isCheckingLocation) return;
    _isCheckingLocation = true;

    try {
      final locationResult = await checkLocationSetting();

      if (!mounted) return;

      if (locationResult == LocationSettingResult.enabled) {
        setState(() {
          _hasLocationPermission = true;
        });

        await _getCurrentLocation();
      } else {
        setState(() {
          _hasLocationPermission = false;
        });

        await recoverLocationSettings(context, locationResult);
      }
    } catch (e) {
      logger.w('Error initializing location service: $e');
    } finally {
      _isCheckingLocation = false;
    }
  }

  // Recheck permissions after returning from device settings.
  Future<void> _refreshLocationAfterResume() async {
    if (_isCheckingLocation) return;
    _isCheckingLocation = true;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!mounted) return;

      if (!serviceEnabled) {
        setState(() {
          _hasLocationPermission = false;
        });
        return;
      }

      final permission = await Geolocator.checkPermission();

      if (!mounted) return;

      final isGranted = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      setState(() {
        _hasLocationPermission = isGranted;
      });

      if (isGranted) {
        await _getCurrentLocation();
      }
    } catch (e) {
      logger.w('Error refreshing location settings: $e');
    } finally {
      _isCheckingLocation = false;
    }
  }

  // Retrieve the device's current location.
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = LatLng(
          position.latitude,
          position.longitude,
        );
      });

      _moveToCurrentLocation();
    } catch (e) {
      logger.w('Error getting location: $e');
    }
  }

  // Move the camera only after the map is initialized.
  void _moveToCurrentLocation() {
    if (!_isMapReady || _currentPosition == null) return;

    _currentZoom = 17.0;

    mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition!,
          zoom: _currentZoom,
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _isMapReady = true;

    if (!_controller.isCompleted) {
      _controller.complete(controller);
    }

    _moveToCurrentLocation();
  }

  // Zoom in.
  void _zoomIn() {
    if (!_isMapReady) return;

    setState(() {
      _currentZoom += 1.0;
    });

    mapController.animateCamera(
      CameraUpdate.zoomTo(_currentZoom),
    );
  }

  // Zoom out.
  void _zoomOut() {
    if (!_isMapReady) return;

    setState(() {
      _currentZoom -= 1.0;
    });

    mapController.animateCamera(
      CameraUpdate.zoomTo(_currentZoom),
    );
  }

  // Search for a location and move the map.
  Future<void> _searchAndNavigate() async {
    final searchQuery = _searchController.text.trim().toLowerCase();

    if (searchQuery.isEmpty) return;

    debugPrint('Search Query: $searchQuery');

    final List<String> keywords = [
      'Tsurugajo',
      'Tsurugajo castle',
      'castle',
      '鶴ヶ城',
      '会津若松城',
    ];

    final isTsurugajo = keywords.any(
      (keyword) => searchQuery.contains(keyword.toLowerCase()),
    );

    debugPrint('Is Tsurugajo: $isTsurugajo');

    const apiKey = String.fromEnvironment('GOOGLE_GEOCODING_API_KEY');

    if (apiKey.isEmpty) {
      logger.w('GOOGLE_GEOCODING_API_KEY is not configured.');

      if (!mounted) return;

      await showOkAlertDialog(
        context: context,
        title: 'Search unavailable',
        message: 'Location search has not been configured.',
      );
      return;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'address': searchQuery,
        'key': apiKey,
      },
    );

    try {
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (isTsurugajo) {
          const target = LatLng(37.5076457, 139.9318131);

          setState(() {
            _markers = {
              Marker(
                markerId: const MarkerId('Tsurugajo_Marker'),
                position: target,
                infoWindow: InfoWindow(
                  title: 'Schedule',
                  onTap: _showBusSchedulePopup,
                ),
              ),
            };
          });

          if (!_isMapReady) return;

          mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              const CameraPosition(
                target: target,
                zoom: 15,
              ),
            ),
          );
        } else if (data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];

          final searchedLocation = LatLng(
            (location['lat'] as num).toDouble(),
            (location['lng'] as num).toDouble(),
          );

          if (!_isMapReady) return;

          mapController.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: searchedLocation,
                zoom: 15,
              ),
            ),
          );

          setState(() {
            _markers = {};
          });
        } else {
          logger.w('No results found for the search.');
        }
      } else {
        logger.w('Failed to fetch location data.');
      }
    } catch (e) {
      logger.w('Error searching location: $e');
    }
  }

  // Display the bus schedule.
  Future<void> _showBusSchedulePopup() async {
    final dbHelper = DatabaseHelper.instance;
    final List<Map<String, dynamic>> schedule = await dbHelper.getBusSchedule();

    final busTimes =
        schedule.map((item) => item['departureTime'].toString()).join('\n');

    if (!mounted) return;

    await showOkAlertDialog(
      context: context,
      title: 'Bus Schedule',
      message: busTimes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search location',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _searchAndNavigate,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? defaultLocation,
              zoom: _currentZoom,
            ),
            zoomControlsEnabled: false,
            myLocationEnabled: _hasLocationPermission,
            onMapCreated: _onMapCreated,
            markers: _markers,
          ),
          Positioned(
            bottom: 80,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _zoomIn,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _zoomOut,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBar(
        selectedIndex: _selectedIndex,
        onTap: (index) {},
      ),
    );
  }
}

enum LocationSettingResult {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  enabled,
}

// Check location services and permissions.
Future<LocationSettingResult> checkLocationSetting() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) {
    logger.w('Location services are disabled.');
    return LocationSettingResult.serviceDisabled;
  }

  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      logger.w('Location permissions are denied.');
      return LocationSettingResult.permissionDenied;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    logger.w('Location permissions are permanently denied.');
    return LocationSettingResult.permissionDeniedForever;
  }

  return LocationSettingResult.enabled;
}

// Guide the user to the appropriate settings screen.
Future<void> recoverLocationSettings(
  BuildContext context,
  LocationSettingResult locationResult,
) async {
  if (locationResult == LocationSettingResult.enabled) {
    return;
  }

  final result = await showOkCancelAlertDialog(
    context: context,
    okLabel: 'OK',
    cancelLabel: 'Cancel',
    title: 'Location Settings',
    message: 'Please enable location services or permissions to continue.',
  );

  if (result != OkCancelResult.ok) {
    logger.w('User canceled recovery of location settings.');
    return;
  }

  if (locationResult == LocationSettingResult.serviceDisabled) {
    await Geolocator.openLocationSettings();
  } else {
    await Geolocator.openAppSettings();
  }
}