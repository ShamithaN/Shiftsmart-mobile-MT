import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shiftsmart/models/employee.dart';
import 'package:shiftsmart/models/leave_request.dart';
import 'package:shiftsmart/models/shift.dart';
import 'package:shiftsmart/screens/manager/manager_shifts_view.dart';
import 'package:shiftsmart/services/leave_service.dart';
import 'package:shiftsmart/services/project_service.dart';
import 'package:shiftsmart/services/employee_service.dart';
import 'package:shiftsmart/services/shift_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/circleindicator.dart';
import 'package:shiftsmart/widgets/gradientbox.dart';
import 'package:shiftsmart/widgets/gradienthorizontal.dart';
import 'package:shiftsmart/models/project.dart';
import 'package:shiftsmart/services/attendance_service.dart';
import 'package:shiftsmart/screens/manager/manager_pending_requests.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/user_provider.dart';
import 'package:shiftsmart/services/super_admin_service.dart';
import 'package:shiftsmart/services/auth_service.dart';
import 'dart:ui';

class Managerdashboard extends StatefulWidget {
  const Managerdashboard({super.key});

  @override
  State<Managerdashboard> createState() => _ManagerdashboardState();
}

class _ManagerdashboardState extends State<Managerdashboard> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  int completed = 0;
  int total = 0;
  int inProgress = 0;
  List<Project> allProjects = [];
  List<String> filteredEmployees = [];
  List<LeaveRequest> _leaveRequests = [];
  bool _isLoading = true;
  List<Employee> _allEmployees = [];
  List<Shift> _todayShifts = [];
  int _pendingCount = 0;

  String _selectedOrganization = 'codebase Ltd';
  List<Map<String, dynamic>> _tenants = [];
  final List<String> _organizations = ['Vel Ltd', 'codebase Ltd', 'SK Ltd', 'CodegenX Ltd'];

  final SuperAdminService _superAdminService = SuperAdminService();

  final ProjectService _projectService = ProjectService();
  final LeaveService _leaveService = LeaveService();
  final EmployeeService _employeeService = EmployeeService();
  final ShiftService _shiftService = ShiftService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    enableFullScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshKey.currentState?.show();
      _initializeDashboard();
    });
  }

  Future<void> _initializeDashboard() async {
    setState(() => _isLoading = true);
    
    // 1. Fetch current tenant info from token/profile
    try {
      final userInfo = await _authService.getCurrentUserInfo();
      if (userInfo != null) {
        final currentTenant = userInfo['tenantName'] ?? userInfo['TenantName'];
        if (currentTenant != null) {
          setState(() {
            _selectedOrganization = currentTenant.toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching current user info: $e");
    }

    // 2. Fetch all available tenants for the dropdown
    await _fetchTenants();
    
    // 3. Refresh all dashboard data
    await _refreshData();
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await fetchProjects();
    await _fetchLeaveRequests();
    await _fetchAllEmployees();
    await _fetchAllShifts();
    
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAllEmployees() async {
    try {
      final employees = await _employeeService.fetchAllEmployees();
      setState(() {
        _allEmployees = employees;
      });
    } catch (e) {
      print("Error fetching employees: $e");
    }
  }

  Future<void> _fetchLeaveRequests() async {
    try {
      final requests = await _leaveService.fetchLeaveRequests();
      setState(() {
        _leaveRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching leave requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchProjects() async {
    final projects = await _projectService.fetchAllProjects();
    if (!mounted) return;
    setState(() {
      // Filter projects by selected organization name to show ONLY relevant details
      allProjects = projects.where((p) => 
        p.companyName.toLowerCase() == _selectedOrganization.toLowerCase()
      ).toList();
      
      total = allProjects.length;
      completed = getCompletedProjectsCount();
      inProgress = getInProgressProjectsCount();
    });
  }

  Future<void> _fetchAllShifts() async {
    try {
      final allRawShifts = await _shiftService.fetchAllRawShifts();
      
      // Filter shifts to only include those belonging to the selected organization's projects
      final projectIds = allProjects.map((p) => p.projectId).toSet();
      final filteredRawShifts = allRawShifts.where((s) {
        final pid = s['ProjectId'] ?? s['projectId'];
        return projectIds.contains(pid);
      }).toList();

      final today = DateTime.now();
      final todayOnly = filteredRawShifts
          .map((shiftData) => Shift.fromJson(shiftData))
          .where((shift) =>
              shift.date.year == today.year &&
              shift.date.month == today.month &&
              shift.date.day == today.day)
          .toList();

      int pending = 0;
      for (var s in filteredRawShifts) {
        final shift = Shift.fromJson(s);
        for (var resp in shift.employeeResponses) {
          if (resp.approvalStatus == "Pending") {
            pending++;
          }
        }
      }

      setState(() {
        _todayShifts = todayOnly;
        _pendingCount = pending;
        debugPrint("Today shifts: $_todayShifts, Pending count: $_pendingCount");
      });
    } catch (e) {
      debugPrint("Error fetching today's shifts: $e");
    }
  }

  Future<void> _fetchTenants() async {
    try {
      final tenants = await _superAdminService.getAllTenants();
      if (tenants.isNotEmpty) {
        setState(() {
          _tenants = tenants.map((t) => t as Map<String, dynamic>).toList();
          
          // Synchronize _selectedOrganization with the fetched list
          final tenantNames = _tenants.map((t) => (t['name'] ?? t['Name'] ?? '').toString().toLowerCase()).toList();
          if (!tenantNames.contains(_selectedOrganization.toLowerCase())) {
            // Fallback to the first tenant if current selection is not in the list
            _selectedOrganization = (_tenants[0]['name'] ?? _tenants[0]['Name'] ?? 'Unnamed').toString();
          } else {
            // Ensure exact casing from the list
            final foundOrg = _tenants.firstWhere(
              (t) => (t['name'] ?? t['Name'] ?? '').toString().toLowerCase() == _selectedOrganization.toLowerCase()
            );
            _selectedOrganization = (foundOrg['name'] ?? foundOrg['Name']).toString();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching tenants: $e");
    }
  }

  Future<void> _handleTenantSwitch(String? orgName) async {
    if (orgName == null) return;

    final tenant = _tenants.firstWhere(
      (t) => (t['name'] ?? t['Name'] ?? '').toString().toLowerCase() == orgName.toLowerCase(),
      orElse: () => {},
    );

    // Expand ID lookup for reliability
    final tenantId = tenant['tenantId'] ?? tenant['TenantId'] ?? tenant['id'] ?? tenant['ID'];

    // Update UI name immediately so the dropdown shows the change
    setState(() {
      _selectedOrganization = orgName;
    });

    if (tenantId == null) {
      debugPrint("Warning: No tenantId found for $orgName. Proceeding with client-side filter only.");
      await _refreshData(); // Still refresh data to trigger client-side filtering
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _superAdminService.switchTenant(tenantId);
      
      if (result != null) {
        await _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to $orgName'), backgroundColor: Colors.green),
          );
        }
      } else {
        // Even if API switch fails, we already updated name so client-side filter works
        await _refreshData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Switched to $orgName (Offline Mode)'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint("Error switching tenant: $e");
      await _refreshData();
    }
    setState(() => _isLoading = false);
  }

  int getCompletedProjectsCount() {
    return allProjects.where((project) => project.status == 'Completed').length;
  }

  int getInProgressProjectsCount() {
    return allProjects.where((project) => project.status == 'Active').length;
  }

  Employee? getEmployeeById(int id) {
    return _allEmployees.firstWhere(
      (emp) => emp.employeeId == id,
      orElse: () => Employee(
          employeeId: id,
          firstName: 'Unknown',
          profilePicture: '',
          nextOfKins: []),
    );
  }

  String formatTime(String timeString) {
    try {
      final parsedTime = DateFormat("HH:mm:ss").parse(timeString);
      return DateFormat("HH:mm").format(parsedTime);
    } catch (e) {
      return timeString; 
    }
  }

  List<LeaveRequest> getTodayLeaveRequests() {
    final today = DateTime.now();
    return _leaveRequests.where((req) {
      final isToday =
          !today.isBefore(req.startDate) && !today.isAfter(req.endDate);
      final isApproved = req.status.toLowerCase() == 'approved';
      return isApproved && isToday;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        const Positioned.fill(child: Background()),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF724584)),
                )
              : Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    return Column(
                      children: [
                        // Organization Selection Bar
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF262A34),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: Colors.white24, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedOrganization,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
                                dropdownColor: const Color(0xFF1C2230),
                                isExpanded: true,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: 'HEADER',
                                    enabled: false,
                                    child: Text(
                                      'ACTIVE ORGANIZATION',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  ...(_tenants.isNotEmpty 
                                      ? _tenants.map((t) => (t['name'] ?? t['Name'] ?? 'Unnamed').toString()).toList()
                                      : _organizations).map((String org) {
                                        return DropdownMenuItem<String>(
                                          value: org,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.business, 
                                                color: _selectedOrganization == org ? Colors.blueAccent : Colors.white70, 
                                                size: 20
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  org,
                                                  style: TextStyle(
                                                    color: _selectedOrganization == org ? Colors.blueAccent : Colors.white,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              if (_selectedOrganization == org)
                                                const Icon(Icons.check, color: Colors.blueAccent, size: 20),
                                            ],
                                          ),
                                        );
                                      }),
                                ],
                                onChanged: (String? newValue) {
                                  if (newValue != null && newValue != 'HEADER') {
                                    _handleTenantSwitch(newValue);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                        key: _refreshKey,
                        onRefresh: _refreshData,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenHeight * 0.02,
                            ),
                            child: Column(
                              children: [
                                Gradientbox(
                                  width: double.infinity,
                                  height: screenHeight * 0.35,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.03,
                                      vertical: screenHeight * 0.015,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "PROJECT OVERVIEW",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            Row(
                                              children: [
                                                const SizedBox(width: 50),
                                                Column(
                                                  children: [
                                                    const Text(
                                                      "In Progress",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Circleindicator(
                                                      value: total > 0
                                                          ? inProgress / total
                                                          : 0,
                                                      total: total,
                                                      count: inProgress,
                                                      label: "In Progress",
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 30),
                                                Column(
                                                  children: [
                                                    const Text(
                                                      "Completed",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Circleindicator(
                                                      value: total > 0
                                                          ? completed / total
                                                          : 0,
                                                      total: total,
                                                      count: completed,
                                                      label: "Completed",
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          ],
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                Gradienthorizontal(
                                  width: double.infinity,
                                  height: screenHeight * 0.20,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.04,
                                      vertical: screenHeight * 0.015,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Today on Leave",
                                            style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: getTodayLeaveRequests()
                                                      .isNotEmpty
                                                  ? getTodayLeaveRequests()
                                                      .map((leave) {
                                                      final employee =
                                                          getEmployeeById(
                                                              leave.employeeId);
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(right: 12),
                                                        child: Column(
                                                          children: [
                                                            CircleAvatar(
                                                              radius: 30,
                                                              backgroundColor:
                                                                  Colors
                                                                      .grey[800],
                                                              backgroundImage: (employee?.profilePicture !=
                                                                          null &&
                                                                      employee!
                                                                          .profilePicture!
                                                                          .startsWith(
                                                                              'data:image'))
                                                                  ? MemoryImage(
                                                                      base64Decode(employee
                                                                          .profilePicture!
                                                                          .split(
                                                                              ',')
                                                                          .last),
                                                                    )
                                                                  : (employee?.profilePicture !=
                                                                              null &&
                                                                          employee!
                                                                              .profilePicture!
                                                                              .isNotEmpty)
                                                                      ? NetworkImage(
                                                                          employee
                                                                              .profilePicture!)
                                                                      : null,
                                                              child: (employee?.profilePicture ==
                                                                          null ||
                                                                      employee!
                                                                          .profilePicture!
                                                                          .isEmpty)
                                                                  ? const Icon(
                                                                      Icons.person,
                                                                      size: 30,
                                                                      color: Colors
                                                                          .white)
                                                                  : null,
                                                            ),
                                                            const SizedBox(
                                                                height: 6),
                                                            SizedBox(
                                                              width: 70,
                                                              child: Text(
                                                                employee?.firstName ??
                                                                    'Unknown',
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize: 12),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList()
                                                  : [
                                                      const Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                vertical: 12),
                                                        child: Text(
                                                          "No one is on leave today.",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white70),
                                                        ),
                                                      ),
                                                    ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.025),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: screenHeight * 0.18,
                                    maxHeight: screenHeight * 0.45,
                                  ),
                                  child: Gradienthorizontal(
                                    width: double.infinity,
                                    height: double.infinity,
                                    child: Padding(
                                      padding:
                                          EdgeInsets.all(screenWidth * 0.04),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "TODAY'S SHIFTS",
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "${_todayShifts.length} shift(s) scheduled for today",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            height: screenHeight * 0.25,
                                            child: _todayShifts.isEmpty
                                                ? const Center(
                                                    child: Text(
                                                      "No shifts scheduled today.",
                                                      style: TextStyle(
                                                          color:
                                                              Colors.white70),
                                                    ),
                                                  )
                                                : ListView.builder(
                                                    physics:
                                                        const BouncingScrollPhysics(),
                                                    itemCount:
                                                        _todayShifts.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      final shift =
                                                          _todayShifts[index];
                                                      return Padding(
                                                          padding: EdgeInsets.symmetric(
                                                              vertical:
                                                                  screenHeight *
                                                                      0.008),
                                                          child: InkWell(
                                                            onTap: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder: (context) =>
                                                                      ManagerShiftsView(
                                                                          shift:
                                                                              shift),
                                                                ),
                                                              );
                                                            },
                                                            child: Container(
                                                              padding: EdgeInsets.all(
                                                                  screenWidth *
                                                                      0.03),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white.withOpacity(0.08),
                                                                  borderRadius: BorderRadius.circular(15),
                                                                  border: Border.all(
                                                                    color: Colors.white.withOpacity(0.1),
                                                                    width: 1,
                                                                  ),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: Colors.black.withOpacity(0.1),
                                                                      blurRadius: 10,
                                                                      offset: const Offset(0, 4),
                                                                    ),
                                                                  ],
                                                                ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .spaceBetween,
                                                                    children: [
                                                                      Expanded(
                                                                        child: Text(
                                                                          shift
                                                                              .taskName,
                                                                          style:
                                                                              const TextStyle(
                                                                            fontSize:
                                                                                16,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color:
                                                                                Colors.white,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        shift.status,
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          color: shift.status.trim().toLowerCase() ==
                                                                                  'active'
                                                                              ? Colors.greenAccent
                                                                              : (shift.status.trim().toLowerCase() == 'scheduled' || shift.status.trim().toLowerCase() == 'pending')
                                                                                  ? Colors.yellowAccent
                                                                                  : Colors.white70,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            10,
                                                                      ),
                                                                      const Icon(
                                                                        Icons
                                                                            .arrow_forward_ios,
                                                                        color: Colors
                                                                            .white70,
                                                                        size: 14,
                                                                      )
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                      height: 6),
                                                                  Text(
                                                                    "${formatTime(shift.startTime)} - ${formatTime(shift.endTime)}",
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize: 13,
                                                                      color: Colors
                                                                          .white70,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height: 12),
                                                                  Text(
                                                                    "Assigned employees: ",
                                                                    style:
                                                                        const TextStyle(
                                                                      fontSize: 15,
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height: 12),
                                                                  Column(
                                                                    children: shift
                                                                        .employeeResponses
                                                                        .map((response) {
                                                                      final employee =
                                                                          getEmployeeById(response.employeeId);
                                                                      final isPendingApproval =
                                                                          response.approvalStatus ==
                                                                              "Pending";

                                                                      return Container(
                                                                        margin: const EdgeInsets
                                                                            .only(
                                                                            bottom:
                                                                                12),
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            10),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color: Colors
                                                                              .black26,
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          border: isPendingApproval ? Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)) : null,
                                                                        ),
                                                                        child:
                                                                            Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Row(
                                                                              children: [
                                                                                CircleAvatar(
                                                                                  radius: 18,
                                                                                  backgroundColor: Colors.grey[800],
                                                                                  backgroundImage: (employee?.profilePicture != null && employee!.profilePicture!.startsWith('data:image'))
                                                                                      ? MemoryImage(base64Decode(employee.profilePicture!.split(',').last))
                                                                                      : (employee?.profilePicture != null && employee!.profilePicture!.isNotEmpty)
                                                                                          ? NetworkImage(employee.profilePicture!)
                                                                                          : null,
                                                                                  child: (employee?.profilePicture == null || employee!.profilePicture!.isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
                                                                                ),
                                                                                const SizedBox(width: 10),
                                                                                Expanded(
                                                                                  child: Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: [
                                                                                      Text(
                                                                                        employee?.firstName ?? 'Unknown',
                                                                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                                                      ),
                                                                                      Text(
                                                                                        response.status,
                                                                                        style: TextStyle(
                                                                                          color: _getStatusColor(response.status),
                                                                                          fontSize: 11,
                                                                                          fontWeight: FontWeight.w600,
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                                if (isPendingApproval)
                                                                                  ElevatedButton(
                                                                                    style: ElevatedButton.styleFrom(
                                                                                      backgroundColor: Colors.green,
                                                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                                                                      minimumSize: const Size(60, 30),
                                                                                    ),
                                                                                    onPressed: () => _handleApproval(response.employeeId, shift.shiftId, "Approved"),
                                                                                    child: const Text("Approve", style: TextStyle(fontSize: 12, color: Colors.white)),
                                                                                  ),
                                                                              ],
                                                                            ),
                                                                            if (response.clockInTime != null)
                                                                              Padding(
                                                                                padding: const EdgeInsets.only(top: 8, left: 4),
                                                                                child: Text(
                                                                                  "Clock In: ${DateFormat('hh:mm a').format(response.clockInTime!.toLocal())}",
                                                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                                                ),
                                                                              ),
                                                                            if (response.clockOutTime != null)
                                                                              Padding(
                                                                                padding: const EdgeInsets.only(top: 2, left: 4),
                                                                                child: Text(
                                                                                  "Clock Out: ${DateFormat('hh:mm a').format(response.clockOutTime!.toLocal())}",
                                                                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                                                ),
                                                                              ),
                                                                            if (response.isEarlyExit)
                                                                              Padding(
                                                                                padding: const EdgeInsets.only(top: 4, left: 4),
                                                                                child: Row(
                                                                                  children: [
                                                                                    const Icon(Icons.warning, color: Colors.orange, size: 14),
                                                                                    const SizedBox(width: 4),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        "Reason: ${response.earlyExitReason ?? 'Emergency'}",
                                                                                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                          ],
                                                                        ),
                                                                      );
                                                                    }).toList(),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ));
                                                    },
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )))
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'clockedin':
        return Colors.green;
      case 'clockedout':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'pending':
        return Colors.orange;
      case 'declined':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.white54;
    }
  }

  Future<void> _handleApproval(int employeeId, int shiftId, String status) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Processing approval for shift $shiftId...")),
    );
    
    final attendanceService = AttendanceService();
    try {
      final record = await attendanceService.getShiftsByShiftId(employeeId, shiftId: shiftId);
      if (record != null && record['AttendanceId'] != null) {
        final success = await attendanceService.approveAttendance(record['AttendanceId'], status);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Attendance Approved successfully!")),
          );
          _refreshData();
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to approve attendance.")),
          );
        }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Attendance record not found.")),
        );
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }
}
