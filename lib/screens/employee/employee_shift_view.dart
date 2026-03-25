import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shiftsmart/models/job.dart';
import 'package:shiftsmart/models/site.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/screens/employee/employee_tracking_screen.dart';
import 'package:shiftsmart/services/attendance_service.dart';
import 'package:shiftsmart/services/employee_service.dart';
import 'package:shiftsmart/services/image_picker_service.dart';
import 'package:shiftsmart/services/location_service.dart';
import 'package:shiftsmart/services/shift_service.dart';
import 'package:shiftsmart/services/site_service.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Employeeshiftview extends StatefulWidget {
  final Job job;
  final int shiftId;
  final int employeeId;
  final String scheduledStartTime;
  final String scheduledEndTime;
  final LocationService locationService;
  final ImagePickerService imagePickerService;

  const Employeeshiftview({
    super.key,
    required this.job,
    required this.shiftId,
    required this.employeeId,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    required this.locationService,
    required this.imagePickerService,
  });

  @override
  State<Employeeshiftview> createState() => _EmployeeshiftviewState();
}

class _EmployeeshiftviewState extends State<Employeeshiftview> {
  List<Map<String, DateTime>> breaks = [];
  Map<String, dynamic>? shiftDetails;
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? currentBreakStart;
  DateTime? clockInTime;
  DateTime? clockOutTime;
  bool isClockedIn = false;
  File? clockInPhoto;
  File? clockOutPhoto;
  int? attendanceId;
  Site? currentSite;
  bool isLoading = false;

  // New Variables
  String myStatus = "Pending";
  String? myRejectionReason;
  bool isActionLoading = false;
  List<File> _capturedPhotos = [];

  final SiteService _siteService = SiteService();
  final AttendanceService _attendanceService = AttendanceService();
  final ShiftService _shiftService = ShiftService();
  final LocationService _locationService = RealLocationService();

  final Color green = const Color.fromARGB(255, 1, 126, 42);
  static const Duration networkTimeout = Duration(seconds: 30);

  // --- Helpers ---

  String formatTime(String timeString) {
    try {
      final time = TimeOfDay(
        hour: int.parse(timeString.split(':')[0]),
        minute: int.parse(timeString.split(':')[1]),
      );
      return time.format(context);
    } catch (e) {
      return timeString;
    }
  }

  DateTime _getScheduledStartDateTime() {
    final now = DateTime.now();
    try {
      String timeStr = widget.scheduledStartTime.trim();
      int hour = 0;
      int minute = 0;

      if (timeStr.toLowerCase().contains("pm") ||
          timeStr.toLowerCase().contains("am")) {
        if (timeStr.split(':').length > 2) {
          timeStr =
              "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
        }
        final dt = DateFormat("h:mm a").parse(timeStr);
        hour = dt.hour;
        minute = dt.minute;
      } else {
        final parts = timeStr.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      }
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      debugPrint("⚠️ Start Date Parsing Error: $e");
      return DateTime.now();
    }
  }

