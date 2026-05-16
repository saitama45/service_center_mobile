import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import '../../data/repositories/dtr_repository.dart';
import 'app_providers.dart';

class DtrState {
  final Map<String, dynamic>? status;
  final Position? currentPosition;
  final double? accuracy;
  final XFile? capturedPhoto;
  final bool isLoading;
  final String? errorMessage;
  final bool isLocationServiceEnabled;
  final LocationPermission locationPermission;
  final bool lastSubmitWasQueued;

  DtrState({
    this.status,
    this.currentPosition,
    this.accuracy,
    this.capturedPhoto,
    this.isLoading = false,
    this.errorMessage,
    this.isLocationServiceEnabled = false,
    this.locationPermission = LocationPermission.denied,
    this.lastSubmitWasQueued = false,
  });

  DtrState copyWith({
    Map<String, dynamic>? status,
    Position? currentPosition,
    double? accuracy,
    XFile? capturedPhoto,
    bool? isLoading,
    String? errorMessage,
    bool? isLocationServiceEnabled,
    LocationPermission? locationPermission,
    bool? lastSubmitWasQueued,
  }) {
    return DtrState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      accuracy: accuracy ?? this.accuracy,
      capturedPhoto: capturedPhoto ?? this.capturedPhoto,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      isLocationServiceEnabled:
          isLocationServiceEnabled ?? this.isLocationServiceEnabled,
      locationPermission: locationPermission ?? this.locationPermission,
      lastSubmitWasQueued: lastSubmitWasQueued ?? this.lastSubmitWasQueued,
    );
  }
}

class DtrNotifier extends StateNotifier<DtrState> {
  final DtrRepository _repository;

  DtrNotifier(this._repository) : super(DtrState()) {
    initialize();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    await _repository.refreshOfflineBootstrap();
    await _fetchStatus();
    await _initLocation();

    state = state.copyWith(isLoading: false);
  }

  Future<void> _fetchStatus() async {
    try {
      final status = await _repository.getDtrStatus();
      state = DtrState(
        status: status,
        currentPosition: state.currentPosition,
        accuracy: state.accuracy,
        capturedPhoto: state.capturedPhoto,
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        isLocationServiceEnabled: state.isLocationServiceEnabled,
        locationPermission: state.locationPermission,
        lastSubmitWasQueued: state.lastSubmitWasQueued,
      );
    } catch (e) {
      debugPrint('DTR: Status fetch failed: $e');
    }
  }

  /// Refreshes only the DTR status (schedule + last log) without re-running location init.
  Future<void> refreshStatus() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    await _repository.refreshOfflineBootstrap();
    await _fetchStatus();
    state = state.copyWith(isLoading: false);
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      state = state.copyWith(
        isLocationServiceEnabled: false,
        locationPermission: LocationPermission.denied,
        errorMessage: 'Location services are disabled. Please enable GPS.',
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    state = state.copyWith(
      isLocationServiceEnabled: serviceEnabled,
      locationPermission: permission,
    );

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await refreshLocation();
    } else if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        errorMessage:
            'Location permission permanently denied. Please enable it in app settings.',
      );
    } else {
      state = state.copyWith(
        errorMessage: 'Location permission denied. Tap to grant access.',
      );
    }
  }

  Future<void> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    state = state.copyWith(locationPermission: permission);
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await refreshLocation();
    } else if (permission == LocationPermission.deniedForever) {
      state = state.copyWith(
        errorMessage:
            'Location permission permanently denied. Please enable it in app settings.',
      );
    }
  }

  Future<void> refreshLocation() async {
    try {
      state = state.copyWith(errorMessage: null);
      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('GPS timeout'),
      );
      state = state.copyWith(
        currentPosition: position,
        accuracy: position.accuracy,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Could not acquire GPS location. Tap to retry.',
      );
    }
  }

  void setCapturedPhoto(XFile photo) {
    state = state.copyWith(capturedPhoto: photo);
  }

  void clearCapturedPhoto() {
    state = DtrState(
      status: state.status,
      currentPosition: state.currentPosition,
      accuracy: state.accuracy,
      capturedPhoto: null,
      isLoading: state.isLoading,
      errorMessage: state.errorMessage,
      isLocationServiceEnabled: state.isLocationServiceEnabled,
      locationPermission: state.locationPermission,
      lastSubmitWasQueued: state.lastSubmitWasQueued,
    );
  }

  /// Returns null on success, or an error message string on failure.
  Future<String?> submit(String deviceInfo, bool isOnline) async {
    if (state.currentPosition == null || state.capturedPhoto == null) {
      return 'Missing location or photo.';
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.submitLog(
      latitude: state.currentPosition!.latitude,
      longitude: state.currentPosition!.longitude,
      accuracy: state.accuracy ?? 0.0,
      photoPath: state.capturedPhoto!.path,
      deviceInfo: deviceInfo,
      isOnline: isOnline,
    );

    if (result.isSuccess) {
      final status = result.queued
          ? await _repository.getCachedDtrStatus()
          : await _repository.getDtrStatus();
      state = DtrState(
        status: status,
        currentPosition: state.currentPosition,
        accuracy: state.accuracy,
        capturedPhoto: null,
        isLoading: false,
        isLocationServiceEnabled: state.isLocationServiceEnabled,
        locationPermission: state.locationPermission,
        lastSubmitWasQueued: result.queued,
      );
      return null;
    }

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.message,
      lastSubmitWasQueued: false,
    );
    return result.message;
  }
}

final dtrProvider = StateNotifierProvider<DtrNotifier, DtrState>((ref) {
  return DtrNotifier(ref.watch(dtrRepositoryProvider));
});
