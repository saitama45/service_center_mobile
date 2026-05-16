import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/bms_app_bar.dart';
import '../../../core/widgets/bms_button.dart';
import '../../../core/utils/device_info_util.dart';
import '../../providers/app_providers.dart';
import '../../providers/dtr_provider.dart';

class DtrScreen extends ConsumerStatefulWidget {
  const DtrScreen({super.key});

  @override
  ConsumerState<DtrScreen> createState() => _DtrScreenState();
}

class _DtrScreenState extends ConsumerState<DtrScreen> {
  CameraController? _cameraController;
  late Stream<DateTime> _clockStream;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _clockStream =
        Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController =
        CameraController(front, ResolutionPreset.medium, enableAudio: false);
    try {
      await _cameraController!.initialize();
      // Lock to portrait so the preview and captured photo are never slanted
      await _cameraController!
          .lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('DTR: Camera error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onTakeSelfie() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;
    try {
      final photo = await _cameraController!.takePicture();
      ref.read(dtrProvider.notifier).setCapturedPhoto(photo);
    } catch (e) {
      debugPrint('DTR: Capture error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dtrProvider);
    final notifier = ref.read(dtrProvider.notifier);
    final isOffline = ref.watch(isOfflineProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: AppColors.white,
      drawer: const AppDrawer(),
      appBar: const BmsAppBar(title: 'DTR'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dtrProvider.notifier).refreshStatus(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Manila Time Clock ─────────────────────────────────────────
              _buildClock(),

              // ── Map View ─────────────────────────────────────────────────
              _buildMap(state),

              // ── Camera / Selfie ──────────────────────────────────────────
              _buildCameraSection(state),

              const SizedBox(height: AppDimensions.md),

              // ── Checklist & Action ───────────────────────────────────────
              _buildActionSection(state, notifier, isOffline),

              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClock() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      color: AppColors.primaryBlack,
      child: StreamBuilder<DateTime>(
        stream: _clockStream,
        builder: (context, snapshot) {
          final time = snapshot.data ?? DateTime.now();
          return Column(
            children: [
              Text(
                DateFormat('hh:mm:ss a').format(time),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                DateFormat('EEEE, MMMM dd, yyyy').format(time),
                style: const TextStyle(color: AppColors.white, fontSize: 16),
              ),
              const Text(
                'Manila Time',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(DtrState state) {
    // Build geofence circle from schedule store data (if any)
    Set<Circle> _buildCircles() {
      final circles = <Circle>{};
      if (state.currentPosition == null) return circles;

      // GPS accuracy circle
      circles.add(Circle(
        circleId: const CircleId('accuracy'),
        center: LatLng(
            state.currentPosition!.latitude, state.currentPosition!.longitude),
        radius: state.accuracy ?? 50,
        fillColor: Colors.blue.withValues(alpha: 0.15),
        strokeColor: Colors.blue,
        strokeWidth: 1,
      ));

      // Store geofence circle (skip for WFH)
      final schedule = state.status?['todaySchedule'];
      final scheduleType = schedule?['status'] as String? ?? '';
      if (schedule != null && scheduleType != 'WFH') {
        final store = schedule['store'] as Map<String, dynamic>?;
        if (store != null) {
          final storeLat = (store['latitude'] as num?)?.toDouble();
          final storeLng = (store['longitude'] as num?)?.toDouble();
          final radius = (store['radius_meters'] as num?)?.toDouble() ?? 100;
          if (storeLat != null && storeLng != null) {
            final distance = Geolocator.distanceBetween(
              state.currentPosition!.latitude,
              state.currentPosition!.longitude,
              storeLat,
              storeLng,
            );
            final within = distance <= radius;
            circles.add(Circle(
              circleId: const CircleId('geofence'),
              center: LatLng(storeLat, storeLng),
              radius: radius,
              fillColor:
                  (within ? Colors.green : Colors.red).withValues(alpha: 0.12),
              strokeColor: within ? Colors.green : Colors.red,
              strokeWidth: 2,
            ));
          }
        }
      }

      return circles;
    }

    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        children: [
          if (state.currentPosition != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(state.currentPosition!.latitude,
                    state.currentPosition!.longitude),
                zoom: 17,
              ),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              gestureRecognizers: {
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
              },
              circles: _buildCircles(),
            )
          else
            _buildMapPlaceholder(state),

          // Overlays shown only when map is active
          if (state.currentPosition != null) ...[
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                backgroundColor: AppColors.white,
                onPressed: () =>
                    ref.read(dtrProvider.notifier).refreshLocation(),
                child:
                    const Icon(Icons.gps_fixed, color: AppColors.primaryBlack),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Accuracy: ${state.accuracy?.toStringAsFixed(1) ?? "--"}m',
                  style: const TextStyle(color: AppColors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(DtrState state) {
    final permission = state.locationPermission;
    final serviceEnabled = state.isLocationServiceEnabled;

    // Still initialising — don't flash action buttons yet
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Permission granted but still waiting for GPS fix
    if (state.errorMessage == null &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      return const Center(child: CircularProgressIndicator());
    }

    // GPS service is off → prompt to enable
    if (!serviceEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gps_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text('GPS is disabled', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Enable Location'),
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ],
        ),
      );
    }

    // Permission permanently denied → send to app settings
    if (permission == LocationPermission.deniedForever) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'Location permission permanently denied',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open App Settings'),
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ],
        ),
      );
    }

    // Permission denied (requestable) or GPS error
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_searching, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              state.errorMessage ?? 'Location unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.my_location),
            label: const Text('Grant Location Access'),
            onPressed: () =>
                ref.read(dtrProvider.notifier).requestLocationPermission(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection(DtrState state) {
    final isInitialized =
        _cameraController != null && _cameraController!.value.isInitialized;
    // Android cameras report aspect ratio in landscape (e.g. 4:3 = 1.33).
    // Invert it when > 1 so the container stays portrait-shaped.
    final double previewRatio = isInitialized
        ? (_cameraController!.value.aspectRatio > 1
            ? 1 / _cameraController!.value.aspectRatio
            : _cameraController!.value.aspectRatio)
        : 3 / 4;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: previewRatio,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(color: AppColors.borderGray),
                color: Colors.black,
              ),
              child: state.capturedPhoto != null
                  ? Transform.flip(
                      flipX: true,
                      child: Image.file(File(state.capturedPhoto!.path),
                          fit: BoxFit.cover),
                    )
                  : isInitialized
                      ? CameraPreview(_cameraController!)
                      : const Center(
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 48)),
            ),
          ),
          const SizedBox(height: 8),
          if (state.capturedPhoto == null)
            BmsButton(
              label: 'Capture Selfie',
              variant: BmsButtonVariant.secondary,
              icon: Icons.camera_front,
              onPressed: _onTakeSelfie,
            )
          else
            BmsButton(
              label: 'Retake Photo',
              variant: BmsButtonVariant.danger,
              icon: Icons.refresh,
              onPressed: () =>
                  ref.read(dtrProvider.notifier).clearCapturedPhoto(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionSection(
      DtrState state, DtrNotifier notifier, bool isOffline) {
    if (state.status == null) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Center(
          child: state.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  isOffline
                      ? 'No cached active schedule is available for offline DTR. Connect to the internet to refresh your schedule.'
                      : 'Unable to load DTR status. Pull down to retry.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
        ),
      );
    }

    final schedule = state.status!['todaySchedule'];
    if (schedule == null) return _buildNoScheduleSection();

    final bool isSegmentComplete = state.status!['isSegmentComplete'] == true;
    final bool hasSelfie = state.capturedPhoto != null;
    final bool hasLocation =
        state.currentPosition != null && (state.accuracy ?? 1000) < 100;

    // Geofence check — skipped for WFH schedules
    final scheduleType = schedule['status'] as String? ?? '';
    final bool isWfh = scheduleType == 'WFH';
    bool isWithinVicinity = true;
    double? distanceMeters;
    double? radiusMeters;

    if (!isWfh && state.currentPosition != null) {
      final store = schedule['store'] as Map<String, dynamic>?;
      if (store != null) {
        final storeLat = (store['latitude'] as num?)?.toDouble();
        final storeLng = (store['longitude'] as num?)?.toDouble();
        radiusMeters = (store['radius_meters'] as num?)?.toDouble() ?? 100;
        if (storeLat != null && storeLng != null) {
          distanceMeters = Geolocator.distanceBetween(
            state.currentPosition!.latitude,
            state.currentPosition!.longitude,
            storeLat,
            storeLng,
          );
          isWithinVicinity = distanceMeters <= radiusMeters;
        }
      }
    }

    final bool isReady =
        hasSelfie && hasLocation && isWithinVicinity && !isSegmentComplete;

    String btnLabel = 'Time In';
    String message = 'Please ensure all requirements are met.';

    if (isSegmentComplete) {
      btnLabel = 'Shift Complete';
      message = 'You have completed Time In and Out for today.';
    } else if (!isWithinVicinity) {
      message =
          'You are outside the store vicinity (${distanceMeters!.toStringAsFixed(0)}m away, limit ${radiusMeters!.toStringAsFixed(0)}m). Move closer to enable Time In.';
    } else if (state.status!['lastLog'] != null &&
        state.status!['lastLog']['type'] != 'time_out') {
      btnLabel = 'Time Out';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: Column(
        children: [
          _buildScheduleBanner(schedule),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
          const SizedBox(height: 16),
          BmsButton(
            label: btnLabel,
            isFullWidth: true,
            isLoading: state.isLoading,
            onPressed: isReady
                ? () async {
                    final storeName = (schedule['store']
                            as Map<String, dynamic>?)?['name'] as String? ??
                        'your assigned location';
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Confirm $btnLabel'),
                        content: Text(
                          'You are about to record $btnLabel at $storeName. Continue?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(btnLabel),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) return;
                    final device = await DeviceInfoUtil.getDeviceInfo();
                    final error = await notifier.submit(device, !isOffline);
                    if (!mounted) return;
                    if (error == null) {
                      final wasQueued =
                          ref.read(dtrProvider).lastSubmitWasQueued;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(wasQueued
                              ? '$btnLabel saved offline. It will sync when you reconnect.'
                              : '$btnLabel recorded successfully!'),
                          backgroundColor:
                              wasQueued ? Colors.orange.shade700 : null,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  }
                : null,
          ),
          const SizedBox(height: 16),
          if (!isSegmentComplete)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCheckItem('Selfie', hasSelfie),
                _buildCheckItem('Location', hasLocation),
                if (!isWfh) _buildCheckItem('Vicinity', isWithinVicinity),
                _buildCheckItem('Ready', isReady),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNoScheduleSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.event_busy, color: Colors.orange.shade700, size: 40),
                const SizedBox(height: 8),
                Text(
                  'No Active Schedule',
                  style:
                      AppTextStyles.h3.copyWith(color: Colors.orange.shade800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'No On-site, Off-site, or WFH schedule found for your current time. Attendance logging is disabled.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.orange.shade700),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const BmsButton(
            label: 'Time In',
            isFullWidth: true,
            onPressed: null,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBanner(Map<String, dynamic> schedule) {
    final type = schedule['status'] as String? ?? '';
    final startRaw = schedule['start_time'] as String?;
    final endRaw = schedule['end_time'] as String?;

    String timeRange = '';
    if (startRaw != null && endRaw != null) {
      try {
        final start = DateTime.parse(startRaw).toLocal();
        final end = DateTime.parse(endRaw).toLocal();
        timeRange =
            '${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}';
      } catch (_) {}
    }

    final Color color;
    final IconData icon;
    switch (type) {
      case 'WFH':
        color = Colors.blue;
        icon = Icons.home_work;
        break;
      case 'Off-site':
        color = Colors.purple;
        icon = Icons.directions_car;
        break;
      default:
        color = Colors.green;
        icon = Icons.business;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.isEmpty ? 'Scheduled' : type,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13),
              ),
              if (timeRange.isNotEmpty)
                Text(
                  timeRange,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.8), fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isDone) {
    return Column(
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.circle_outlined,
          color: isDone ? Colors.green : Colors.grey,
        ),
        Text(label,
            style: TextStyle(
                color: isDone ? Colors.black : Colors.grey, fontSize: 12)),
      ],
    );
  }
}
