import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/tenant_provider.dart';
import 'package:shiftsmart/screens/manager/manager_comapny.dart';
import 'package:shiftsmart/screens/manager/manager_create_project1.dart';
import 'package:shiftsmart/screens/manager/manager_projectview.dart';
import 'package:shiftsmart/screens/manager/manager_site.dart';
import 'package:shiftsmart/services/project_service.dart';
import 'package:shiftsmart/services/company_service.dart';
import 'package:shiftsmart/services/site_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/feature_gate.dart';
import 'package:shiftsmart/models/project.dart';
import 'package:shiftsmart/models/company.dart';
import 'package:shiftsmart/models/site.dart';

class Managerprojects extends StatefulWidget {
  const Managerprojects({super.key});

  @override
  State<Managerprojects> createState() => _Managerprojectstate();
}

class _Managerprojectstate extends State<Managerprojects> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  final ProjectService _projectService = ProjectService();
  final CompanyService _companyService = CompanyService();
  final SiteService _siteService = SiteService();

  List<Project> allProjects = [];
  List<Project> filteredProjects = [];

  List<Company> allCompanies = [];
  List<Company> filteredCompanies = [];

  List<Site> allSites = [];
  List<Site> filteredSites = [];

  String _lastTenant = '';
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    enableFullScreen();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshKey.currentState?.show();
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      fetchProjects(),
      fetchCompanies(),
      fetchSites(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> fetchProjects() async {
    final tenantProvider = context.read<TenantProvider>();
    final selectedOrg = tenantProvider.selectedOrganization;
    final projects = await _projectService.fetchAllProjects();
    setState(() {
      allProjects = projects;
      _lastTenant = selectedOrg;
      _applySearch();
    });
  }

  Future<void> fetchCompanies() async {
    final companies = await _companyService.fetchCompanies();
    setState(() {
      allCompanies = companies;
      _applySearch();
    });
  }

  Future<void> fetchSites() async {
    final sites = await _siteService.fetchAllSites();
    setState(() {
      allSites = sites;
      _applySearch();
    });
  }

  void _applySearch() {
    setState(() {
      filteredProjects = _searchQuery.isEmpty
          ? List<Project>.from(allProjects)
          : allProjects
              .where((p) =>
                  p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
      filteredCompanies = _searchQuery.isEmpty
          ? List<Company>.from(allCompanies)
          : allCompanies
              .where((c) =>
                  c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
      filteredSites = _searchQuery.isEmpty
          ? List<Site>.from(allSites)
          : allSites
              .where((s) =>
                  s.siteName.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();
    });
  }

  void onQueryChanged(String query) {
    _searchQuery = query;
    _applySearch();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureGate(
      featureKey: 'project_management',
      featureName: 'Project Management',
      currentScreen: 'ManagerProjects',
      child: Consumer<TenantProvider>(
        builder: (context, tp, _) {
          if (tp.selectedOrganization != _lastTenant) {
            _lastTenant = tp.selectedOrganization;
            if (_lastTenant.isNotEmpty && mounted && !_isLoading) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _refreshData());
            }
          }
          return Scaffold(
            body: Stack(
              children: [
                const Background(),
                SafeArea(
                  child: DefaultTabController(
                    length: 3,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: Colors.blueAccent,
                          unselectedLabelColor: Colors.white,
                          indicatorColor: Colors.blueAccent,
                          tabs: [
                            Tab(
                                icon: const Icon(Icons.business),
                                text: "COMPANY ${allCompanies.length}"),
                            Tab(
                                icon: const Icon(Icons.assignment),
                                text: "PROJECT ${allProjects.length}"),
                            Tab(
                                icon: const Icon(Icons.location_on),
                                text: "SITE ${allSites.length}"),
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
                              prefixIcon: const Icon(Icons.search,
                                  color: Colors.white54),
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
                              : TabBarView(
                                  children: [
                                    _buildCompanyView(),
                                    _buildProjectView(),
                                    _buildSiteView(),
                                  ],
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
      ),
    );
  }

  Widget _buildCompanyView() {
    return Column(
      children: [
        _buildListHeader("COMPANY LIST",
            "Total: ${filteredCompanies.length} Companies", "Add Company", () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const Managercomapny()));
        }),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredCompanies.length,
              itemBuilder: (context, index) {
                final company = filteredCompanies[index];
                return _buildListItem(
                  title: company.name,
                  subtitle: company.address,
                  bottomInfo:
                      "☎ ${company.phoneNumber} - ${company.ContactPerson}",
                  onEdit: () {},
                  onDelete: () {},
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectView() {
    return Column(
      children: [
        _buildListHeader("PROJECT LIST",
            "Total: ${filteredProjects.length} Projects", "Add Project", () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const Managercreateproject()));
        }),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredProjects.length,
              itemBuilder: (context, index) {
                final project = filteredProjects[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                Managerprojectview(project: project)));
                  },
                  child: _buildProjectListItem(
                    title: project.name,
                    status: project.status,
                    startDate: DateFormat("yyyy-MM-dd")
                        .format(DateTime.parse(project.startDate)),
                    dueDate: DateFormat("yyyy-MM-dd")
                        .format(DateTime.parse(project.projectDue)),
                    trailing: _buildStatusIcon(project.status),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSiteView() {
    return Column(
      children: [
        _buildListHeader(
            "SITE LIST", "Total: ${filteredSites.length} Sites", "Add Site",
            () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const Managersite()));
        }),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredSites.length,
              itemBuilder: (context, index) {
                final site = filteredSites[index];
                return _buildListItem(
                  title: site.siteName,
                  subtitle: "Project ID: ${site.projectId ?? 'N/A'}",
                  bottomInfo:
                      "Coordinates: ${site.latitude ?? ''}, ${site.longitude ?? ''}",
                  onEdit: () {},
                  onDelete: () {},
                );
              },
            ),
          ),
        ),
      ],
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

  Widget _buildListItem(
      {required String title,
      required String subtitle,
      required String bottomInfo,
      required VoidCallback onEdit,
      required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(bottomInfo,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12))),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 14, color: Colors.blue),
                    label: const Text("Edit",
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                    label: const Text("Delete",
                        style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 0)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectListItem(
      {required String title,
      required String status,
      required String startDate,
      required String dueDate,
      required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amberAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(status,
                        style: const TextStyle(
                            color: Colors.amberAccent, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 20)
            ],
          ),
          const SizedBox(height: 8),
          const Text("Initial setup and onboarding project for operations",
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text("Start Date: $startDate",
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 16),
              Text("Due Date: $dueDate",
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Icon(Icons.domain_verification_outlined,
            color: Colors.green, size: 20);
      case 'pending':
        return const Icon(Icons.hourglass_top, color: Colors.red, size: 20);
      case 'active':
      default:
        return const Icon(Icons.donut_large_sharp,
            color: Colors.amberAccent, size: 20);
    }
  }
}
