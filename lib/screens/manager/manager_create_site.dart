import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:shiftsmart/models/project.dart';
import 'package:shiftsmart/models/site.dart';
import 'package:shiftsmart/services/project_service.dart';
import 'package:shiftsmart/services/site_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradient_button.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';

class Managercreatesite extends StatefulWidget {
  final Site? site;
  const Managercreatesite({super.key, this.site});

  @override
  State<Managercreatesite> createState() => _ManagercreatesiteState();
}

class _ManagercreatesiteState extends State<Managercreatesite> {
  // Controllers
  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _latitudeController =
      TextEditingController(text: "-33.8688");
  final TextEditingController _longitudeController =
      TextEditingController(text: "151.2093");

  // State Variables
  LatLng? _selectedLocation;
  List<Project> allProjects = [];
  int? _selectedProjectId;
  List<String> _suggestions = [];
  String tokenForSession = const Uuid().v4();
  bool _isSaving = false;

  // Services & Maps
  final ProjectService _projectService = ProjectService();
  GoogleMapController? mapController;
  static const LatLng _defaultCenter = LatLng(-33.8688, 151.2093);

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    fetchProjects();

    // Populate fields if editing
    if (widget.site != null) {
      _siteNameController.text = widget.site!.siteName;
      _addressController.text =
          widget.site!.address ?? ""; // <-- USE ADDRESS HERE
      _latitudeController.text = widget.site!.latitude ?? "-33.8688";
      _longitudeController.text = widget.site!.longitude ?? "151.2093";
      _selectedProjectId = widget.site!.projectId;
    }

