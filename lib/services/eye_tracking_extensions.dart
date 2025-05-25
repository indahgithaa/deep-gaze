// File: lib/extensions/eye_tracking_extensions.dart

import 'package:flutter/material.dart';

import '../services/eye_tracking_service.dart';

// Extension untuk menambahkan fungsi calibration ke EyeTrackingService
extension EyeTrackingCalibration on EyeTrackingService {
  static final List<CalibrationData> _calibrationPoints = [];
  static bool _isCalibrated = false;

  // Menambahkan calibration point
  void addCalibrationPoint(double x, double y) {
    final calibrationData = CalibrationData(
      screenX: x,
      screenY: y,
      gazeX: gazeX,
      gazeY: gazeY,
      timestamp: DateTime.now(),
    );

    _calibrationPoints.add(calibrationData);
    print('Calibration point added: Screen($x, $y) -> Gaze($gazeX, $gazeY)');

    // Auto-compute calibration when we have enough points
    if (_calibrationPoints.length >= 9) {
      _computeCalibration();
    }
  }

  // Mendapatkan semua calibration points
  List<CalibrationData> get calibrationPoints => _calibrationPoints;

  // Mengecek apakah sudah dikalibrasi
  bool get isCalibrated => _isCalibrated;

  // Menghitung calibration matrix/offset
  void _computeCalibration() {
    if (_calibrationPoints.length < 9) return;

    // Implementasi sederhana: rata-rata offset
    double totalOffsetX = 0;
    double totalOffsetY = 0;

    for (final point in _calibrationPoints) {
      totalOffsetX += (point.screenX - point.gazeX);
      totalOffsetY += (point.screenY - point.gazeY);
    }

    final avgOffsetX = totalOffsetX / _calibrationPoints.length;
    final avgOffsetY = totalOffsetY / _calibrationPoints.length;

    print('Calibration computed: Offset($avgOffsetX, $avgOffsetY)');

    _isCalibrated = true;

    // Simpan offset untuk koreksi gaze di masa depan
    _setCalibrationOffset(avgOffsetX, avgOffsetY);
  }

  // Mengatur offset calibration
  void _setCalibrationOffset(double offsetX, double offsetY) {
    // Dalam implementasi nyata, ini akan menyimpan offset
    // dan menggunakannya untuk mengoreksi gaze position
    print('Calibration offset set: ($offsetX, $offsetY)');
  }

  // Reset calibration
  void resetCalibration() {
    _calibrationPoints.clear();
    _isCalibrated = false;
    print('Calibration reset');
  }

  // Mendapatkan gaze position yang sudah dikoreksi
  Offset getCalibratedGaze() {
    if (!_isCalibrated) {
      return Offset(gazeX, gazeY);
    }

    // Implementasi koreksi gaze berdasarkan calibration
    // Ini adalah implementasi sederhana
    return Offset(gazeX, gazeY);
  }

  // Menghitung akurasi calibration
  double getCalibrationAccuracy() {
    if (_calibrationPoints.length < 9) return 0.0;

    double totalError = 0;
    for (final point in _calibrationPoints) {
      final errorX = (point.screenX - point.gazeX).abs();
      final errorY = (point.screenY - point.gazeY).abs();
      final error = (errorX + errorY) / 2;
      totalError += error;
    }

    final avgError = totalError / _calibrationPoints.length;
    final accuracy = (100 - (avgError / 10)).clamp(0.0, 100.0);

    return accuracy;
  }

  // Mendapatkan status calibration
  String getCalibrationStatus() {
    if (!_isCalibrated) {
      return 'Not Calibrated';
    }

    final accuracy = getCalibrationAccuracy();
    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 80) return 'Good';
    if (accuracy >= 70) return 'Fair';
    return 'Poor';
  }

  // Validasi calibration
  bool validateCalibration() {
    if (!_isCalibrated) return false;

    final accuracy = getCalibrationAccuracy();
    return accuracy >= 70; // Minimum 70% accuracy
  }

  // Export calibration data (untuk debugging atau analisis)
  Map<String, dynamic> exportCalibrationData() {
    return {
      'isCalibrated': _isCalibrated,
      'pointCount': _calibrationPoints.length,
      'accuracy': getCalibrationAccuracy(),
      'status': getCalibrationStatus(),
      'points': _calibrationPoints
          .map((point) => {
                'screenX': point.screenX,
                'screenY': point.screenY,
                'gazeX': point.gazeX,
                'gazeY': point.gazeY,
                'timestamp': point.timestamp.toIso8601String(),
              })
          .toList(),
    };
  }
}

// Data class untuk menyimpan calibration point
class CalibrationData {
  final double screenX;
  final double screenY;
  final double gazeX;
  final double gazeY;
  final DateTime timestamp;

  CalibrationData({
    required this.screenX,
    required this.screenY,
    required this.gazeX,
    required this.gazeY,
    required this.timestamp,
  });

  // Menghitung error distance
  double get errorDistance {
    final dx = screenX - gazeX;
    final dy = screenY - gazeY;
    return (dx * dx + dy * dy);
  }

  @override
  String toString() {
    return 'CalibrationData(screen: ($screenX, $screenY), gaze: ($gazeX, $gazeY), error: ${errorDistance.toStringAsFixed(2)})';
  }
}