  DateTime _getScheduledEndDateTime() {
    final now = DateTime.now();
    try {
      String timeStr = widget.scheduledEndTime.trim();
      int hour = 0;
      int minute = 0;

      if (timeStr.toLowerCase().contains("pm") ||
          timeStr.toLowerCase().contains("am")) {
        if (timeStr.split(':').length > 2) {
          timeStr =
              "${timeStr.split(':')[0]}:${timeStr.split(':')[1]} ${timeStr.split(' ')[1]}";
        }
        final dt = DateFormat("h:mm a").parse(timeStr);
        hour = dt.hour;
        minute = dt.minute;
      } else {
        final parts = timeStr.split(':');
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      }
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      debugPrint("⚠️ End Date Parsing Error: $e");
      return DateTime.now();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSiteData();
    _loadShiftDetailsAndStatus();
    _loadShiftProgress();
    enableFullScreen();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    if (mounted) _disposePhotos();
    super.dispose();
  }

  void _disposePhotos() {
    clockInPhoto = null;
    clockOutPhoto = null;
  }

  Future<void> _loadShiftDetailsAndStatus() async {
    try {
      final myShifts =
          await _shiftService.fetchShiftsByEmployeeIdRaw(widget.employeeId);
      final shift = myShifts.firstWhere(
        (s) => s['ShiftId'] == widget.shiftId,
        orElse: () => {},
      );

      if (shift.isNotEmpty && mounted) {
        setState(() {
          shiftDetails = shift;
          myStatus = shift['MyStatus'] ?? "Pending";
          myRejectionReason = shift['MyRejectionReason'];
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading shift details & status: $e');
    }
  }

  // --- Actions ---

  Future<void> _handleAccept() async {
    setState(() => isActionLoading = true);
    try {
      bool success =
          await _shiftService.respondToShift(widget.shiftId, "Accept");
      if (success) {
        setState(() => myStatus = "Accepted");
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Shift Accepted!")));
      }
    } catch (e) {
      debugPrint("Error accepting shift: $e");
    } finally {
      setState(() => isActionLoading = false);
    }
  }

  Future<void> _handleDecline() async {
    TextEditingController reasonCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C2230),
              title: const Text("Decline Shift",
                  style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Reason (Required)",
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54)),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    if (reasonCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    setState(() => isActionLoading = true);
                    bool success = await _shiftService.respondToShift(
                        widget.shiftId, "Decline",
                        reason: reasonCtrl.text);
                    if (success) setState(() => myStatus = "Declined");
                    setState(() => isActionLoading = false);
                  },
                  child: const Text("Decline"),
                )
              ],
            ));
  }

  Future<void> _handleSwapRequest() async {
    setState(() => isActionLoading = true);
    try {
      bool success = await _shiftService.requestSwap(widget.shiftId);
      if (success) {
        setState(() => myStatus = "Swap Requested");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Swap Requested Successfully")));
      }
    } catch (e) {
      debugPrint("Error requesting swap: $e");
    } finally {
      setState(() => isActionLoading = false);
    }
  }

  Future<void> _loadSiteData() async {
    setState(() => isLoading = true);
    try {
      if (widget.job.siteId == 0 || widget.job.siteId == null) return;
      final site = await _siteService.fetchSiteById(widget.job.siteId!);
      if (site != null) currentSite = site;
    } catch (e) {
      debugPrint('❌ Error loading site data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UPDATED: Properly syncs Break Status from Server ---
  Future<void> _loadShiftProgress() async {
    // 1. Load Local Data (Prevents flickering)
    final prefs = await SharedPreferences.getInstance();
    final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
    final progressData = prefs.getString(key);

    if (progressData != null) {
      final progress = jsonDecode(progressData);
      if (mounted) {
        setState(() {
          clockInTime = progress['clockInTime'] != null
              ? DateTime.parse(progress['clockInTime'])
              : null;
          clockOutTime = progress['clockOutTime'] != null
              ? DateTime.parse(progress['clockOutTime'])
              : null;
          if (progress['breaks'] != null) {
            breaks = (progress['breaks'] as List<dynamic>).map((b) {
              return {
                'start': DateTime.parse(b['start']),
                'end': DateTime.parse(b['end']),
              };
            }).toList();
          }
          if (progress['currentBreakStart'] != null) {
            currentBreakStart =
                DateTime.tryParse(progress['currentBreakStart']);
          }
          attendanceId = progress['attendanceId'];
        });
      }
    }

    try {
      // 2. Fetch Latest Status from Server
      final shift = await _attendanceService.getShiftsByShiftId(
          widget.employeeId,
          shiftId: widget.shiftId) as Map<String, dynamic>?;

      if (shift != null && mounted) {
        // --- Parse Backend Times ---
        final backendClockInTime = shift['ClockInTime'] != null
            ? DateTime.tryParse(shift['ClockInTime'])
            : null;
        final backendClockOutTime = shift['ClockOutTime'] != null
            ? DateTime.tryParse(shift['ClockOutTime'])
            : null;

        // --- NEW: Parse Backend Break Times ---
        final backendBreakStart = shift['BreakStart'] != null
            ? DateTime.tryParse(shift['BreakStart'])
            : null;
        final backendBreakEnd = shift['BreakEnd'] != null
            ? DateTime.tryParse(shift['BreakEnd'])
            : null;

        if (mounted) {
          setState(() {
            // Sync Clock In
            if (backendClockInTime != null) {
              if (attendanceId == null || clockInTime == null) {
                clockInTime = backendClockInTime;
                attendanceId = shift['AttendanceId'];
              }
            }

            // Sync Clock Out
            if (backendClockOutTime != null &&
                backendClockOutTime.year > 1900) {
              clockOutTime = backendClockOutTime;
            }

            // --- Sync Break Status ---
            if (backendBreakStart != null) {
              // Active Break
              if (backendBreakEnd == null) {
                currentBreakStart = backendBreakStart;
              }
              // Finished Break
              else {
                currentBreakStart = null;
                // Add to history if unique
                bool exists = breaks.any((b) =>
                    b['start']!.isAtSameMomentAs(backendBreakStart) &&
                    b['end']!.isAtSameMomentAs(backendBreakEnd!));

                if (!exists) {
                  breaks.add({
                    'start': backendBreakStart,
                    'end': backendBreakEnd,
                  });
                }
              }
            }
          });

          _saveShiftProgress();
        }
      }
    } catch (e) {
      debugPrint('Error fetching shift status: $e');
    }
  }

  Future<void> _saveShiftProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
    final progressData = {
      'clockInTime': clockInTime?.toIso8601String(),
      'clockOutTime': clockOutTime?.toIso8601String(),
      'breaks': breaks
          .map((b) => {
                'start': b['start']!.toIso8601String(),
                'end': b['end']!.toIso8601String()
              })
          .toList(),
      'currentBreakStart': currentBreakStart?.toIso8601String(),
      'attendanceId': attendanceId,
    };
    await prefs.setString(key, jsonEncode(progressData));
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  Future<bool> _validateGeofence() async {
    if (currentSite == null) return false;
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      final siteLat = double.tryParse(currentSite!.latitude ?? '');
      final siteLng = double.tryParse(currentSite!.longitude ?? '');

      if (siteLat == null || siteLng == null) return false;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        siteLat,
        siteLng,
      );
      return distance <= (currentSite!.radius ?? 150);
    } catch (e) {
      debugPrint("Geofence Check Failed: $e");
      return false;
    }
  }

  Future<bool> _capturePhotos() async {
    _capturedPhotos.clear();
    bool done = false;

    while (!done && _capturedPhotos.length < 5) {
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1C2230),
          title: Text("Add Photo (${_capturedPhotos.length}/5)",
              style: const TextStyle(color: Colors.white)),
          content: const Text("You must take at least one photo.",
              style: TextStyle(color: Colors.white70)),
          actions: [
            if (_capturedPhotos.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // Done
                child: const Text("Done", style: TextStyle(color: Colors.blue)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => Navigator.pop(ctx, true), // Add Photo
              child: const Text("Take Photo"),
            ),
          ],
        ),
      );

      if (shouldAdd == true) {
        final File? photo = await widget.imagePickerService.pickImage();
        if (photo != null) {
          setState(() {
            _capturedPhotos.add(File(photo.path));
          });
        }
      } else {
        done = true;
      }
    }
    return _capturedPhotos.isNotEmpty;
  }

  Future<void> _clearOldShiftData() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'shift_progress_${widget.employeeId}_${widget.shiftId}';
    await prefs.remove(key);
    _capturedPhotos.clear();
    if (mounted) {
      setState(() {
        clockInTime = null;
        clockOutTime = null;
        breaks.clear();
        currentBreakStart = null;
        attendanceId = null;
      });
    }
  }

  // --- CLOCK IN (Strict Geofence + GPS + Multi-Photo) ---
  Future<void> _handleClockIn() async {
    if (mounted) setState(() => isLoading = true);
    try {
      if (!await _checkLocationPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Location permission is required.')));
          setState(() => isLoading = false);
        }
        return;
      }

      // 🛑 STRICT CHECK: Validate Geofence BEFORE anything else
      bool inRange = await _validateGeofence();
      if (!inRange) {
        if (mounted) {
          setState(() => isLoading = false);
          // Show strict warning dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C2230),
              title: const Text("Out of Range",
                  style: TextStyle(color: Colors.redAccent)),
              content: const Text(
                "You are not within the allowed range of the site.\n\nYou cannot clock in or take photos until you are on site.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 🕒 TIME CHECK: Is it within the shift window?
      final now = DateTime.now();
      final scheduledStart = _getScheduledStartDateTime();
      final scheduledEnd = _getScheduledEndDateTime();
      
      // Allow clock-in up to 15 minutes before start
      final earliestAllowed = scheduledStart.subtract(const Duration(minutes: 15));

      if (now.isBefore(earliestAllowed)) {
        if (mounted) {
          setState(() => isLoading = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C2230),
              title: const Text("Too Early", style: TextStyle(color: Colors.orangeAccent)),
              content: Text(
                "You cannot clock in yet.\n\nScheduled Start: ${DateFormat('hh:mm a').format(scheduledStart)}\nEarliest Clock-in: ${DateFormat('hh:mm a').format(earliestAllowed)}",
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
              ],
            ),
          );
        }
        return;
      }

      if (now.isAfter(scheduledEnd)) {
        if (mounted) {
          setState(() => isLoading = false);
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1C2230),
              title: const Text("Shift Ended", style: TextStyle(color: Colors.redAccent)),
              content: Text(
                "The scheduled shift has already ended.\n\nScheduled End: ${DateFormat('hh:mm a').format(scheduledEnd)}",
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
              ],
            ),
          );
        }
        return;
      }

      // 1. Capture Photos (Only if in range)
      bool hasPhotos = await _capturePhotos();
      if (!hasPhotos) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('At least one photo is required.')));
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final result = await _attendanceService.clockIn(
        employeeId: widget.employeeId,
        shiftId: widget.shiftId,
        siteId: widget.job.siteId ?? 0,
        scheduledStartTime: widget.scheduledStartTime,
        photos: _capturedPhotos,
        clockInTime: now,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (result['success']) {
        final attendanceIdFromResponse = result['attendanceId'];
        if (mounted) {
          setState(() {
            clockInTime = now;
            attendanceId = attendanceIdFromResponse;
            clockInPhoto =
                _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
          });
        }
        await _saveShiftProgress();
        await _sendEmployeeLocation(position);
        _startLocationTracking();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Clock-in successful!')));
        }
      } else {
        throw Exception(result['error'] ?? 'Unknown clock-in error');
      }
    } catch (e) {
      debugPrint('Clock-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Clock-in failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startLocationTracking() async {
    final locationSettings =
        LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) async {
      await _sendEmployeeLocation(position);
    });
  }

  Future<void> _sendEmployeeLocation(Position position) async {
    try {
      await _locationService.sendLocation(position, widget.employeeId);
    } catch (e) {
      debugPrint("❌ Error sending employee location: $e");
    }
  }

  Widget _buildDebugButton() {
    return ElevatedButton(
      onPressed: _clearOldShiftData,
      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
      child: const Text('Clear Old Data'),
    );
  }

  // --- CLOCK OUT (Early Warning & Multi-Photo) ---
  Future<void> _handleClockOut() async {
    if (attendanceId == null) return;

    // 🛑 STRICT CHECK: Cannot Clock Out during an active break
    if (currentBreakStart != null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C2230),
            title: const Text("Active Break",
                style: TextStyle(color: Colors.orangeAccent)),
            content: const Text(
              "You cannot clock out while on a break.\n\nPlease end your break first.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    final scheduledEnd = _getScheduledEndDateTime();

    // 🛑 CHECK: Is it Early Departure?
    bool isEarly =
        now.isBefore(scheduledEnd.subtract(const Duration(minutes: 5)));
    
    String? earlyExitReason;

    if (isEarly) {
      bool? confirmEarly = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1C2230),
          title: const Text("Early Departure Warning",
              style: TextStyle(color: Colors.orangeAccent)),
          content: const Text(
            "You are attempting to clock out BEFORE your scheduled end time.\n\nAre you sure you want to proceed?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // No
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true), // Yes
              child: const Text("Yes, Clock Out Early"),
            ),
          ],
        ),
      );

      if (confirmEarly != true) return; // User cancelled

      // captures early exit reason
      final String? reason = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final controller = TextEditingController();
          final formKey = GlobalKey<FormState>();
          return AlertDialog(
            backgroundColor: const Color(0xFF1C2230),
            title: const Text("Early Departure Reason",
                style: TextStyle(color: Colors.white)),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "You are clocking out early. Please provide a reason to proceed.",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Reason for early exit",
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Reason is required for early clock-out';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, controller.text);
                  }
                },
                child: const Text("Submit"),
              ),
            ],
          );
        },
      );

      if (reason == null) {
        if (mounted) setState(() => isLoading = false);
        return; // User cancelled or didn't provide reason
      }
      
      earlyExitReason = reason;
    }

    if (mounted) setState(() => isLoading = true);

    try {
      // 1. Capture Photos
      bool hasPhotos = await _capturePhotos();
      if (!hasPhotos) {
        if (mounted) {
          setState(() => isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('At least one photo is required.')));
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 2. Calculate Total Break Duration
      int totalBreakMinutes = 0;
      for (var b in breaks) {
        if (b['start'] != null && b['end'] != null) {
          totalBreakMinutes += b['end']!.difference(b['start']!).inMinutes;
        }
      }

      // 3. Call Service
      final result = await _attendanceService.clockOut(
        attendanceId: attendanceId!,
        shiftId: widget.shiftId,
        clockOutTime: now,
        photos: _capturedPhotos,
        latitude: position.latitude,
        longitude: position.longitude,
        clockInTime: clockInTime,
        totalBreakMinutes: totalBreakMinutes,
        earlyExitReason: earlyExitReason,
        timeout: networkTimeout,
      );

      if (result['success']) {
        if (mounted) {
          setState(() {
            clockOutTime = now;
            clockOutPhoto =
                _capturedPhotos.isNotEmpty ? _capturedPhotos.first : null;
          });
        }
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final profile = userProvider.userProfile;
        final employeeName = profile.isNotEmpty 
            ? "${profile['firstName'] ?? ''} ${profile['lastName'] ?? ''}".trim()
            : "An employee";
            
        await NotificationService()
            .sendShiftCompletionNotification(employeeName, widget.shiftId, now);
        await _saveShiftProgress();

        if (mounted) {
          if (isEarly) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.orange[800],
              content: const Text(
                  '⚠ Early Departure Recorded. You clocked out early.'),
            ));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Clock-out successful!')));
          }
        }
      } else {
        throw Exception(result['error'] ?? 'Unknown clock-out error');
      }
    } catch (e) {
      debugPrint('Clock-out error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Clock-out failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UPDATED: Fix for Timezone Issue (Break Start) ---
  Future<void> _handleBreakStart() async {
    if (attendanceId == null) return;
    if (mounted) setState(() => isLoading = true);
    try {
      // 1. Capture Local Time
      final now = DateTime.now();

      // 2. Send 'now' to the service
      final result =
          await _attendanceService.breakStart(attendanceId!, startTime: now);

      if (result == true) {
        if (mounted) setState(() => currentBreakStart = now);
        await _saveShiftProgress();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Break started!')));
        }
      }
    } catch (e) {
      debugPrint('Break start error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UPDATED: Fix for Timezone Issue (Break End) ---
  Future<void> _handleBreakEnd() async {
    if (attendanceId == null) return;
    if (mounted) setState(() => isLoading = true);
    try {
      // 1. Capture Local Time
      final now = DateTime.now();

      // 2. Send 'now' to the service
      final result =
          await _attendanceService.endBreak(attendanceId!, endTime: now);

      if (result == true) {
        if (mounted) {
          setState(() {
            if (currentBreakStart != null) {
              breaks.add({'start': currentBreakStart!, 'end': now});
              currentBreakStart = null;
            }
          });
        }
        await _saveShiftProgress();
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Break ended!')));
      }
    } catch (e) {
      debugPrint('Break end error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          backgroundColor: Colors.transparent,
          drawer: const Sidenav(),
          appBar: const Uppernavbar(showBackButton: true),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Gradienthorizontal(
                    width: MediaQuery.of(context).size.width,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildShiftInfoCard(),
                          const SizedBox(height: 24),
                          if (isActionLoading)
                            const CircularProgressIndicator()
                          else if (myStatus == "Pending")
                            _buildAcknowledgementCard()
                          else if (myStatus == "Declined")
                            _buildStatusMessage(
                                "⛔ You have declined this shift.", Colors.red)
                          else if (myStatus == "Swap Requested")
                            _buildStatusMessage(
                                "🔄 Swap Requested. Waiting for approval.",
                                Colors.orange)
                          else if (myStatus == "Accepted")
                            _buildTimeTrackingCard(),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLiveTrackingButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          if (currentSite != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmployeeTrackingScreen(
                  currentSite: currentSite!,
                  employeeId: widget.employeeId,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Site location not available.")),
            );
          }
        },
        icon: const Icon(Icons.map, color: Colors.white),
        label: const Text("View Live Location Map",
            style: TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildAcknowledgementCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            "Shift Acknowledgment",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            "Please accept this shift to start tracking time.",
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleDecline,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  child: const Text("Decline"),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleAccept,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Accept"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _handleSwapRequest,
            icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
            label: const Text("Request Swap",
                style: TextStyle(color: Colors.orangeAccent)),
          )
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String msg, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        msg,
        style:
            TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildShiftInfoCard() {
    final date = shiftDetails?['Date'];
    final formattedDate = date != null
        ? DateFormat.yMMMMd().format(DateTime.parse(date))
        : 'Loading...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.job.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          shiftDetails?['TaskName'] ?? 'Loading...',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                color: Colors.white.withValues(alpha: 0.9), size: 18),
            const SizedBox(width: 8),
            Text(
              'Date: $formattedDate',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.schedule,
                color: Colors.white.withValues(alpha: 0.9), size: 18),
            const SizedBox(width: 8),
            Text(
              'Start: ${formatTime(widget.scheduledStartTime)}',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.schedule_outlined,
                color: Colors.white.withValues(alpha: 0.9), size: 18),
            const SizedBox(width: 8),
            Text(
              'End: ${formatTime(widget.scheduledEndTime)}',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
            ),
          ],
        ),
        if (currentSite != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on,
                  color: Colors.white.withValues(alpha: 0.9), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentSite!.siteName,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeTrackingCard() {
    if (attendanceId == null && clockInTime != null) {
      _buildDebugButton();
    }

    final isBreakEnabled = clockInTime != null && clockOutTime == null;

    bool isEarlyDeparture = false;
    if (clockOutTime != null) {
      final scheduledEnd = _getScheduledEndDateTime();
      isEarlyDeparture = clockOutTime!
          .isBefore(scheduledEnd.subtract(const Duration(minutes: 1)));
    }

    return Container(
      child: Column(
        children: [
          Container(width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                if (clockOutTime != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isEarlyDeparture
                          ? Colors.orange.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEarlyDeparture
                            ? Colors.orange.withValues(alpha: 0.5)
                            : Colors.green.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isEarlyDeparture
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle,
                          color:
                              isEarlyDeparture ? Colors.orange : Colors.green,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEarlyDeparture
                                    ? 'Early Departure'
                                    : 'Shift Completed!',
                                style: TextStyle(
                                  color: isEarlyDeparture
                                      ? Colors.orange
                                      : Colors.green,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEarlyDeparture
                                    ? 'You clocked out at ${DateFormat('hh:mm a').format(clockOutTime!)} before the scheduled end time.'
                                    : 'You have successfully completed your shift at ${DateFormat('hh:mm a').format(clockOutTime!)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (clockOutTime == null) ...[
                  _buildTimeTrackingItem(
                    clockInTime == null ? "Clock In" : "Clock Out",
                    clockInTime,
                    clockInTime == null ? Icons.login : Icons.logout,
                    clockInTime == null ? "Clock In" : "Clock Out",
                    clockInTime == null
                        ? () => _handleClockIn()
                        : () => _handleClockOut(),
                    isEnabled: clockOutTime == null,
                    photo: clockInTime == null ? clockInPhoto : clockOutPhoto,
                  ),
                ] else
                  _buildTimeTrackingItem(
                    "Clock Out",
                    clockOutTime,
                    Icons.logout,
                    "Shift Completed",
                    () {},
                    isEnabled: false,
                    photo: clockOutPhoto,
                  ),
                const SizedBox(height: 16),
                if (clockInTime != null && clockOutTime == null) ...[
                  if (currentBreakStart == null)
                    _buildTimeTrackingItem(
                      "Start Break",
                      null,
                      Icons.free_breakfast,
                      "Start Break",
                      _handleBreakStart,
                      isEnabled: isBreakEnabled,
                    )
                  else
                    // 🔴 UPDATED: End Break Button with Distinct Color
                    _buildTimeTrackingItem(
                      "End Break",
                      currentBreakStart,
                      Icons.task_alt,
                      "End Break",
                      _handleBreakEnd,
                      isEnabled: isBreakEnabled,
                      customButtonColor: Colors.orangeAccent, // Changed color
                      customTextColor: Colors.black,
                    ),
                  const SizedBox(height: 16),
                  _buildLiveTrackingButton(),
                  const SizedBox(height: 16),
                ],
                if (breaks.isNotEmpty) ...[
                  _buildBreakHistory(),
                  const SizedBox(height: 16),
                ],
                if (clockOutTime != null) ...[
                  _buildShiftSummary(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftSummary() {
    if (clockInTime == null || clockOutTime == null) return SizedBox.shrink();

    final duration = clockOutTime!.difference(clockInTime!);
    if (duration.isNegative) {
      return const Text(
        '⚠ Shift times are invalid (Clock-out before Clock-in)',
        style: TextStyle(color: Colors.redAccent, fontSize: 14),
      );
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Shift Summary',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.login, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Clock In: ${DateFormat('hh:mm a').format(clockInTime!)}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                'Clock Out: ${DateFormat('hh:mm a').format(clockOutTime!)}',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Text(
                'Total Time: ${hours}h ${minutes}m',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (breaks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.free_breakfast, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Breaks Taken: ${breaks.length}',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeTrackingItem(
    String label,
    DateTime? time,
    IconData icon,
    String buttonText,
    VoidCallback onPressed, {
    bool? isEnabled,
    File? photo,
    Color? customButtonColor,
    Color? customTextColor,
  }) {
    final isRecorded = time != null;
    final buttonEnabled = isEnabled ?? !isRecorded;

    // Use custom color if provided, else logic
    final isRedButton = buttonText.toLowerCase().contains("out") ||
        buttonText.toLowerCase().contains("end");

    final buttonColor = customButtonColor ?? (isRedButton ? Colors.red : green);
    final textColor = customTextColor ?? Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                time != null
                    ? DateFormat('hh:mm:ss a').format(time)
                    : "Time: 00:00:00",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: buttonEnabled ? onPressed : null,
              icon: Icon(
                buttonText == "Completed" ? Icons.check_circle : icon,
                size: 20,
                color: buttonEnabled ? textColor : null,
              ),
              label: Text(
                buttonText,
                style: TextStyle(
                  fontSize: 16,
                  color: buttonEnabled ? textColor : null,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    buttonEnabled ? buttonColor : buttonColor.withValues(alpha: 0.4),
                foregroundColor: textColor,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'Break History',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...breaks.map((breakItem) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.white70, size: 8),
                    const SizedBox(width: 8),
                    Text(
                      '${DateFormat('hh:mm a').format(breakItem['start']!)} - ${DateFormat('hh:mm a').format(breakItem['end']!)}',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
