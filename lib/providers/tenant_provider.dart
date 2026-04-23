import 'package:flutter/material.dart';
import 'package:shiftsmart/services/super_admin_service.dart';

/// Shared state that holds the currently selected tenant across
/// all manager screens. When [setTenant] is called (from the Dashboard
/// dropdown or the Bottomnavbar picker), every Consumer<TenantProvider>
/// widget rebuilds automatically.
class TenantProvider with ChangeNotifier {
  final SuperAdminService _superAdminService = SuperAdminService();

  Map<String, dynamic>? _selectedTenant; // Full tenant map from API
  String _selectedOrganization = '';      // Display name
  List<Map<String, dynamic>> _tenants = []; // All available tenants

  bool _isSwitching = false; // Switching-in-progress guard

  // ── Getters ──────────────────────────────────────────────────────────────
  Map<String, dynamic>? get selectedTenant => _selectedTenant;
  String get selectedOrganization => _selectedOrganization;
  List<Map<String, dynamic>> get tenants => List.unmodifiable(_tenants);
  bool get isSwitching => _isSwitching;
  bool get hasTenant => _selectedOrganization.isNotEmpty;

  // ── Load tenants from backend ─────────────────────────────────────────────
  Future<void> loadTenants() async {
    try {
      final fetched = await _superAdminService.getAllTenants();
      _tenants = fetched.map((t) => t as Map<String, dynamic>).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('[TenantProvider] Error loading tenants: $e');
    }
  }

  // ── Initialise from current token (call once after login) ─────────────────
  void initFromCurrentTenant(String tenantName, Map<String, dynamic>? tenantMap) {
    _selectedOrganization = tenantName;
    _selectedTenant = tenantMap;
    notifyListeners();
  }

  // ── Switch tenant (calls backend + notifies listeners) ───────────────────
  Future<bool> switchTenant(Map<String, dynamic> tenant) async {
    final name = (tenant['name'] ?? tenant['Name'] ?? 'Unnamed').toString();
    final tenantId = tenant['tenantId'] ?? tenant['TenantId'] ??
        tenant['id'] ?? tenant['ID'];

    // Optimistically update display name so UI is instant
    _selectedOrganization = name;
    _selectedTenant = tenant;
    _isSwitching = true;
    notifyListeners();

    bool success = false;
    if (tenantId != null) {
      try {
        final result = await _superAdminService.switchTenant(tenantId);
        success = result != null;
      } catch (e) {
        debugPrint('[TenantProvider] switchTenant error: $e');
      }
    }

    _isSwitching = false;
    notifyListeners();
    return success;
  }

  // ── Utility: find tenant map by organisation name ─────────────────────────
  Map<String, dynamic>? findTenantByName(String name) {
    try {
      return _tenants.firstWhere(
        (t) => (t['name'] ?? t['Name'] ?? '')
            .toString()
            .toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
