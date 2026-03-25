import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/leave_request.dart';
import 'package:shiftsmart/services/employee_service.dart';
import 'package:shiftsmart/services/job_service.dart';
import 'package:shiftsmart/services/shift_service.dart';
import 'package:shiftsmart/services/site_service.dart';
import 'package:shiftsmart/services/leave_service.dart';
import 'package:shiftsmart/widgets/custom_date_picker.dart';
import 'package:shiftsmart/models/employee.dart';
import 'package:shiftsmart/models/job.dart';
import 'package:shiftsmart/models/shift.dart';
import 'package:shiftsmart/models/site.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/gradient_button.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';
import 'package:shiftsmart/services/notification_service.dart';
import 'package:shiftsmart/widgets/success_dialog.dart';

class Managercreateshift extends StatefulWidget {
  final Shift? shift;
  const Managercreateshift({super.key, this.shift});

  @override
  State<Managercreateshift> createState() => _ManagercreateshiftState();
}

class _ManagercreateshiftState extends State<Managercreateshift> {
  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _starttimecontroller = TextEditingController();
  final TextEditingController _endtimecontroller = TextEditingController();

  // Data Lists
  List<Employee> allEmployees = [];
  final List<int> _selectedEmptIds = [];
  List<Job> allJobs = [];
  List<Shift> allShifts = [];
  List<LeaveRequest> allLeaves = [];
  List<Site> _sites = [];
  final List<DateTime> _selectedDates = [];

  // Selections
  int? _selectedJobId;
  Map<int, String> employeeNameMap = {};

