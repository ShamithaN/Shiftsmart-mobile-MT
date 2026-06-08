import 'package:flutter/material.dart';
import 'package:shiftsmart/models/site.dart';
import 'package:shiftsmart/screens/manager/manager_create_site.dart';
import 'package:shiftsmart/widgets/background.dart';
import 'package:shiftsmart/widgets/sidenav.dart';
import 'package:shiftsmart/widgets/uppernavbar.dart';

class Managersiteview extends StatefulWidget {
  final Site site;
  final String? projectName;
  final bool embedded;

  const Managersiteview({
    super.key,
    required this.site,
    this.projectName,
    this.embedded = false,
  });

  @override
  State<Managersiteview> createState() => _ManagersiteviewState();
}

class _ManagersiteviewState extends State<Managersiteview> {
  static const _pageBg = Color(0xFF0B1020);
  static const _panelBg = Color(0xFF262D3F);
  static const _tileBg = Color(0xFF1B2335);
  static const _cyan = Color(0xFF77E4F7);

  Site get site => widget.site;

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildDetailsPanel();
    }

    return Scaffold(
      backgroundColor: _pageBg,
      drawer: const Sidenav(),
      appBar: const Uppernavbar(showBackButton: true),
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: _buildDetailsPanel(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _panelBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSiteInfo(),
                const SizedBox(height: 24),
                _textPanel(
                  title: 'ADDRESS',
                  body: _valueOrFallback(site.address, 'No address provided'),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 64, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SITE DETAILS',
            style: TextStyle(
              color: _cyan,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _valueOrFallback(site.siteName, 'Untitled Site'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _statusBadge(_projectName),
        ],
      ),
    );
  }

  Widget _statusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cyan.withValues(alpha: 0.6)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _cyan,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildSiteInfo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 820
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final spacing = 16.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: [
            _detailTile(
              width: itemWidth,
              label: 'PROJECT',
              value: _projectName,
              icon: Icons.assignment_rounded,
            ),
            _detailTile(
              width: itemWidth,
              label: 'SITE ID',
              value: site.siteId.toString(),
              icon: Icons.tag_rounded,
            ),
            _detailTile(
              width: itemWidth,
              label: 'GEOFENCE TYPE',
              value: _valueOrFallback(site.geoFenceType, 'Not provided'),
              icon: Icons.radar_rounded,
            ),
            _detailTile(
              width: itemWidth,
              label: 'RADIUS',
              value: site.radius == null ? 'Not provided' : '${site.radius} m',
              icon: Icons.adjust_rounded,
            ),
            _detailTile(
              width: itemWidth,
              label: 'LATITUDE',
              value: _valueOrFallback(site.latitude, 'Not provided'),
              icon: Icons.explore_rounded,
            ),
            _detailTile(
              width: itemWidth,
              label: 'LONGITUDE',
              value: _valueOrFallback(site.longitude, 'Not provided'),
              icon: Icons.explore_outlined,
            ),
            _detailTile(
              width: itemWidth,
              label: 'COORDINATES',
              value: _coordinatesValue,
              icon: Icons.location_on_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _detailTile({
    required double width,
    required String label,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _tileBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.56),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: _cyan, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _textPanel({required String title, required String body}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 90),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _tileBg.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _cyan,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 12,
      children: [
        _actionButton(
          text: 'Update',
          icon: Icons.edit_rounded,
          gradient: const [Color(0xFF34C8E8), Color(0xFF4E4AF2)],
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => Managercreatesite(site: site),
              ),
            );
            if (result == true && mounted) {
              Navigator.pop(context, true);
            }
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required String text,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onPressed,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String get _projectName {
    return _valueOrFallback(
      widget.projectName ?? site.project?.name,
      'No Project Name',
    );
  }

  String get _coordinatesValue {
    final savedCoordinates = _valueOrFallback(site.geoCoordinates, '');
    if (savedCoordinates.isNotEmpty) {
      return savedCoordinates;
    }

    final lat = _valueOrFallback(site.latitude, '');
    final lng = _valueOrFallback(site.longitude, '');
    if (lat.isNotEmpty && lng.isNotEmpty) {
      return '$lat, $lng';
    }

    return 'Not provided';
  }

  String _valueOrFallback(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'null' ||
        trimmed.toLowerCase().startsWith('no ')) {
      return fallback;
    }
    return trimmed;
  }
}
