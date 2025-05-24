import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:seeso_flutter/event/calibration_info.dart';
import 'package:seeso_flutter/event/gaze_info.dart';
import 'package:seeso_flutter/event/status_info.dart';
import 'package:seeso_flutter/seeso.dart';
import 'package:seeso_flutter/seeso_initialized_result.dart';
import 'package:seeso_flutter/seeso_plugin_constants.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _seesoPlugin = SeeSo();
  //todo input your license key
  static const String _licenseKey =
      "dev_d4rilp973uxfvzofi0ky4mwkqp4qf9w19vodfe70";

  String _version = "Unknown";
  String _hasCameraPermissionString = "NO_GRANTED";
  String _stateString = "IDLE";
  String _trackingBtnText = "STOP TRACKING";
  bool _hasCameraPermission = false;
  bool _isInitialied = false;
  bool _showingGaze = false;
  bool _isCaliMode = false;

  double _x = 0.0, _y = 0.0;
  MaterialColor _gazeColor = Colors.red;
  double _nextX = 0, _nextY = 0, _calibrationProgress = 0.0;

  @override
  void initState() {
    super.initState();
    getSeeSoVersion();
    initSeeSo();
  }

  Future<void> checkCameraPermission() async {
    _hasCameraPermission = await _seesoPlugin.checkCameraPermission();
    if (!_hasCameraPermission) {
      _hasCameraPermission = await _seesoPlugin.requestCameraPermission();
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _hasCameraPermissionString = _hasCameraPermission ? "granted" : "denied";
    });
  }

  Future<void> initSeeSo() async {
    await checkCameraPermission();
    String requestInitGazeTracker = "failed Request";
    if (_hasCameraPermission) {
      try {
        InitializedResult? initializedResult =
            await _seesoPlugin.initGazeTracker(licenseKey: _licenseKey);

        setState(() {
          _isInitialied = initializedResult!.result;
          _stateString = initializedResult.message;
        });
        if (initializedResult!.result) {
          listenEvents();
          try {
            _seesoPlugin.startTracking();
          } on PlatformException catch (e) {
            setState(() {
              _stateString = "Occur PlatformException (${e.message})";
            });
          }
        }
      } on PlatformException catch (e) {
        requestInitGazeTracker = "Occur PlatformException (${e.message})";
        setState(() {
          _isInitialied = false;
          _stateString = requestInitGazeTracker;
        });
      }
    }
  }

  void _trackingBtnPressed() {
    if (_isInitialied) {
      if (_trackingBtnText == "START TRACKING") {
        try {
          _seesoPlugin.startTracking(); // Call the function to start tracking
          _trackingBtnText = "STOP TRACKING";
        } on PlatformException catch (e) {
          setState(() {
            _stateString = "Occur PlatformException (${e.message})";
          });
        }
      } else {
        try {
          _seesoPlugin.stopTracking(); // Call the function to stop tracking
          _trackingBtnText = "START TRACKING";
        } on PlatformException catch (e) {
          setState(() {
            _stateString = "Occur PlatformException (${e.message})";
          });
        }
      }
      setState(() {
        _trackingBtnText = _trackingBtnText;
      });
    }
  }

  void _calibrationBtnPressed() {
    if (_isInitialied) {
      try {
        _seesoPlugin.startCalibration(CalibrationMode.FIVE);
        setState(() {
          _isCaliMode = true;
        });
      } on PlatformException catch (e) {
        setState(() {
          _stateString = "Occur PlatformException (${e.message})";
        });
      }
    }
  }

  void listenEvents() {
    _seesoPlugin.getGazeEvent().listen((event) {
      GazeInfo info = GazeInfo(event);

      if (info.trackingState == TrackingState.SUCCESS) {
        setState(() {
          _x = info.x;
          _y = info.y;
          _gazeColor = Colors.green;
        });
      } else {
        setState(() {
          _gazeColor = Colors.red;
        });
      }
    });
    _seesoPlugin.getStatusEvent().listen((event) {
      StatusInfo statusInfo = StatusInfo(event);
      if (statusInfo.type == StatusType.START) {
        setState(() {
          _stateString = "start Tracking";
          _showingGaze = true;
        });
      } else {
        setState(() {
          _stateString = "stop Trakcing : ${statusInfo.stateErrorType}";
          _showingGaze = false;
        });
      }
    });

    _seesoPlugin.getCalibrationEvent().listen((event) {
      CalibrationInfo caliInfo = CalibrationInfo(event);
      if (caliInfo.type == CalibrationType.CALIBRATION_NEXT_XY) {
        setState(() {
          _nextX = caliInfo.nextX!;
          _nextY = caliInfo.nextY!;
          _calibrationProgress = 0.0;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          _seesoPlugin.startCollectSamples();
        });
      } else if (caliInfo.type == CalibrationType.CALIBRATION_PROGRESS) {
        setState(() {
          _calibrationProgress = caliInfo.progress!;
        });
      } else if (caliInfo.type == CalibrationType.CALIBRATION_FINISHED) {
        setState(() {
          _isCaliMode = false;
        });
      }
    });
  }

  Future<void> getSeeSoVersion() async {
    String? seesoVersion;
    try {
      seesoVersion = await _seesoPlugin.getSeeSoVersion();
    } on PlatformException {
      seesoVersion = 'Failed to get SeeSo version';
    }

    if (!mounted) return;

    setState(() {
      _version = seesoVersion!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: null, // Hide the AppBar
        body: Stack(
          children: <Widget>[
            if (!_isCaliMode)
              Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('SeeSo version: $_version'),
                  Text('App has CameraPermission: $_hasCameraPermissionString'),
                  Text('SeeSo initState : $_stateString'),
                  const SizedBox(
                      height: 20), // Adding spacing between Text and Button
                  if (_isInitialied)
                    ElevatedButton(
                      onPressed: _trackingBtnPressed,
                      child: Text(_trackingBtnText),
                    ),
                  if (_isInitialied && _showingGaze)
                    ElevatedButton(
                        onPressed: _calibrationBtnPressed,
                        child: const Text("START CALIBRATION"))
                ],
              )),
            if (_showingGaze && !_isCaliMode)
              Positioned(
                  left: _x - 5,
                  top: _y - 5,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _gazeColor,
                      shape: BoxShape.circle,
                    ),
                  )),
            if (_isCaliMode)
              Positioned(
                  left: _nextX - 10,
                  top: _nextY - 10,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: _calibrationProgress,
                      backgroundColor: Colors.grey,
                    ),
                  ))
          ],
        ),
      ),
    );
  }
}
