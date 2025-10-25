// File: lib/pages/profile_page.dart
import 'package:flutter/material.dart';
import 'dart:async';

import '../services/global_seeso_service.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../widgets/gaze_overlay_manager.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStart;

  // Config dwell times
  static const int _backDwellMs = 1000; // back 1s
  static const int _itemDwellMs = 1500; // item 1.5s
  static const int _dwellUpdateMs = 50;

  // Hover grace for back button agar tidak mudah batal saat mata goyang
  static const int _hoverGraceMs = 120;
  Timer? _hoverGraceTimer;

  bool _boundsReady = false;

  // ResponsiveBoundsMixin overrides
  @override
  double get boundsUpdateDelay => 150.0;
  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    // Pakai sistem fokus halaman
    _eyeTrackingService.setActivePage('profile_page', _onEyeUpdate);

    _registerKeys();

    // Attach HUD (overlay global)
    GazeOverlayManager.instance.attach(context);
    GazeOverlayManager.instance.update(cursor: Offset.zero, visible: false);

    _initializeEyeTracking();

    // Hitung bounds aman setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      updateBoundsAfterBuild();
      _boundsReady = true;
    });
  }

  void _registerKeys() {
    // header
    generateKeyForElement('back_button');

    // fitur
    generateKeyForElement('feat_user_info');
    generateKeyForElement('feat_settings');
    generateKeyForElement('feat_eye_settings');
    generateKeyForElement('feat_help');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hoverGraceTimer?.cancel();
    _dwellTimer?.cancel();

    _eyeTrackingService.removePage('profile_page');
    clearBounds();

    // Sembunyikan HUD ketika keluar
    GazeOverlayManager.instance.hide();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateBoundsAfterBuild();
  }

  Future<void> _initializeEyeTracking() async {
    try {
      await _eyeTrackingService.initialize(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Eye tracking initialization failed: $e"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ===================== Eye Update =====================
  void _onEyeUpdate() {
    if (!mounted || _isDisposed || !_boundsReady) return;

    final gaze = Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // Update HUD global (cursor & progress)
    GazeOverlayManager.instance.update(
      cursor: gaze,
      visible: _eyeTrackingService.isTracking,
      progress: _currentDwellingElement != null ? _dwellProgress : null,
    );

    // Deteksi elemen yang sedang ditatap
    String? hovered = getElementAtPoint(gaze);

    // Perbesar hitbox tombol back sedikit (inflasi 10px)
    final backRect = getBoundsForElement('back_button');
    if (backRect != null && backRect.inflate(10).contains(gaze)) {
      hovered = 'back_button';
    }

    if (hovered != null) {
      _hoverGraceTimer?.cancel();
      if (hovered != _currentDwellingElement) {
        _handleHover(hovered);
      }
    } else if (_currentDwellingElement != null) {
      if (_currentDwellingElement == 'back_button') {
        // Grace kecil agar tidak langsung batal saat mata sedikit keluar
        _hoverGraceTimer?.cancel();
        _hoverGraceTimer =
            Timer(Duration(milliseconds: _hoverGraceMs), _stopDwell);
      } else {
        _stopDwell();
      }
    }
  }

  void _handleHover(String id) {
    VoidCallback? action;
    int dwellMs = _itemDwellMs;

    switch (id) {
      case 'back_button':
        dwellMs = _backDwellMs;
        action = _goBack;
        break;
      case 'feat_user_info':
        action = () => _comingSoon('User Information');
        break;
      case 'feat_settings':
        action = () => _comingSoon('App Settings');
        break;
      case 'feat_eye_settings':
        action = () => _comingSoon('Eye Tracking Settings');
        break;
      case 'feat_help':
        action = () => _comingSoon('Help & Support');
        break;
      default:
        break;
    }

    if (action != null) _startDwell(id, action, dwellMs);
  }

  void _startDwell(String id, VoidCallback action, int dwellMs) {
    _stopDwell();
    setState(() {
      _currentDwellingElement = id;
      _dwellProgress = 0.0;
    });
    _dwellStart = DateTime.now();
    _dwellTimer =
        Timer.periodic(Duration(milliseconds: _dwellUpdateMs), (timer) {
      if (!mounted || _isDisposed || _currentDwellingElement != id) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_dwellStart!).inMilliseconds;
      final p = (elapsed / dwellMs).clamp(0.0, 1.0);
      setState(() => _dwellProgress = p);
      if (p >= 1.0) {
        timer.cancel();
        action();
      }
    });
  }

  void _stopDwell() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    if (mounted) {
      setState(() {
        _currentDwellingElement = null;
        _dwellProgress = 0.0;
      });
    }
  }

  // ===================== Actions =====================
  void _goBack() {
    _stopDwell();
    Navigator.of(context).pop();
  }

  void _comingSoon(String feature) {
    _stopDwell();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming soon'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // ===================== UI helpers =====================
  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Back (dwell 1s, progress di bawah icon)
              Container(
                key: generateKeyForElement('back_button'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    if (_currentDwellingElement == 'back_button')
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _dwellProgress,
                          child: Container(height: 3, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const Expanded(
                child: Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Icon kanan (non-interaktif untuk saat ini)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    const Icon(Icons.visibility, color: Colors.blue, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureItem({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final dwell = _currentDwellingElement == id;

    return Container(
      key: generateKeyForElement(id),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        elevation: dwell ? 4 : 1,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dwell ? Colors.blue.shade400 : Colors.grey.shade300,
              width: dwell ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              if (dwell)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: _dwellProgress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade600,
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.blue.shade600, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            )),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            )),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16,
                      color:
                          dwell ? Colors.blue.shade600 : Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileBody() {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profile Page',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 32),

                // Feature list (gaze dwellable)
                _featureItem(
                  id: 'feat_user_info',
                  icon: Icons.person_outline,
                  title: 'User Information',
                  subtitle: 'View and edit personal details',
                ),
                const SizedBox(height: 16),
                _featureItem(
                  id: 'feat_settings',
                  icon: Icons.settings,
                  title: 'App Settings',
                  subtitle: 'Customize app preferences',
                ),
                const SizedBox(height: 16),
                _featureItem(
                  id: 'feat_eye_settings',
                  icon: Icons.visibility_outlined,
                  title: 'Eye Tracking Settings',
                  subtitle: 'Calibration and tracking preferences',
                ),
                const SizedBox(height: 16),
                _featureItem(
                  id: 'feat_help',
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get help with using the app',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _header(),
          _profileBody(),
        ],
      ),
    );
  }
}