    _selectedLocation = _currentLatLng();
  }

  // --- Fetch Projects ---
  Future<void> fetchProjects() async {
    try {
      final projects = await _projectService.fetchAllProjects();
      if (mounted) {
        setState(() {
          allProjects = projects;
        });
      }
    } catch (e) {
      debugPrint("Error fetching projects: $e");
    }
  }

  // --- Map Controller ---
  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    final selected = _selectedLocation;
    if (selected != null) {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: selected, zoom: 15),
        ),
      );
    }
  }

  LatLng _currentLatLng() {
    return LatLng(
      double.tryParse(_latitudeController.text.trim()) ??
          _defaultCenter.latitude,
      double.tryParse(_longitudeController.text.trim()) ??
          _defaultCenter.longitude,
    );
  }

  Future<void> _selectLocation(LatLng latLng,
      {bool updateAddress = true}) async {
    setState(() {
      _latitudeController.text = latLng.latitude.toString();
      _longitudeController.text = latLng.longitude.toString();
      _selectedLocation = latLng;
    });

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 16),
      ),
    );

    if (!updateAddress) return;

    try {
      final placemarks =
          await geo.placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final parts = [
          place.name,
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ]
            .where((part) => part != null && part.trim().isNotEmpty)
            .map((part) => part!.trim())
            .toSet()
            .toList();
        if (parts.isNotEmpty) {
          setState(() => _addressController.text = parts.join(', '));
        }
      }
    } catch (e) {
      debugPrint("Reverse geo error: $e");
    }
  }

  // --- Address Lookup (Forward Geocoding) ---
  Future<void> _moveMapToAddress() async {
    final address = _addressController.text;
    if (address.isEmpty) return;

    try {
      final locations = await geo.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);

        await _selectLocation(latLng, updateAddress: false);
      }
    } catch (e) {
      debugPrint("Address lookup failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Address not found on map")),
        );
      }
    }
  }

  // --- Google Places Autocomplete ---
  Future<List<Map<String, String>>> makeSuggestion(String input) async {
    String key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$key&sessiontoken=$tokenForSession";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final predictions = json['predictions'] as List;
        return predictions.map<Map<String, String>>((e) {
          return {
            "description": e['description'],
            "place_id": e['place_id'],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Autocomplete error: $e");
    }
    return [];
  }

  // --- Submit Site ---
  Future<void> _submitSite() async {
    // 1. Validation
    if (_siteNameController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Site Name is required")));
      return;
    }
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Address is required")));
      return;
    }
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a project")));
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a map location")));
      return;
    }

    setState(() => _isSaving = true);

    final siteData = {
      "ProjectId": _selectedProjectId,
      "SiteName": _siteNameController.text.trim(),
      "Address": _addressController.text.trim(),
      "Latitude": double.tryParse(_latitudeController.text.trim()) ?? 0.0,
      "Longitude": double.tryParse(_longitudeController.text.trim()) ?? 0.0,
      "GeoFenceType": "circle",
      "GeoCoordinates": "",
      "Radius": 150.5,
    };

    bool success = false;

    // 2. API Call
    try {
      if (widget.site != null) {
        success = await SiteService().updateSite(widget.site!.siteId, siteData);
      } else {
        success = await SiteService().addSite(siteData);
      }
    } catch (e) {
      debugPrint("Error saving site: $e");
      success = false;
    }

    setState(() => _isSaving = false);

    // 3. Success Handling
    if (mounted) {
      if (success) {
        // --- Show Success Dialog ---
        SuccessDialog.show(
          context,
          title: widget.site != null ? "Site Updated" : "Site Created",
          message: widget.site != null
              ? "The site details have been updated successfully."
              : "New site has been created successfully.",
          buttonText: "OK",
          onPressed: () {
            Navigator.pop(context, true); // Return to list screen with 'true'
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save site")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: const Sidenav(),
        backgroundColor: const Color(0xFF1C2230),
        appBar: const Uppernavbar(
          showBackButton: true,
        ),
        body: Stack(
          children: [
            const Background(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Gradienthorizontal(
                width: double.infinity,
                height: double.maxFinite,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            widget.site != null ? "UPDATE SITE" : "CREATE SITE",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Form Fields
                        _buildDropdownProject(),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _siteNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Site Name (e.g. Head Office)",
                            labelStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.2),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Address Field with Autocomplete
                        _buildSiteAddressField(),

                        const SizedBox(height: 16),

                        // Map Widget
                        _buildMapPinSection(),

                        const SizedBox(height: 20),

                        // Action Buttons (Fixed Overflow)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: GradientButton(
                                text: "Cancel",
                                onPressed: () => Navigator.pop(context),
                                isCancel: true,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: GradientButton(
                                text: _isSaving
                                    ? (widget.site != null
                                        ? "Updating..."
                                        : "Creating...")
                                    : (widget.site != null
                                        ? "Update"
                                        : "Create"),
                                onPressed: _submitSite,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ));
  }

  // --- UI Helper: Address Field ---
  Widget _buildSiteAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _addressController,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) async {
            if (value.isNotEmpty) {
              final results = await makeSuggestion(value);
              setState(() {
                _suggestions =
                    results.map((e) => e['description'] ?? '').toList();
              });
            } else {
              setState(() {
                _suggestions = [];
              });
            }
          },
          decoration: InputDecoration(
            labelText: "Site Address",
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.2),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: _moveMapToAddress,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Suggestions Dropdown
        if (_suggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  title: Text(
                    suggestion,
                    style: const TextStyle(color: Colors.black),
                  ),
                  onTap: () {
                    _addressController.text = suggestion;
                    _moveMapToAddress();
                    setState(() {
                      _suggestions.clear();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // --- UI Helper: Project Dropdown ---
  Widget _buildDropdownProject() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Project",
          style: TextStyle(
              color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              dropdownColor: const Color(0xFF2A3243),
              value: _selectedProjectId,
              isExpanded: true,
              style: const TextStyle(color: Colors.white),
              items: allProjects.map((project) {
                return DropdownMenuItem<int>(
                  value: project.projectId,
                  child: Text(project.name),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedProjectId = value),
              hint: const Text("Choose a project",
                  style: TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Google Map ---
  Widget _buildMapPinSection() {
    final selected = _selectedLocation ?? _currentLatLng();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Map Pin",
            style: TextStyle(
              color: Color(0xFF85E8FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Tap on the map to adjust the exact site coordinates.",
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 18),
          RichText(
            text: const TextSpan(
              text: "Select Location",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(text: "*", style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: selected,
                  zoom: 15,
                ),
                onTap: _selectLocation,
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: selected,
                    infoWindow: const InfoWindow(title: 'Selected location'),
                  ),
                },
                mapType: MapType.normal,
                zoomControlsEnabled: true,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
