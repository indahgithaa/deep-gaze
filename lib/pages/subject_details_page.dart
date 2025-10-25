// File: lib/pages/subject_details_page.dart
import 'package:flutter/material.dart';
import 'dart:async';

import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../mixins/responsive_bounds_mixin.dart';
import 'quiz_page.dart';
import 'tugas_page.dart';
import 'material_reader_page.dart';

// HUD cursor/overlay global (selalu di root Overlay)
import '../widgets/gaze_overlay_manager.dart';
// (opsional) jika kamu pakai jembatan navigasi berbasis gaze
import '../widgets/nav_gaze_bridge.dart';

class SubjectDetailsPage extends StatefulWidget {
  final Subject subject;

  const SubjectDetailsPage({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectDetailsPage> createState() => _SubjectDetailsPageState();
}

class _SubjectDetailsPageState extends State<SubjectDetailsPage>
    with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // ===== Dwell state =====
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // ===== Durasi dwell =====
  static const int _dwellUpdateIntervalMs = 50;
  static const int _dwellBackMs = 1000; // back: 1.0s
  static const int _dwellTabMs = 1500; // tabs & cards: 1.5s

  // ===== Anti-jitter back button =====
  static const int _hoverGraceMs = 120; // toleransi lepas hover sebentar
  static const double _backInflatePx = 12.0; // perluas hitbox back (sticky)
  Timer? _hoverGraceTimer;

  // ===== Tab terpilih =====
  String _selectedTab = 'Semua';

  // ===== ResponsiveBoundsMixin config =====
  @override
  double get boundsUpdateDelay => 200.0; // jeda kalkulasi bounds

  @override
  bool get enableBoundsLogging => true; // aktifkan log (bisa dimatikan)

  @override
  void initState() {
    super.initState();

    _eyeTrackingService = GlobalSeesoService();
    // Registrasi halaman + callback
    _eyeTrackingService.setActivePage('subject_details', _onEyeTrackingUpdate);

    _initializeEyeTracking();

    // Daftarkan keys awal sesuai filter aktif
    _rebuildBoundsForCurrentFilter();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _hoverGraceTimer?.cancel();
    _dwellTimer = null;

    // Lepas callback halaman
    _eyeTrackingService.removePage('subject_details');

    // Bersihkan cache bounds
    clearBounds();

    // Sembunyikan HUD bila ini halaman terakhir yang update
    GazeOverlayManager.instance.hide();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateBoundsAfterBuild();
  }

  // =========================================================
  // =============== Bounds Registrations ====================
  // =========================================================
  void _registerStaticKeys() {
    // Back button & tab ids
    generateKeyForElement('back_button');
    generateKeyForElement('tab_semua');
    generateKeyForElement('tab_materi');
    generateKeyForElement('tab_tugas_kuis');
  }

  void _registerFilteredTopicKeys() {
    for (final topic in _getFilteredTopics()) {
      generateKeyForElement(topic.id);
    }
  }

  void _rebuildBoundsForCurrentFilter() {
    // Penting untuk mencegah overlap bounds dari mode "Semua"
    // saat pindah ke filter Materi / Tugas & Kuis
    clearBounds();
    _registerStaticKeys();
    _registerFilteredTopicKeys();
    updateBoundsAfterBuild();
  }

  // =========================================================
  // =================== Dwell Helpers =======================
  // =========================================================
  void _startDwellTimerWithDuration(
    String elementId,
    VoidCallback action, {
    required int dwellMs,
  }) {
    if (_isDisposed || !mounted) return;
    if (_currentDwellingElement == elementId) return;

    _stopDwellTimer();

    setState(() {
      _currentDwellingElement = elementId;
      _dwellProgress = 0.0;
    });

    _dwellStartTime = DateTime.now();
    _dwellTimer = Timer.periodic(
      Duration(milliseconds: _dwellUpdateIntervalMs),
      (timer) {
        if (_isDisposed || !mounted || _currentDwellingElement != elementId) {
          timer.cancel();
          return;
        }

        final elapsed =
            DateTime.now().difference(_dwellStartTime!).inMilliseconds;
        final progress = (elapsed / dwellMs).clamp(0.0, 1.0);

        setState(() => _dwellProgress = progress);

        if (progress >= 1.0) {
          timer.cancel();
          if (mounted && !_isDisposed) action();
        }
      },
    );
  }

  void _stopDwellTimer() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = null;
        _dwellProgress = 0.0;
      });
    }
  }

  void _maybeStopDwellTimerWithGrace(String? leavingId) {
    // Untuk tombol back, beri grace period agar timer tak gampang batal
    if (leavingId == 'back_button') {
      _hoverGraceTimer?.cancel();
      _hoverGraceTimer = Timer(Duration(milliseconds: _hoverGraceMs), () {
        if (_currentDwellingElement == leavingId) {
          _stopDwellTimer();
        }
      });
    } else {
      _stopDwellTimer();
    }
  }

  // =========================================================
  // =================== Eye Tracking ========================
  // =========================================================
  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      await _eyeTrackingService.initialize(context);
      _eyeTrackingService.debugPrintStatus();
    } catch (e) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Eye tracking initialization failed: $e"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // (opsional) update jembatan navigasi
    NavGazeBridge.instance
        .update(currentGazePoint, _eyeTrackingService.isTracking);

    // Update HUD global (cursor)
    GazeOverlayManager.instance.update(
      cursor: currentGazePoint,
      visible: _eyeTrackingService.isTracking,
      highlight: null, // bisa diisi Rect bila mau highlight elemen
    );

    // 1) Hit-test normal
    String? hovered = getElementAtPoint(currentGazePoint);

    // 2) Sticky override khusus tombol back:
    //    jika gaze masih di sekitar back (inflate), paksa hovered = 'back_button'
    final backRect = getBoundsForElement('back_button');
    if (backRect != null &&
        backRect.inflate(_backInflatePx).contains(currentGazePoint)) {
      hovered = 'back_button';
    }

    // 3) Transisi hover -> start/stop dwell
    if (hovered != null) {
      _hoverGraceTimer?.cancel(); // kembali masuk area: hentikan grace cancel

      if (_currentDwellingElement != hovered) {
        // Prioritas tombol back
        if (hovered == 'back_button') {
          _startDwellTimerWithDuration(hovered, _goBack, dwellMs: _dwellBackMs);
        }
        // Tabs
        else if (hovered == 'tab_semua') {
          _startDwellTimerWithDuration(hovered, () {
            setState(() => _selectedTab = 'Semua');
            _rebuildBoundsForCurrentFilter();
          }, dwellMs: _dwellTabMs);
        } else if (hovered == 'tab_materi') {
          _startDwellTimerWithDuration(hovered, () {
            setState(() => _selectedTab = 'Materi');
            _rebuildBoundsForCurrentFilter();
          }, dwellMs: _dwellTabMs);
        } else if (hovered == 'tab_tugas_kuis') {
          _startDwellTimerWithDuration(hovered, () {
            setState(() => _selectedTab = 'Tugas & Kuis');
            _rebuildBoundsForCurrentFilter();
          }, dwellMs: _dwellTabMs);
        }
        // Topic (filtered list saja karena bounds sudah dibangun ulang)
        else {
          final list = _getFilteredTopics();
          if (list.isNotEmpty) {
            final topic = list.firstWhere(
              (t) => t.id == hovered,
              orElse: () => list.first,
            );
            _startDwellTimerWithDuration(
              hovered,
              () => _handleTopicSelection(topic),
              dwellMs: _dwellTabMs,
            );
          }
        }
      }
    } else {
      // Tidak hovering apa pun: jangan langsung stop kalau sebelumnya back_button
      if (_currentDwellingElement != null) {
        _maybeStopDwellTimerWithGrace(_currentDwellingElement);
      }
    }

    if (mounted && !_isDisposed) setState(() {});
  }

  // =========================================================
  // ================= Navigation helpers ====================
  // =========================================================
  void _goBack() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    // Lepas callback halaman sebelum keluar
    _eyeTrackingService.removePage('subject_details');
    Navigator.of(context).pop();
  }

  void _handleTopicSelection(Topic topic) {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    // Lepas callback halaman sebelum push
    _eyeTrackingService.removePage('subject_details');

    Future<void> _afterReturn() async {
      if (!_isDisposed && mounted) {
        // Re-aktivasi halaman ini setelah kembali
        _eyeTrackingService.setActivePage(
            'subject_details', _onEyeTrackingUpdate);
        _rebuildBoundsForCurrentFilter();
      }
    }

    if (topic.type == 'Kuis' && topic.questions != null) {
      Navigator.of(context)
          .push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => QuizPage(
                subject: widget.subject,
                topic: topic,
                questions: topic.questions!,
              ),
              transitionsBuilder: (_, animation, __, child) => SlideTransition(
                position: animation.drive(
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero),
                ),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          )
          .then((_) => _afterReturn());
    } else if (topic.type == 'Tugas') {
      Navigator.of(context)
          .push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => TugasPage(
                subject: widget.subject,
                topic: topic,
              ),
              transitionsBuilder: (_, animation, __, child) => SlideTransition(
                position: animation.drive(
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero),
                ),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          )
          .then((_) => _afterReturn());
    } else if (topic.type == 'Materi') {
      Navigator.of(context)
          .push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => MaterialReaderPage(
                subject: widget.subject,
                topic: topic,
              ),
              transitionsBuilder: (_, animation, __, child) => SlideTransition(
                position: animation.drive(
                  Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero),
                ),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 300),
            ),
          )
          .then((_) => _afterReturn());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${topic.name} - ${topic.type} will be available soon!'),
          duration: const Duration(seconds: 2),
          backgroundColor: topic.isCompleted ? Colors.green : Colors.blue,
        ),
      );
      // Re-aktivasi langsung karena tidak navigasi
      if (!_isDisposed && mounted) {
        _eyeTrackingService.setActivePage(
            'subject_details', _onEyeTrackingUpdate);
        _rebuildBoundsForCurrentFilter();
      }
    }
  }

  // =========================================================
  // ==================== Data helpers =======================
  // =========================================================
  List<Topic> _getFilteredTopics() {
    switch (_selectedTab) {
      case 'Materi':
        return widget.subject.topics.where((t) => t.type == 'Materi').toList();
      case 'Tugas & Kuis':
        return widget.subject.topics
            .where((t) => t.type == 'Tugas' || t.type == 'Kuis')
            .toList();
      default:
        return widget.subject.topics;
    }
  }

  // =========================================================
  // ====================== UI helpers =======================
  // =========================================================
  Widget _buildTabItem({
    required String id,
    required String label,
    required bool selected,
  }) {
    final isDwellingThis = _currentDwellingElement == id;

    return Expanded(
      child: Container(
        key: generateKeyForElement(id), // key untuk hit-test dwell
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? null
              : Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            // Indikator progres dwell (opsional)
            if (isDwellingThis)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _dwellProgress, // 0..1
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard(Topic topic) {
    final isCurrentlyDwelling = _currentDwellingElement == topic.id;
    IconData iconData;
    Color iconColor;

    switch (topic.type) {
      case 'Tugas':
        iconData = Icons.assignment;
        iconColor = Colors.blue;
        break;
      case 'Materi':
        iconData = Icons.book;
        iconColor = Colors.green;
        break;
      case 'Kuis':
        iconData = Icons.quiz;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.circle;
        iconColor = Colors.grey;
    }

    return Container(
      key: generateKeyForElement(topic.id),
      margin: const EdgeInsets.only(bottom: 15),
      child: Material(
        elevation: isCurrentlyDwelling ? 8 : 2,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
            border: isCurrentlyDwelling
                ? Border.all(color: iconColor, width: 2)
                : Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Stack(
            children: [
              if (isCurrentlyDwelling)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    height: 3,
                    width: (MediaQuery.of(context).size.width - 80) *
                        _dwellProgress,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: iconColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                topic.type,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: iconColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (topic.isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getActionHint(topic.type),
                        style: TextStyle(
                          fontSize: 10,
                          color: iconColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getActionHint(String topicType) {
    switch (topicType) {
      case 'Materi':
        return 'Read';
      case 'Tugas':
        return 'Essay';
      case 'Kuis':
        return 'Options';
      default:
        return 'Open';
    }
  }

  // =========================================================
  // ========================= UI ============================
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final filteredTopics = _getFilteredTopics();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.white),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF5A8DEE), Color(0xFF32CCBC)],
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Back button + dwell progress + sticky hitbox (via mixin bounds)
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: Container(
                                key: generateKeyForElement('back_button'),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    // Dwell indicator (garis tipis di atas)
                                    if (_currentDwellingElement ==
                                        'back_button')
                                      Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: _dwellProgress,
                                          child: Container(
                                            height: 3,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                'Ruang Kelas',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.visibility,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Center(
                                child: Text(
                                  widget.subject.iconName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.subject.teacher,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.subject.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tabs (dwell 1.5s via key)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    child: Row(
                      children: [
                        _buildTabItem(
                          id: 'tab_semua',
                          label: 'Semua',
                          selected: _selectedTab == 'Semua',
                        ),
                        _buildTabItem(
                          id: 'tab_materi',
                          label: 'Materi',
                          selected: _selectedTab == 'Materi',
                        ),
                        _buildTabItem(
                          id: 'tab_tugas_kuis',
                          label: 'Tugas & Kuis',
                          selected: _selectedTab == 'Tugas & Kuis',
                        ),
                      ],
                    ),
                  ),

                  // Topics
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredTopics.length,
                      itemBuilder: (context, index) =>
                          _buildTopicCard(filteredTopics[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tidak ada gaze widget lokal—HUD ditangani oleh GazeOverlayManager (global)
        ],
      ),
    );
  }
}