  // Services & State
  final NotificationService _notificationService = NotificationService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _initializeData();
  }

  // --- 1. Initialize All Data ---
  Future<void> _initializeData() async {
    await Future.wait([
      fetchJobs(),
      fetchEmployee(),
      fetchSites(),
      fetchAllShifts(),
      fetchAllLeaves(),
    ]);

    final dateFormat = DateFormat('yyyy-MM-dd');

    if (widget.shift != null && mounted) {
      // Pre-fill if editing
      setState(() {
        _titleController.text = widget.shift!.taskName;
        _dateController.text = dateFormat.format(widget.shift!.date);
        _starttimecontroller.text = widget.shift!.startTime;
        _endtimecontroller.text = widget.shift!.endTime;
        _selectedJobId = widget.shift!.jobId;
        _selectedEmptIds.addAll(widget.shift!.assignedEmployeeIds);
        _selectedDates.add(widget.shift!.date);
      });
    } else if (mounted) {
      // Default values for new shift
      setState(() {
        _dateController.text = dateFormat.format(DateTime.now());
        _starttimecontroller.text = "07:00:00";
        _endtimecontroller.text = "15:00:00";
        _selectedDates.add(DateTime.now());
      });
      // Initial auto-name attempt (might be empty until job is selected)
      _updateAutoShiftName();
    }
  }

  // Helper: Auto-generate Shift Name
  void _updateAutoShiftName() {
    if (_selectedJobId == null) return;

    final selectedJob = allJobs.firstWhere(
      (job) => job.jobId == _selectedJobId,
      orElse: () => allJobs.isNotEmpty ? allJobs.first : Job(jobId: 0, title: '', description: '', status: '', projectId: 0, totalEstimatedTime: 0, siteId: 0, startDate: '', jobDueDate: '', jobImageUrl: '', jobRoles: []),
    );

    if (selectedJob.jobId == 0) return;

    final matchingSite = _sites.firstWhere(
      (site) => site.siteId == selectedJob.siteId,
      orElse: () => Site(siteId: 0, siteName: ''),
    );

    final String start = _starttimecontroller.text.split(':').take(2).join(':');
    final String end = _endtimecontroller.text.split(':').take(2).join(':');

    // Format: "Job Name - Date 07:00-15:00 (Location)"
    String formattedDate = "";
    try {
      if (_selectedDates.isNotEmpty) {
        formattedDate = DateFormat('MMM dd').format(_selectedDates.first);
      }
    } catch (e) {}

    String newTitle = "${selectedJob.title}";
    if (formattedDate.isNotEmpty) newTitle += " - $formattedDate";
    if (start.isNotEmpty && end.isNotEmpty) newTitle += " $start-$end";
    if (matchingSite.siteName.isNotEmpty) newTitle += " (${matchingSite.siteName})";

    setState(() {
      _titleController.text = newTitle;
    });
  }

  // --- Fetch Methods ---
  Future<void> fetchAllShifts() async {
    allShifts = await ShiftService().fetchAllShifts();
  }

  Future<void> fetchAllLeaves() async {
    allLeaves = await LeaveService().fetchLeaveRequests();
  }

  Future<void> fetchSites() async {
    final sites = await SiteService().fetchAllSites();
    if (mounted) setState(() => _sites = sites);
  }

  Future<void> fetchEmployee() async {
    final employees = await EmployeeService().fetchAllEmployees();
    final nameMap = await EmployeeService().fetchEmployeeNameMap();
    if (mounted) {
      setState(() {
        allEmployees = employees;
        employeeNameMap = nameMap;
      });
    }
  }

  Future<void> fetchJobs() async {
    final jobs = await JobService().fetchAllJobs();
    if (mounted) setState(() => allJobs = jobs);
  }

  // --- Helper: Format Employee Names ---
  String getEmployeeNames(List<int> employeeIds) {
    List<String> names =
        employeeIds.map((id) => employeeNameMap[id] ?? 'Unknown').toList();
    if (names.isEmpty) return "";
    if (names.length <= 2) return names.join(", ");
    return "${names.take(2).join(", ")} +${names.length - 2} more";
  }

  // --- Date & Time Pickers ---
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: datePickerThemeBuilder);
    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
      _updateAutoShiftName();
    }
  }

  Future<void> _selectTime(
      BuildContext context, TextEditingController controller) async {
    // Parse current text to set initial time in picker
    TimeOfDay initialTime = TimeOfDay.now();
    try {
      if (controller.text.isNotEmpty) {
        final parts = controller.text.split(':');
        initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } catch (e) {}

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      builder: datePickerThemeBuilder,
      initialTime: initialTime,
    );

    if (picked != null) {
      final now = DateTime.now();
      final dt =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      setState(() {
        controller.text = DateFormat('HH:mm:ss').format(dt);
      });
      _updateAutoShiftName();
    }
  }

  // --- Conflict Detection Logic ---
  bool isOverlapping(String start1, String end1, String start2, String end2) {
    try {
      final fmt = DateFormat('HH:mm:ss');
      final s1 = fmt.parse(start1);
      final e1 = fmt.parse(end1);
      final s2 = fmt.parse(start2);
      final e2 = fmt.parse(end2);
      return s1.isBefore(e2) && s2.isBefore(e1);
    } catch (e) {
      return false;
    }
  }

  bool isOnLeave(int employeeId, String shiftDateStr) {
    if (shiftDateStr.isEmpty) return false;
    try {
      final shiftDate = DateFormat('yyyy-MM-dd').parse(shiftDateStr);
      for (final leave in allLeaves) {
        if (leave.employeeId == employeeId &&
            leave.status.toLowerCase() == 'approved' &&
            !shiftDate.isBefore(leave.startDate) &&
            !shiftDate.isAfter(leave.endDate)) {
          return true;
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  bool hasConflict(int employeeId, String selectedDate, String selectedStart,
      String selectedEnd) {
    if (selectedDate.isEmpty || selectedStart.isEmpty || selectedEnd.isEmpty) {
      return false;
    }

    for (final shift in allShifts) {
      if (widget.shift != null && shift.shiftId == widget.shift!.shiftId) {
        continue;
      }

      final shiftDate = DateFormat('yyyy-MM-dd').format(shift.date);
      if (shiftDate == selectedDate &&
          shift.assignedEmployeeIds.contains(employeeId)) {
        if (isOverlapping(
            shift.startTime, shift.endTime, selectedStart, selectedEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  // --- 2. Submit Logic ---
  Future<void> _submitShift() async {
    // Basic Validations
    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a job first")));
      return;
    }

    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select at least one date")));
      return;
    }

    if (_isSubmitting) return; // Prevent double taps

    setState(() => _isSubmitting = true);

    final start = _starttimecontroller.text.trim();
    final end = _endtimecontroller.text.trim();

    // Check Leaves & Overlaps for ALL selected dates
    for (final date in _selectedDates) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Check Leaves
      final onLeaveEmployees = _selectedEmptIds
          .where((id) => isOnLeave(id, dateStr))
          .toList();

      if (onLeaveEmployees.isNotEmpty) {
        final names = onLeaveEmployees
            .map((id) => employeeNameMap[id] ?? 'Unknown')
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$names are on approved leave on $dateStr.")));
        setState(() => _isSubmitting = false);
        return;
      }

      // Check Shift Overlaps
      final conflictingAssignments = <int, int>{};
      for (final empId in _selectedEmptIds) {
        for (final shift in allShifts) {
          if (widget.shift != null && shift.shiftId == widget.shift!.shiftId) {
            continue;
          }

          if (DateFormat('yyyy-MM-dd').format(shift.date) == dateStr &&
              shift.assignedEmployeeIds.contains(empId)) {
            if (isOverlapping(shift.startTime, shift.endTime, start, end)) {
              conflictingAssignments[empId] = shift.shiftId;
            }
          }
        }
      }

      if (conflictingAssignments.isNotEmpty) {
        final employeeNames = conflictingAssignments.keys
            .map((id) => employeeNameMap[id] ?? 'Unknown')
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Overlapping shifts for: $employeeNames on $dateStr")));
        setState(() => _isSubmitting = false);
        return;
      }
    }

    // Prepare Base Data
    final selectedJob = allJobs.firstWhere(
      (job) => job.jobId == _selectedJobId,
      orElse: () => Job(
          jobId: 0,
          title: '',
          description: '',
          status: '',
          projectId: 0,
          totalEstimatedTime: 0,
          siteId: 0,
          startDate: '',
          jobDueDate: '',
          jobImageUrl: '',
          jobRoles: []),
    );

    final matchingSite = _sites.firstWhere(
      (site) => site.siteId == selectedJob.siteId,
      orElse: () => Site(siteId: 0, siteName: 'Unknown'),
    );

    int successCount = 0;
    bool anyFailure = false;

    // API Call: Create a separate shift for each date
    for (final date in _selectedDates) {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final String taskNameForThisDate = _selectedDates.length > 1 
          ? "${selectedJob.title} - ${DateFormat('MMM dd').format(date)} ${start.split(':').take(2).join(':')}-${end.split(':').take(2).join(':')} (${matchingSite.siteName})"
          : _titleController.text.trim();

      final Map<String, dynamic> shiftData = {
        // --- PascalCase (Core) ---
        "ProjectId": selectedJob.projectId,
        "JobId": _selectedJobId,
        "SiteId": selectedJob.siteId,
        "TaskName": taskNameForThisDate,
        "Date": "${dateStr}T00:00:00.000",
        "StartTime": "${dateStr}T$start",
        "EndTime": "${dateStr}T$end",
        "Location": matchingSite.siteName,
        "Status": (widget.shift != null && _selectedDates.length == 1)
            ? widget.shift!.status
            : "Scheduled",
        "AssignedEmployeeIds": _selectedEmptIds,

        // --- camelCase ---
        "projectId": selectedJob.projectId,
        "jobId": _selectedJobId,
        "siteId": selectedJob.siteId,
        "taskName": taskNameForThisDate,
        "date": "${dateStr}T00:00:00.000",
        "startTime": "${dateStr}T$start",
        "endTime": "${dateStr}T$end",
        "assignedEmployeeIds": _selectedEmptIds,

        // --- Typo Fallbacks from Model ---
        "Projectld": selectedJob.projectId,
        "Jobld": _selectedJobId,
        "AssignedEmployeelds": _selectedEmptIds,
        "Shitid": 0,

        // --- Date Fix Keys (Suggested by user/screenshot) ---
        "StartDate": "${dateStr}T00:00:00",
        "JobDueDate": "${dateStr}T00:00:00",
        "startDate": "${dateStr}T00:00:00",
        "jobDueDate": "${dateStr}T00:00:00",
      };

      // Only include for updates
      if (widget.shift != null && _selectedDates.length == 1 && widget.shift!.employeeResponses.isNotEmpty) {
        final responses = widget.shift!.employeeResponses
            .where((r) => _selectedEmptIds.contains(r.employeeId))
            .map((e) => e.toJson())
            .toList();
        shiftData["EmployeeResponses"] = responses;
        shiftData["EmployeResponses"] = responses; // Typo
      }

      // Log the refined payload for final verification
      debugPrint("📤 Submitting Shotgun payload for $dateStr: ${jsonEncode(shiftData)}");

      try {
        bool success = false;
        if (widget.shift != null && _selectedDates.length == 1) {
          success = await ShiftService().updateShift(widget.shift!.shiftId, shiftData);
        } else {
          // For new shifts, ensure ShiftId 0 doesn't cause issues (backend usually ignores it on create)
          success = await ShiftService().addShift(shiftData);
        }

        if (success) {
          successCount++;
          // Send Notifications
          for (var empId in _selectedEmptIds) {
            await _notificationService.sendShiftNotification(
                empId, "New shift assigned: $dateStr at $start");
          }
        } else {
          anyFailure = true;
          debugPrint("❌ Backend returned failure for shift creation on $dateStr");
        }
      } catch (e) {
        debugPrint("🔥 Exception submitting shift for $dateStr: $e");
        anyFailure = true;
      }
    }

    if (successCount > 0) {
      if (mounted) {
        SuccessDialog.show(
          context,
          title: widget.shift != null && _selectedDates.length == 1 ? "Shift Updated" : "Shifts Created",
          message: widget.shift != null && _selectedDates.length == 1
              ? "The shift details have been updated successfully."
              : "$successCount shifts have been created successfully.${anyFailure ? ' (Some failed)' : ''}",
          buttonText: "OK",
          onPressed: () {
            Navigator.pop(context); // Close dialog
            Navigator.pop(context, true); // Return to list screen
          },
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Operation Failed")));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          drawer: const Sidenav(),
          backgroundColor: Colors.transparent,
          appBar: const Uppernavbar(showBackButton: true),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Gradienthorizontal(
              width: double.infinity,
              height: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        widget.shift != null ? "EDIT SHIFT" : "CREATE SHIFT",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDropdownJob(),
                    const SizedBox(height: 16),
                    _buildTextField("Shift Name", _titleController),
                    const SizedBox(height: 16),
                    _buildMultiDateSelector(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTime("Start Time", _starttimecontroller)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTime("End Time", _endtimecontroller)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMultiEmployeeSelector(),
                    const SizedBox(height: 32),

                    // --- Action Buttons ---
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: GradientButton(
                            text: widget.shift != null ? "Update" : "Create",
                            onPressed: _isSubmitting ? () {} : _submitShift,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Text Field (Upgraded) ---
  Widget _buildTextField(String label, TextEditingController controller,
      {bool isReadOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            children: const [
              TextSpan(text: " *", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isReadOnly
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            enabled: !isReadOnly,
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: InputBorder.none),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Multi-Date Selector (Upgraded) ---
  Widget _buildMultiDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            text: "Select Dates",
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: " *", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedDates.isEmpty)
                const Text("No dates selected",
                    style: TextStyle(color: Colors.white54, fontSize: 14))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedDates.map((date) {
                    return Chip(
                      label: Text(DateFormat('MMM dd, yyyy').format(date)),
                      labelStyle: const TextStyle(
                          color: Color(0xFF34C8E8),
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                      backgroundColor: const Color(0xFF1E2433),
                      deleteIcon: const Icon(Icons.cancel, size: 18, color: Color(0xFF34C8E8)),
                      onDeleted: () {
                        setState(() {
                          _selectedDates.remove(date);
                        });
                        _updateAutoShiftName();
                      },
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Color(0xFF34C8E8), width: 1.5)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openMultiDatePicker(context),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text("Add/Change Dates"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openMultiDatePicker(BuildContext context) async {
    DateTime? tempDate = DateTime.now();
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A3243),
              title: const Text("Select Shift Dates", style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 320,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Show Current Selection ---
                    if (_selectedDates.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text("Selected Dates:",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 45,
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _selectedDates.map((date) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Chip(
                                  label: Text(DateFormat('MMM dd').format(date)),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF34C8E8), fontSize: 11, fontWeight: FontWeight.bold),
                                  backgroundColor: const Color(0xFF1E2433),
                                  onDeleted: () {
                                    setDialogState(() {
                                      _selectedDates.remove(date);
                                    });
                                    setState(() {});
                                    _updateAutoShiftName();
                                  },
                                  deleteIcon: const Icon(Icons.close,
                                      size: 14, color: Color(0xFF34C8E8)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(color: Color(0xFF34C8E8), width: 1)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const Divider(color: Colors.white12),
                    ],
                    Expanded(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF34C8E8),
                            onPrimary: Colors.white,
                            surface: Color(0xFF2A3243),
                            onSurface: Colors.white,
                          ),
                          dialogBackgroundColor: const Color(0xFF2A3243),
                        ),
                        child: CalendarDatePicker(
                          initialDate: tempDate ?? DateTime.now(),
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 2)),
                          onDateChanged: (date) {
                            setDialogState(() {
                              tempDate = date;
                              if (_selectedDates.any((d) =>
                                  d.year == date.year &&
                                  d.month == date.month &&
                                  d.day == date.day)) {
                                _selectedDates.removeWhere((d) =>
                                    d.year == date.year &&
                                    d.month == date.month &&
                                    d.day == date.day);
                              } else {
                                _selectedDates.add(date);
                                _selectedDates.sort();
                              }
                            });
                            setState(() {}); // Update the background chips
                            _updateAutoShiftName();
                          },
                        ),
                      ),
                    ),
                    const Text("Tap dates to select/deselect",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("DONE", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- UI Helper: Time Picker (Upgraded) ---
  Widget _buildTime(String label, TextEditingController timeController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            children: const [
              TextSpan(text: " *", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _selectTime(context, timeController),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    timeController.text.isEmpty ? "Select Time" : timeController.text,
                    style: TextStyle(
                        color: timeController.text.isEmpty ? Colors.white54 : Colors.white,
                        fontSize: 14),
                  ),
                ),
                const Icon(Icons.access_time_rounded,
                    color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Job Dropdown (Upgraded) ---
  Widget _buildDropdownJob() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            text: "Select a Job",
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: " *", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              dropdownColor: const Color(0xFF2A3243),
              value: allJobs.any((job) => job.jobId == _selectedJobId)
                  ? _selectedJobId
                  : null,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
              items: allJobs
                  .map((job) => DropdownMenuItem<int>(
                      value: job.jobId,
                      child: Text(job.title,
                          style: const TextStyle(color: Colors.white, fontSize: 14))))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedJobId = value);
                _updateAutoShiftName();
              },
              hint: const Text("Choose a Job",
                  style: TextStyle(color: Colors.white54, fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }

  // --- UI Helper: Employee Selector Modal (Upgraded) ---
  Widget _buildMultiEmployeeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            text: "Select Employees",
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            children: [
              TextSpan(text: " *", style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            if (allShifts.isEmpty) await fetchAllShifts();

            showModalBottomSheet(
              context: context,
              backgroundColor: const Color(0xFF2A3243),
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20))),
              builder: (context) {
                String searchQuery = '';
                return StatefulBuilder(
                  builder: (context, setModalState) {
                    final filteredEmployees = allEmployees.where((e) {
                      final fullName = (employeeNameMap[e.employeeId] ?? e.firstName).toLowerCase();
                      return fullName.contains(searchQuery.toLowerCase());
                    }).toList();

                    return Container(
                      height: MediaQuery.of(context).size.height * 0.75,
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const Text("Select Employees",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              onChanged: (value) => setModalState(() => searchQuery = value),
                              decoration: InputDecoration(
                                hintText: "Search employees...",
                                hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.08),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none),
                              ),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: filteredEmployees.length,
                              separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                              itemBuilder: (context, index) {
                                final employee = filteredEmployees[index];
                                final isSelected = _selectedEmptIds.contains(employee.employeeId);
                                final fullName = employeeNameMap[employee.employeeId] ?? employee.firstName;
                                final hasCon = hasConflict(employee.employeeId, _dateController.text, _starttimecontroller.text, _endtimecontroller.text);
                                final onL = isOnLeave(employee.employeeId, _dateController.text);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected ? Colors.blueAccent : Colors.white10,
                                    child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                                  subtitle: (hasCon || onL)
                                      ? Text(hasCon ? "⚠️ Scheduling Conflict" : "🏖️ On Approved Leave",
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 12))
                                      : Text(employee.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Colors.blueAccent)
                                      : (hasCon || onL ? const Icon(Icons.info_outline, color: Colors.redAccent, size: 20) : const Icon(Icons.add_circle_outline, color: Colors.white24)),
                                  onTap: (hasCon || onL) ? null : () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedEmptIds.remove(employee.employeeId);
                                      } else {
                                        _selectedEmptIds.add(employee.employeeId);
                                      }
                                    });
                                    setModalState(() {});
                                  },
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text("Done (${_selectedEmptIds.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_add_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        _selectedEmptIds.isEmpty
                            ? "Search and select employees"
                            : getEmployeeNames(_selectedEmptIds),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: _selectedEmptIds.isEmpty
                                ? Colors.white54
                                : Colors.white,
                            fontSize: 14))),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
