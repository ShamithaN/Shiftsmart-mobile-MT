import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/tenant_provider.dart';
import 'package:shiftsmart/models/job.dart';
import 'package:shiftsmart/models/shift.dart';
import 'package:shiftsmart/screens/manager/manager_create_job.dart';
import 'package:shiftsmart/screens/manager/manager_create_shift.dart';
import 'package:shiftsmart/screens/manager/manager_job_view.dart';
import 'package:shiftsmart/screens/manager/manager_shifts_view.dart';
import 'package:shiftsmart/services/job_service.dart';
import 'package:shiftsmart/services/shift_service.dart';
import 'package:shiftsmart/services/project_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/premium_feature_gate.dart';
import 'package:shiftsmart/models/project.dart' as model;

class Managerjobs extends StatefulWidget {
  const Managerjobs({super.key});

  @override
  State<Managerjobs> createState() => _ManagerjobsState();
}

class _ManagerjobsState extends State<Managerjobs>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  List<Job> allJobs = [];
  List<Job> filteredJobs = [];

  List<Shift> allShifts = [];
  List<Shift> filteredShifts = [];

  bool _isLoading = true;
  Map<int, model.Project> projectMap = {};
  String _lastTenant = '';
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshKey.currentState?.show();
      _loadData();
    });
  }

  String _formatDate(String dateTimeString) {
    if (dateTimeString.contains('T')) {
      return dateTimeString.split('T')[0];
    }
    return dateTimeString;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _fetchProjects(), // We need projects to filter jobs by tenant
      _fetchShifts(), // Load shifts
    ]);

    await _fetchJobs(); // Needs projects loaded first to filter

    setState(() => _isLoading = false);
  }

  Future<void> _fetchProjects() async {
    try {
      final projects = await ProjectService().fetchAllProjects();
      setState(() {
        projectMap = {for (var p in projects) p.projectId: p};
      });
    } catch (e) {
      debugPrint(" managerJobs: Error loading projects: \$e");
    }
  }

  Future<void> _fetchJobs() async {
    final selectedOrg = context.read<TenantProvider>().selectedOrganization;
    try {
      final jobs = await JobService().fetchAllJobs();
      setState(() {
        allJobs = jobs;
        _lastTenant = selectedOrg;
        _applyFilters();
      });
    } catch (e) {
      debugPrint(" managerJobs: Error loading jobs: \$e");
    }
  }

  Future<void> _fetchShifts() async {
    try {
      final shifts = await ShiftService().fetchAllShifts();
      setState(() {
        allShifts = shifts;
        _applyFilters();
      });
    } catch (e) {
      debugPrint(" managerJobs: Error loading shifts: \$e");
    }
  }

  void _applyFilters() {
    setState(() {
      // Jobs filter (tenant + search)
      List<Job> tempJobs = _lastTenant.isNotEmpty
          ? allJobs.where((j) {
              final proj = projectMap[j.projectId];
              return proj != null &&
                  proj.companyName.toLowerCase() == _lastTenant.toLowerCase();
            }).toList()
          : List.from(allJobs);

      filteredJobs = _searchQuery.isEmpty
          ? tempJobs
          : tempJobs
              .where((j) =>
                  j.title.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

      // Shifts filter (search)
      filteredShifts = _searchQuery.isEmpty
          ? List.from(allShifts)
          : allShifts
              .where((s) =>
                  s.taskName.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
    });
  }

  void onQueryChanged(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<TenantProvider>(
      builder: (context, tp, _) {
        if (tp.selectedOrganization != _lastTenant) {
          _lastTenant = tp.selectedOrganization;
          if (_lastTenant.isNotEmpty && mounted && !_isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
          }
        }

        // ── Premium Feature Gate ──────────────────────────────────────────
        if (!tp.isFeatureEnabled('job_management')) {
          return Stack(
            children: [
              const Positioned.fill(child: Background()),
              Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: PremiumFeatureGate(
                        featureName: 'Job Management',
                        blockedEndpoint: '/api/job/list',
                        customMessage:
                            'Contact your administrator to enable this module for your tenant.',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // ── Normal screen ─────────────────────────────────────────────
        return Scaffold(
          body: Stack(
            children: [
              const Background(),
              SafeArea(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        labelColor: Colors.blueAccent,
                        unselectedLabelColor: Colors.white,
                        indicatorColor: Colors.blueAccent,
                        tabs: [
                          Tab(
                              icon: const Icon(Icons.build),
                              text: "JOB \${filteredJobs.length}"),
                          Tab(
                              icon: const Icon(Icons.access_time),
                              text: "SHIFT \${filteredShifts.length}"),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          onChanged: onQueryChanged,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.white54),
                            filled: true,
                            fillColor: const Color(0xFF2A3243),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Color(0xFF724584)))
                            : RefreshIndicator(
                                key: _refreshKey,
                                onRefresh: _loadData,
                                child: TabBarView(
                                  children: [
                                    _buildJobView(),
                                    _buildShiftView(),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListHeader(
      String title, String countText, String buttonText, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Text(countText,
                      style: const TextStyle(
                          color: Colors.blueAccent, fontSize: 13)),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(buttonText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white24, height: 1),
        ],
      ),
    );
  }

  Widget _buildJobView() {
    return Column(
      children: [
        _buildListHeader(
            "JOB LIST", "Total: \${filteredJobs.length} Jobs", "Add Job",
            () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ManagerCreateJob()));
          if (result == true) _loadData();
        }),
        Expanded(
          child: filteredJobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/cJob.png',
                          height: 30, color: Colors.white54),
                      const SizedBox(height: 16),
                      Text("No jobs found",
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    return InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    ManagerJobView(job: job)));
                        if (result == true) _loadData();
                      },
                      child: _buildJobListItem(job),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShiftView() {
    return Column(
      children: [
        _buildListHeader("SHIFT LIST",
            "Total: \${filteredShifts.length} Shifts", "Add Shift", () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const Managercreateshift()));
          if (result == true) _loadData();
        }),
        Expanded(
          child: filteredShifts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/cShift.png',
                          height: 30, color: Colors.white54),
                      const SizedBox(height: 16),
                      Text("No shifts found",
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredShifts.length,
                  itemBuilder: (context, index) {
                    final shift = filteredShifts[index];
                    return InkWell(
                      onTap: () async {
                        final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    ManagerShiftsView(shift: shift)));
                        if (result == true) _loadData();
                      },
                      child: _buildShiftListItem(shift),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJobListItem(Job job) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Image.asset('assets/cJob.png', height: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                    "Due Date: \${job.jobDueDate.isNotEmpty ? _formatDate(job.jobDueDate) : 'No date'}",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  Widget _buildShiftListItem(Shift shift) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Image.asset('assets/cShift.png', height: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.taskName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 6),
                Text("Date: ${_formatDate(shift.date.toIso8601String())}",
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                    "${shift.startTime} - ${shift.endTime}  |  Status: ${shift.status.toUpperCase()}",
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        ],
      ),
    );
  }
}
