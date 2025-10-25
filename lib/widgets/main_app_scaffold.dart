import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../pages/ruang_kelas.dart';
import '../pages/lecture_recorder_page.dart';
import '../pages/profile_page.dart';
import 'gaze_overlay_manager.dart';
import 'nav_gaze_bridge.dart';

class MainAppScaffold extends StatefulWidget {
  final int startIndex;
  const MainAppScaffold({super.key, this.startIndex = 0});

  @override
  State<MainAppScaffold> createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> {
  late int _index;
  late final PageController _pageController;

  // ===== Navbar hit-test & dwell =====
  final _navKeys = List<GlobalKey>.generate(3, (_) => GlobalKey());
  final GlobalKey _navBarKey = GlobalKey();
  Rect? _navBarRect;
  final List<Rect> _navItemBounds = [Rect.zero, Rect.zero, Rect.zero];

  int? _hoveredIndex;
  Timer? _dwellTimer;
  DateTime? _dwellStart;
  final Duration _dwellTime = const Duration(milliseconds: 1500);
  double _dwellProgress = 0.0;

  // Langganan ke NavGazeBridge
  void _onGazeBusChanged() {
    final pos = NavGazeBridge.instance.cursor;
    final tracking = NavGazeBridge.instance.isTracking;

    // Hit-test navbar
    final hit = _hitTestNav(pos);
    if (hit != _hoveredIndex) {
      _cancelDwell();
      _hoveredIndex = hit;
      _dwellProgress = 0.0;
    }

    if (_hoveredIndex != null && tracking) {
      _startDwellIfNeeded(() {
        _navigateTo(_hoveredIndex!);
        _hoveredIndex = null;
        _cancelDwell();
      });
    }

    // Kirim highlight + progress ke overlay (agar ada indikator 1.5s)
    GazeOverlayManager.instance.update(
      cursor: pos,
      visible: tracking,
      highlight:
          (_hoveredIndex != null) ? _navItemBounds[_hoveredIndex!] : null,
      progress: (_hoveredIndex != null) ? _dwellProgress : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, 2);
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeNavBounds());

    // Subscribe ke gaze bus
    NavGazeBridge.instance.addListener(_onGazeBusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeNavBounds());
  }

  @override
  void dispose() {
    NavGazeBridge.instance.removeListener(_onGazeBusChanged);
    _pageController.dispose();
    _cancelDwell();
    // Jangan hide overlay di sini — mungkin dipakai halaman lain juga
    super.dispose();
  }

  // ====== NAV ======
  void _navigateTo(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _pageController.jumpToPage(i);
  }

  // ====== DWELL ======
  void _startDwellIfNeeded(VoidCallback onComplete) {
    _dwellTimer ??= Timer.periodic(const Duration(milliseconds: 50), (t) {
      _dwellStart ??= DateTime.now();
      final elapsed = DateTime.now().difference(_dwellStart!);
      _dwellProgress =
          (elapsed.inMilliseconds / _dwellTime.inMilliseconds).clamp(0.0, 1.0);

      // Update progress bar di overlay
      final hi = _hoveredIndex;
      if (hi != null) {
        GazeOverlayManager.instance.update(
          cursor: NavGazeBridge.instance.cursor,
          visible: NavGazeBridge.instance.isTracking,
          highlight: _navItemBounds[hi],
          progress: _dwellProgress,
        );
      }

      if (_dwellProgress >= 1.0) {
        t.cancel();
        _dwellTimer = null;
        _dwellStart = null;
        _dwellProgress = 0.0;
        onComplete();
      }
      setState(() {});
    });
  }

  void _cancelDwell() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _dwellStart = null;
    _dwellProgress = 0.0;
    setState(() {});
  }

  // ====== HIT-TEST ======
  int? _hitTestNav(Offset p) {
    if (_navBarRect == null) return null;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final expanded = _navBarRect!.inflate(max(0, bottomInset - 1));
    if (!expanded.contains(p)) return null;

    for (var i = 0; i < _navItemBounds.length; i++) {
      if (_navItemBounds[i].contains(p)) return i;
    }
    return null;
  }

  void _computeNavBounds() {
    final navBox = _navBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (navBox != null && mounted) {
      final pos = navBox.localToGlobal(Offset.zero);
      _navBarRect = pos & navBox.size;
    }
    for (var i = 0; i < _navKeys.length; i++) {
      final box = _navKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final pos = box.localToGlobal(Offset.zero);
      _navItemBounds[i] = pos & box.size;
    }
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [RuangKelas(), LectureRecorderPage(), ProfilePage()],
      ),
      bottomNavigationBar: Material(
        key: _navBarKey,
        elevation: 8,
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                _NavItem(
                  key: _navKeys[0],
                  label: 'Home',
                  icon: Icons.home,
                  selected: _index == 0,
                  onTap: () => _navigateTo(0),
                ),
                _NavItem(
                  key: _navKeys[1],
                  label: 'Recorder',
                  icon: Icons.mic,
                  selected: _index == 1,
                  onTap: () => _navigateTo(1),
                ),
                _NavItem(
                  key: _navKeys[2],
                  label: 'Profile',
                  icon: Icons.person,
                  selected: _index == 2,
                  onTap: () => _navigateTo(2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.blue : Colors.black54;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
