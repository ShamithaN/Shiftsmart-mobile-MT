import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shiftsmart/providers/tenant_provider.dart';
import 'package:shiftsmart/screens/manager/manager_tenant_details.dart';

class OrganizationSelector extends StatefulWidget {
  final VoidCallback? onTenantSwitched;

  const OrganizationSelector({super.key, this.onTenantSwitched});

  @override
  State<OrganizationSelector> createState() => _OrganizationSelectorState();
}

class _OrganizationSelectorState extends State<OrganizationSelector> {
  @override
  void initState() {
    super.initState();
    // Ensure tenant list is loaded when this widget first appears.
    // This makes the organization dropdown available immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tp = context.read<TenantProvider>();
      if (tp.tenants.isEmpty) {
        tp.loadTenants();
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    return Consumer<TenantProvider>(
      builder: (context, tenantProvider, child) {
        final tenants = tenantProvider.tenants;
        final selectedOrg = tenantProvider.selectedOrganization;

        // Build a popup menu of all known tenants. The current selection
        // is shown in the button, and selecting a different tenant triggers
        // tenantProvider.switchTenant.
        return PopupMenuButton<Map<String, dynamic>>(
          offset: const Offset(0, 50),
          color: const Color(0xFF161B28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          elevation: 10,
          padding: EdgeInsets.zero,
          onSelected: (Map<String, dynamic> tenant) async {
            final name = (tenant['name'] ?? 
                          tenant['Name'] ?? 
                          tenant['tenantName'] ?? 
                          tenant['TenantName'] ?? 
                          tenant['organizationName'] ?? 
                          '').toString();
            if (name == selectedOrg && name.isNotEmpty) return;

            // When the user picks a new organization, ask TenantProvider
            // to switch tenant context. The provider handles backend
            // switching and notifies all listeners.
            final success = await tenantProvider.switchTenant(tenant);
            if (success && widget.onTenantSwitched != null) {
              widget.onTenantSwitched!();
            }
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2430),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.business,
                      color: Color(0xFF2DA6FF),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        selectedOrg.isNotEmpty ? selectedOrg : 'Select Organization',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
          itemBuilder: (BuildContext context) {
            List<PopupMenuEntry<Map<String, dynamic>>> items = [];

            // Header
            items.add(
              const PopupMenuItem<Map<String, dynamic>>(
                enabled: false,
                height: 30,
                child: Text(
                  'ACTIVE ORGANIZATION',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            );

            // Tenants
            for (var tenant in tenants) {
              final name = (tenant['name'] ?? 
                            tenant['Name'] ?? 
                            tenant['tenantName'] ?? 
                            tenant['TenantName'] ?? 
                            tenant['organizationName'] ?? 
                            'Unnamed').toString();
              final isSelected = name == selectedOrg;

              items.add(
                PopupMenuItem<Map<String, dynamic>>(
                  value: tenant,
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF222B45) : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check,
                            color: Color(0xFF2DA6FF),
                            size: 18,
                          )
                        else
                          Icon(
                            Icons.arrow_outward,
                            color: Colors.white.withOpacity(0.2),
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return items;
          },
        );
      },
    );
  }
}
