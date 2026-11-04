import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../models/family_models.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_components.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import 'family_member_details_screen.dart';

const String osmTileUrlTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String osmUserAgentPackageName = 'com.binarypulse.amarguard';

class FamilyMapScreen extends StatefulWidget {
  const FamilyMapScreen({super.key, required this.controller});

  final FamilySafetyController controller;

  @override
  State<FamilyMapScreen> createState() => _FamilyMapScreenState();
}

class _FamilyMapScreenState extends State<FamilyMapScreen> {
  final MapController _mapController = MapController();
  String? _selectedMemberId;
  bool _tilesFailed = false;
  Timer? _freshnessTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _freshnessTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _freshnessTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connections = _connections;

    return Scaffold(
      backgroundColor: CareColors.ivory,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(context, connections)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 14,
            right: 14,
            child: _MapTopBar(
              title: l10n.careMapTitle,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 14,
            right: 14,
            child: _MemberSelector(
              connections: connections,
              selectedMemberId: _selectedMemberId,
              onSelect: _selectMember,
            ),
          ),
          Positioned(
            right: 14,
            bottom: 190,
            child: Column(
              children: [
                _MapControlButton(
                  icon: Icons.add_rounded,
                  label: l10n.careMapZoomIn,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.remove_rounded,
                  label: l10n.careMapZoomOut,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.my_location_rounded,
                  label: l10n.careMapRecenter,
                  onTap: _recenter,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomInfoSheet(
              connections: connections,
              selectedMemberId: _selectedMemberId,
              onSelect: _selectMember,
              onOpenDetails: _openDetails,
              onClose: () => setState(() => _selectedMemberId = null),
            ),
          ),
        ],
      ),
    );
  }

  List<FamilyConnection> get _connections {
    final watched = widget.controller.authorizedConnections;
    return watched;
  }

  Widget _buildMap(BuildContext context, List<FamilyConnection> connections) {
    final l10n = AppLocalizations.of(context)!;
    final located = connections
        .where(
          (item) => item.location != null && item.location!.hasValidCoordinates,
        )
        .toList();

    if (located.isEmpty) {
      return Container(
        color: CareColors.ivory,
        child: SafeArea(
          child: CareEmptyState(
            icon: Icons.map_outlined,
            title: l10n.careMapNoMembers,
            message: l10n.careMapNoMembersBody,
          ),
        ),
      );
    }

    final markers = <Marker>[];
    for (final connection in located) {
      final record = connection.location!;
      final point = LatLng(record.latitude, record.longitude);
      final freshness = connection.freshness;
      markers.add(
        Marker(
          point: point,
          width: 74,
          height: 74,
          alignment: Alignment.topCenter,
          child: CareMapMarker(
            name: connection.viewerDisplayName,
            freshness: freshness,
            batteryLevel: connection.presence?.batteryLevel ?? -1,
            isCharging: connection.presence?.isCharging ?? false,
            isSelected: _selectedMemberId == connection.memberKey,
            onTap: () => _selectMember(connection.memberKey),
          ),
        ),
      );
      if (record.accuracy > 0) {
        markers.add(
          Marker(
            point: point,
            width: record.accuracy,
            height: record.accuracy,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: freshnessColor(freshness).withValues(alpha: 0.12),
                border: Border.all(
                  color: freshnessColor(freshness).withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(
          located.first.location!.latitude,
          located.first.location!.longitude,
        ),
        initialZoom: 13,
        minZoom: 2,
        maxZoom: 18,
        backgroundColor: CareColors.seaMist,
      ),
      children: [
        TileLayer(
          urlTemplate: osmTileUrlTemplate,
          userAgentPackageName: osmUserAgentPackageName,
          maxNativeZoom: 19,
          tileDisplay: TileDisplay.fadeIn(
            duration: const Duration(milliseconds: 120),
          ),
          errorTileCallback: (tile, error, stackTrace) {
            if (!_tilesFailed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _tilesFailed = true);
              });
            }
          },
        ),
        MarkerLayer(markers: markers),
        SimpleAttributionWidget(
          source: Text(
            l10n.careMapAttribution,
            style: const TextStyle(fontSize: 10.5),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.86),
        ),
      ],
    );
  }

  void _selectMember(String memberId) {
    setState(() => _selectedMemberId = memberId);
    final connection = _connections.firstWhere(
      (item) => item.memberKey == memberId,
      orElse: () => _connections.first,
    );
    final record = connection.location;
    if (record == null || !record.hasValidCoordinates) return;
    _mapController.move(LatLng(record.latitude, record.longitude), 15);
  }

  void _recenter() {
    final located = _connections
        .where((item) => item.location != null)
        .toList();
    if (located.isEmpty) return;
    final latitudes = located.map((item) => item.location!.latitude).toList();
    final longitudes = located.map((item) => item.location!.longitude).toList();
    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLng = longitudes.reduce((a, b) => a < b ? a : b);
    final maxLng = longitudes.reduce((a, b) => a > b ? a : b);
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final span = (maxLat - minLat).abs() > (maxLng - minLng).abs()
        ? (maxLat - minLat).abs()
        : (maxLng - minLng).abs();
    final zoom = span < 0.005 ? 15.0 : (span < 0.05 ? 13.0 : 11.0);
    _mapController.move(center, zoom);
  }

