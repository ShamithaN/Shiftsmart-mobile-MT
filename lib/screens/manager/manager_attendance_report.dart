import 'package:flutter/material.dart';
import 'package:shiftsmart/models/attendance.dart';
import 'package:shiftsmart/screens/manager/manager_attendace_view.dart';
import 'package:shiftsmart/services/attendance_report_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/search.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Managerattendancereport extends StatefulWidget {
  const Managerattendancereport({super.key});

  // [x] Research existing Attendance Details implementation <!-- id: 0 -->
  // [x] Verify backend support for clock-in/out images and early exit data <!-- id: 1 -->
  // [/] Update Attendance Details UI to show images <!-- id: 2 -->
  // [/] Update Attendance Details UI to show early exit status <!-- id: 3 -->
  // [ ] Verify changes <!-- id: 4 -->
  @override
  State<Managerattendancereport> createState() =>
      _ManagerattendancereportState();
}

class _ManagerattendancereportState extends State<Managerattendancereport> {
  // State Variables
  List<Attendance> _allAttendances = [];
  List<Attendance> _filteredAttendances = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    _fetchData();
  }

  // Fetch attendance data from the backend
  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final attendances = await AttendanceReportService().fetchAttendanceData();
      if (mounted) {
        setState(() {
          _allAttendances = attendances;
          _filteredAttendances =
              List.from(attendances); // Initialize filter list
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load attendance reports.')),
        );
      }
    }
  }

  // Filter the list based on search text (Employee Name or Shift Name)
  void _onQueryChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAttendances = List.from(_allAttendances);
      } else {
        _filteredAttendances = _allAttendances.where((item) {
          final employee = item.employeeName.toLowerCase();
          final shift = item.shiftName.toLowerCase();
          final search = query.toLowerCase();
          return employee.contains(search) || shift.contains(search);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF1C2230),
      appBar: const Uppernavbar(
        showBackButton: true,
      ),
      drawer: const Sidenav(),
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 15),

                        // Search Bar
                        Search(onQueryChanged: _onQueryChanged),

                        const SizedBox(height: 20),
                        const Text(
                          "Attendance Reports",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // List of Reports
                        Expanded(child: _attendanceList()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display the list of attendance items
  Widget _attendanceList() {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF724584)));
    }

    if (_filteredAttendances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_late_outlined,
                color: Colors.white38, size: 40),
            const SizedBox(height: 10),
            Text(
              "No attendance records found.",
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    // Show newest first (assuming the list is chronological, reversing makes it newest-first)
    final displayList = _filteredAttendances.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final attendance = displayList[index];
        return _buildAttendanceCard(attendance);
      },
    );
  }

  Widget _buildAttendanceCard(Attendance attendance) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF363E51), Color(0xFF191E26)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.blueAccent),
        ),
        title: Text(
          attendance.employeeName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              attendance.shiftName,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (attendance.isEmergency) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  " EARLY CLOCK-OUT",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: SizedBox(
          width: 140,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (attendance.clockInPhotoUrl.isNotEmpty)
                _buildThumbnail(attendance.clockInPhotoUrl),
              const SizedBox(width: 4),
              if (attendance.clockOutPhotoUrl.isNotEmpty)
                _buildThumbnail(attendance.clockOutPhotoUrl),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chevron_right,
                    color: Colors.white70, size: 20),
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Managerattendaceview(
                attendance: attendance,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(String url) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 15, color: Colors.white24),
        ),
      ),
    );
  }
}
