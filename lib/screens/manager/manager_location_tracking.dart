import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/models/site.dart';
import 'package:shiftsmart/models/site_employee.dart';
import 'package:shiftsmart/services/site_service.dart';

class ManagerLocationTracking extends StatefulWidget {
  final int siteId;

  const ManagerLocationTracking({super.key, required this.siteId});

  @override
  State<ManagerLocationTracking> createState() =>
      _ManagerLocationTrackingState();
}

class _ManagerLocationTrackingState extends State<ManagerLocationTracking> {
  Site? currentSite;
  List<Site> availableSites = [];
  List<SiteEmployee> employees = [];
  bool isLoading = true;
  final Completer<GoogleMapController> _mapController = Completer();
  Set<Marker> _markers = {};
  LatLng _mapCenter = _defaultMapCenter;
  final double _mapZoom = 15.0;
  List<SiteEmployee> filteredEmployees = [];
  final SiteService _siteService = SiteService();
  Timer? _refreshTimer;
  MapType _mapType = MapType.normal;
  static const LatLng _defaultMapCenter = LatLng(-33.8688, 151.2093);

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _loadSiteData();

    // Auto-refresh locations every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshEmployeeLocations();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSiteData() async {
    try {
      final site = await _fetchSiteDetails(widget.siteId);
      final sitePosition = _siteLatLng(site);

      setState(() {
        currentSite = site;
        _mapCenter = sitePosition ?? _defaultMapCenter;
      });

      await _refreshEmployeeLocations();
    } catch (e) {
      setState(() {
        isLoading = false;
        _mapCenter = _defaultMapCenter;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _onSiteSelected(Site site) {
    setState(() {
      currentSite = site;
      final sitePosition = _siteLatLng(site);
      _mapCenter = sitePosition ?? _defaultMapCenter;
    });
    _refreshEmployeeLocations();
  }

  Future<void> _refreshEmployeeLocations() async {
    if (currentSite == null) return;

    try {
      final siteEmployees =
          await _siteService.fetchEmployeesInSite(widget.siteId, currentSite!);

      if (mounted) {
        setState(() {
          employees = siteEmployees;
          filteredEmployees = List.from(siteEmployees);
          isLoading = false;
          _createMarkers(currentSite!, siteEmployees);
        });
        await _fitMapToContent();
      }
    } catch (e) {
      debugPrint("Error refreshing locations: $e");
    }
  }

  void _createMarkers(Site site, List<SiteEmployee> employees) {
    final markers = <Marker>{};
    final sitePosition = _siteLatLng(site);

    if (sitePosition != null) {
      // 1. Site Marker
      markers.add(Marker(
        markerId: MarkerId('site_${site.siteId}'),
        position: sitePosition,
        infoWindow: InfoWindow(
          title: site.siteName,
          snippet: "Radius: ${site.radius}m",
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    // 2. Employee Markers
    for (final employee in employees) {
      if (employee.clockInLat != null && employee.clockInLng != null) {
        final double markerHue = employee.isInside
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed;
        final distanceText = employee.distance == null
            ? 'Outside fence'
            : 'Outside (${(employee.distance! * 1000).toStringAsFixed(0)}m away)';

        markers.add(Marker(
          markerId: MarkerId('employee_${employee.employeeId}'),
          position: LatLng(employee.clockInLat!, employee.clockInLng!),
          infoWindow: InfoWindow(
            title: employee.name,
            snippet: employee.isInside ? 'Inside Fence' : distanceText,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        ));
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    if (!_mapController.isCompleted) {
      _mapController.complete(controller);
    }
    await _fitMapToContent();
  }

  Future<void> _fitMapToContent() async {
    if (!_mapController.isCompleted) return;

    final controller = await _mapController.future;
    final points = <LatLng>[_mapCenter];

    for (final employee in employees) {
      if (employee.clockInLat != null && employee.clockInLng != null) {
        points.add(LatLng(employee.clockInLat!, employee.clockInLng!));
      }
    }

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _mapCenter, zoom: _mapZoom),
        ),
      );
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(_boundsFromLatLngList(points), 56),
    );
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  LatLng? _siteLatLng(Site site) {
    final lat = double.tryParse(site.latitude ?? '');
    final lng = double.tryParse(site.longitude ?? '');

    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

    // Most bad site records in this app arrive as 0/0 after failed parsing.
    if (lat == 0 && lng == 0) return null;

    return LatLng(lat, lng);
  }

  Future<Site> _fetchSiteDetails(int siteId) async {
    final site = await _siteService.fetchSiteById(siteId);
    if (site != null) {
      return site;
    } else {
      throw Exception('Site not found');
    }
  }

  void onQueryChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredEmployees = List.from(employees);
      } else {
        filteredEmployees = employees
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          backgroundColor: Colors.transparent,
          drawer: const Sidenav(currentScreen: 'LocationTracking'),
          extendBodyBehindAppBar: true,
          appBar: const Uppernavbar(showBackButton: false),
          body: SafeArea(
            child: Stack(
              children: [
                // Full-screen map
                Positioned.fill(
                  child: _buildMapContent(),
                ),
                // Site Selector at top center
                Positioned(
                  top: 24,
                  left: 50,
                  right: 50,
                  child: _buildSiteSelector(),
                ),
                // Map type toggle - below site selector on left
                Positioned(
                  left: 24,
                  top: 150,
                  child: _buildMapTypeToggle(),
                ),
                // Refresh button - top right of selector
                Positioned(
                  right: 40,
                  top: 32,
                  child: Material(
                    color: Colors.transparent,
                    child: IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Color(0xFF6B7280), size: 20),
                      onPressed: () => _refreshEmployeeLocations(),
                      tooltip: 'Refresh',
                    ),
                  ),
                ),
                // Recenter button - bottom right
                Positioned(
                  right: 24,
                  bottom: 140,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: IconButton(
                      tooltip: 'Recenter',
                      icon: const Icon(Icons.my_location,
                          color: Color(0xFF1F2937)),
                      onPressed: _fitMapToContent,
                    ),
                  ),
                ),
                // Zoom controls - right side
                Positioned(
                  right: 24,
                  bottom: 200,
                  child: _buildZoomControls(),
                ),
                // Bottom Tracking Status Panel
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildTrackingPanel(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: _mapCenter,
        zoom: _mapZoom,
      ),
      markers: _markers,
      mapType: _mapType,
      zoomControlsEnabled: false,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      circles: currentSite != null && _siteLatLng(currentSite!) != null
          ? {
              Circle(
                circleId: CircleId('geofence_${currentSite!.siteId}'),
                center: _siteLatLng(currentSite!)!,
                radius: currentSite!.radius ?? 0.0,
                strokeWidth: 2,
                strokeColor: const Color(0xFF6EA8FF),
                fillColor: const Color(0xFF6EA8FF).withValues(alpha: 0.18),
              )
            }
          : {},
    );
  }

  Widget _buildSiteSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Site',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              PopupMenuButton<Site>(
                initialValue: currentSite,
                onSelected: _onSiteSelected,
                itemBuilder: (context) => [
                  const PopupMenuItem<Site>(
                    enabled: false,
                    child: Text('Choose a site'),
                  ),
                  const PopupMenuDivider(),
                  ...availableSites.map((site) => PopupMenuItem(
                        value: site,
                        child: Text(site.siteName),
                      )),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSite?.siteName ?? 'Choose a site',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a site to start tracking',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          child: IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF6B7280)),
            onPressed: () async {
              final controller = await _mapController.future;
              controller.animateCamera(CameraUpdate.zoomIn());
            },
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 4,
          child: IconButton(
            icon: const Icon(Icons.remove, color: Color(0xFF6B7280)),
            onPressed: () async {
              final controller = await _mapController.future;
              controller.animateCamera(CameraUpdate.zoomOut());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tracking',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                currentSite == null ? 'No site selected' : '${employees.length} active',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currentSite == null
                ? 'No clocked-in employees for this site.'
                : employees.isEmpty
                    ? 'No employees currently active'
                    : '${employees.length} employee${employees.length != 1 ? 's' : ''} checked in',
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTypeToggle() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mapTypeButton('Map', MapType.normal),
          Container(
            width: 1,
            height: 36,
            color: Colors.black.withValues(alpha: 0.08),
          ),
          _mapTypeButton('Satellite', MapType.satellite),
        ],
      ),
    );
  }

  Widget _mapTypeButton(String label, MapType mapType) {
    final selected = _mapType == mapType;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.black : const Color(0xFF666666),
        backgroundColor: selected ? Colors.white : const Color(0xFFF9FAFB),
        minimumSize: const Size(78, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      ),
      onPressed: () {
        setState(() => _mapType = mapType);
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