  void _openDetails(FamilyConnection connection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyMemberDetailsScreen(
          controller: widget.controller,
          grant: connection.grant,
          connection: connection,
        ),
      ),
    );
  }
}

class CareMapMarker extends StatelessWidget {
  const CareMapMarker({
    super.key,
    required this.name,
    required this.freshness,
    required this.batteryLevel,
    required this.isCharging,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final LocationFreshness freshness;
  final int batteryLevel;
  final bool isCharging;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = freshnessColor(freshness);
    final scale = isSelected ? 1.25 : 1.0;
    return GestureDetector(
      onTap: onTap,
      child: Transform.scale(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (batteryLevel >= 0 && batteryLevel <= 10)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: CareColors.markerLowBattery,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$batteryLevel%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            Container(width: 2, height: 8, color: accent),
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: CareColors.mapControlSurface,
        borderRadius: BorderRadius.circular(CareTheme.radiusControl),
        border: Border.all(color: CareColors.mapControlBorder),
        boxShadow: [
          BoxShadow(
            color: CareColors.mapShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CareColors.seaMist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: CareColors.teal,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: CareColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberSelector extends StatelessWidget {
  const _MemberSelector({
    required this.connections,
    required this.selectedMemberId,
    required this.onSelect,
  });

  final List<FamilyConnection> connections;
  final String? selectedMemberId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (connections.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: connections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final connection = connections[index];
          final selected = connection.memberKey == selectedMemberId;
          final accent = freshnessColor(connection.freshness);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(connection.memberKey),
              borderRadius: BorderRadius.circular(CareTheme.radiusControl),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CareColors.mapControlSurface,
                  borderRadius: BorderRadius.circular(CareTheme.radiusControl),
                  border: Border.all(
                    color: selected ? accent : CareColors.mapControlBorder,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CareColors.mapShadow,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        connection.viewerDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CareColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: CareColors.mapControlSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CareColors.mapControlBorder),
              boxShadow: [
                BoxShadow(
                  color: CareColors.mapShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: CareColors.navy, size: 21),
          ),
        ),
      ),
    );
  }
}

class _BottomInfoSheet extends StatelessWidget {
  const _BottomInfoSheet({
    required this.connections,
    required this.selectedMemberId,
    required this.onSelect,
    required this.onOpenDetails,
    required this.onClose,
  });

  final List<FamilyConnection> connections;
  final String? selectedMemberId;
  final ValueChanged<String> onSelect;
  final ValueChanged<FamilyConnection> onOpenDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedConnection;

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: CareColors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CareTheme.radiusSheet),
        ),
        boxShadow: [
          BoxShadow(
            color: CareColors.navy.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: selected == null
            ? _hintContent(l10n)
            : _detailContent(context, l10n, selected),
      ),
    );
  }

  FamilyConnection? get _selectedConnection {
    if (selectedMemberId == null) return null;
    for (final connection in connections) {
      if (connection.memberKey == selectedMemberId) return connection;
    }
    return null;
  }

  Widget _hintContent(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: CareColors.navySoft,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.careMapTitle,
            style: const TextStyle(
              color: CareColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.careFamilyMembersSubtitle,
            style: const TextStyle(
              color: CareColors.slate,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailContent(
    BuildContext context,
    AppLocalizations l10n,
    FamilyConnection connection,
  ) {
    final record = connection.location;
    final freshness = connection.freshness;
    final accent = freshnessColor(freshness);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CareColors.navySoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CareAvatar(name: connection.viewerDisplayName, size: 42),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      connection.viewerDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CareColors.navy,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relationshipLabel(context, connection.grant.relationship),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CareColors.slate,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: CareColors.markerUnavailable,
                  size: 20,
                ),
                tooltip: l10n.careCancel,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CareStatusPill(
                label: freshnessLabelFor(context, freshness),
                color: accent,
                icon: freshnessIcon(freshness),
              ),
              if (record != null)
                CareBatteryBadge(
                  level: connection.presence?.batteryLevel ?? -1,
                  isCharging: connection.presence?.isCharging ?? false,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (record != null) ...[
            CareInfoTile(
              icon: Icons.gps_fixed_rounded,
              label: l10n.careMapCoordinates,
              value: formatCoordinates(record.latitude, record.longitude),
            ),
            CareInfoTile(
              icon: Icons.straighten_rounded,
              label: l10n.careMapAccuracy,
              value: formatAccuracy(record.accuracy),
            ),
            CareInfoTile(
              icon: Icons.schedule_rounded,
              label: l10n.careMapLastUpdate,
              value: relativeTimeLabel(context, record.capturedAt),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => onOpenDetails(connection),
              style: CareTheme.primaryButtonStyle(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: Text(l10n.careMemberDetailsTitle),
            ),
          ),
        ],
      ),
    );
  }
}
