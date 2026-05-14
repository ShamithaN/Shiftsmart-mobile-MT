import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/tenant_provider.dart';
import 'package:shiftsmart/screens/manager/manager_create_com.dart';
import 'package:shiftsmart/screens/manager/manager_create_project1.dart';
import 'package:shiftsmart/screens/manager/manager_projectview.dart';
import 'package:shiftsmart/screens/manager/manager_create_site.dart';
import 'package:shiftsmart/services/project_service.dart';
import 'package:shiftsmart/services/company_service.dart';
import 'package:shiftsmart/services/site_service.dart';
import 'package:shiftsmart/utils/fullscreen_helper.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/premium_feature_gate.dart';
import 'package:shiftsmart/widgets/bottomnavbar.dart';
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
    return Consumer<TenantProvider>(
      builder: (context, tp, _) {
        if (tp.selectedOrganization != _lastTenant) {
          _lastTenant = tp.selectedOrganization;
          if (_lastTenant.isNotEmpty && mounted && !_isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
          }
        }

        // ── Premium Feature Gate ──────────────────────────────────────────
        if (!tp.isFeatureEnabled('project_management') ||
            tp.isNavIndexBlocked(1)) {
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
                        featureName: 'Project Management',
                        blockedEndpoint: '/project/all',
                        customMessage:
                            'Contact your administrator to enable this module for your tenant.',
                        onGotIt: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const Bottomnavbar(selectedIndex: 0),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
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
                              icon: _buildTabIconWithCrown(
                                  tp, 'company', const Icon(Icons.business)),
                              text: "COMPANY ${allCompanies.length}"),
                          Tab(
                              icon: _buildTabIconWithCrown(
                                  tp, 'project', const Icon(Icons.assignment)),
                              text: "PROJECT ${allProjects.length}"),
                          Tab(
                              icon: _buildTabIconWithCrown(
                                  tp, 'site', const Icon(Icons.location_on)),
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
    );
  }

  Widget _buildTabIconWithCrown(
      TenantProvider tp, String keyword, Icon baseIcon) {
    bool isBlocked = tp.isEndpointBlocked(keyword);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        if (isBlocked)
          Positioned(
            top: -4,
            right: -8,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7A5C00), Color(0xFFB8880A)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8880A).withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700),
                size: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompanyView() {
    return Column(
      children: [
        _buildListHeader(
            "COMPANY LIST",
            "Total: ${filteredCompanies.length} Companies",
            "Add Company", () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Managercreatecom()),
          );
          if (result == true) {
            _refreshData();
          }
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
                  onEdit: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              Managercreatecom(company: company)),
                    );
                    if (result == true) {
                      _refreshData();
                    }
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E2433),
                        title: const Text("Delete Company",
                            style: TextStyle(color: Colors.white)),
                        content: Text(
                            "Are you sure you want to delete ${company.name}?",
                            style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Delete",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final success =
                          await _companyService.deleteCompany(company.id);
                      if (success) {
                        _refreshData();
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Failed to delete company")),
                          );
                        }
                      }
                    }
                  },
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
            () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const Managercreatesite()));
          if (result == true) {
            _refreshData();
          }
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
                  onEdit: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Managercreatesite(site: site)),
                    );
                    if (result == true) {
                      _refreshData();
                    }
                  },
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E2433),
                        title: const Text("Delete Site",
                            style: TextStyle(color: Colors.white)),
                        content: Text(
                            "Are you sure you want to delete ${site.siteName}?",
                            style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text("Delete",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final success =
                          await _siteService.deleteSite(site.siteId);
                      if (success) {
                        _refreshData();
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Failed to delete site")),
                          );
                        }
                      }
                    }
                  },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleAndCount = Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(countText,
                  style:
                      const TextStyle(color: Colors.blueAccent, fontSize: 13)),
            ],
          );

          final addButton = ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              buttonText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          );

          final headerContent = constraints.maxWidth < 340
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleAndCount,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: addButton,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: titleAndCount),
                    const SizedBox(width: 8),
                    addButton,
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerContent,
              const SizedBox(height: 8),
              const Divider(color: Colors.white24, height: 1),
            ],
          );
        },
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
