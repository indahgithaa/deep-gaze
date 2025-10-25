// File: lib/pages/saved_notes_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/global_seeso_service.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../widgets/gaze_overlay_manager.dart';
import '../models/lecture_note.dart';
import 'note_detail_page.dart';

class SavedNotesPage extends StatefulWidget {
  final List<LectureNote> savedNotes;

  const SavedNotesPage({super.key, required this.savedNotes});

  @override
  State<SavedNotesPage> createState() => _SavedNotesPageState();
}

class _SavedNotesPageState extends State<SavedNotesPage>
    with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStart;

  // Config dwell times
  static const int _backDwellMs = 1000;
  static const int _buttonDwellMs = 1500;
  static const int _dwellUpdateMs = 50;

  // Hover grace for back button
  static const int _hoverGraceMs = 120;
  Timer? _hoverGraceTimer;

  // Search/sort state
  String _searchQuery = '';
  String _sortBy = 'recent';
  final ScrollController _scrollController = ScrollController();

  bool _boundsReady = false;

  // mixin overrides
  @override
  double get boundsUpdateDelay => 150.0;
  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('saved_notes', _onEyeUpdate);

    _registerKeys();
    GazeOverlayManager.instance.attach(context);
    GazeOverlayManager.instance.update(cursor: Offset.zero, visible: false);

    _initializeEyeTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      updateBoundsAfterBuild();
      _boundsReady = true;
    });
  }

  void _registerKeys() {
    generateKeyForElement('back_button');
    generateKeyForElement('search_button');
    generateKeyForElement('sort_recent');
    generateKeyForElement('sort_oldest');
    generateKeyForElement('sort_title');
    generateKeyForElement('sort_duration');
    for (int i = 0; i < widget.savedNotes.length; i++) {
      generateKeyForElement('note_$i');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hoverGraceTimer?.cancel();
    _dwellTimer?.cancel();
    _scrollController.dispose();
    _eyeTrackingService.removePage('saved_notes');
    clearBounds();
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
    GazeOverlayManager.instance.update(
      cursor: gaze,
      visible: _eyeTrackingService.isTracking,
      progress: _currentDwellingElement != null ? _dwellProgress : null,
    );

    String? hovered = getElementAtPoint(gaze);

    // small inflated area for back button
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
    int dwell = _buttonDwellMs;

    switch (id) {
      case 'back_button':
        dwell = _backDwellMs;
        action = _goBack;
        break;
      case 'search_button':
        action = _showSearch;
        break;
      case 'sort_recent':
        action = () => _changeSort('recent');
        break;
      case 'sort_oldest':
        action = () => _changeSort('oldest');
        break;
      case 'sort_title':
        action = () => _changeSort('title');
        break;
      case 'sort_duration':
        action = () => _changeSort('duration');
        break;
      default:
        if (id.startsWith('note_')) {
          final i = int.parse(id.substring(5));
          final notes = _filtered();
          if (i < notes.length) {
            action = () => _openNote(notes[i]);
          }
        }
    }

    if (action != null) _startDwell(id, action, dwell);
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

  void _showSearch() {
    _stopDwell();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Search Notes'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Search by title or content...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
    );
  }

  void _changeSort(String type) {
    _stopDwell();
    setState(() => _sortBy = type);
  }

  void _openNote(LectureNote n) {
    _stopDwell();
    _eyeTrackingService.removePage('saved_notes');
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => NoteDetailPage(note: n)))
        .then((_) {
      if (!_isDisposed && mounted) {
        _eyeTrackingService.setActivePage('saved_notes', _onEyeUpdate);
        updateBoundsAfterBuild();
      }
    });
  }

  // ===================== Data Helpers =====================
  List<LectureNote> _filtered() {
    var notes = widget.savedNotes;
    if (_searchQuery.isNotEmpty) {
      notes = notes
          .where((n) =>
              n.title.toLowerCase().contains(_searchQuery) ||
              n.content.toLowerCase().contains(_searchQuery))
          .toList();
    }
    switch (_sortBy) {
      case 'oldest':
        notes.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'title':
        notes.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'duration':
        notes.sort((a, b) => b.duration.compareTo(a.duration));
        break;
      default:
        notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return notes;
  }

  String _fmtDur(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  String _fmtDate(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ===================== UI =====================
  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
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
                child: Text('Saved Notes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
              Container(
                key: generateKeyForElement('search_button'),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortButton(String type, String label, IconData icon) {
    final sel = _sortBy == type;
    final dwell = _currentDwellingElement == 'sort_$type';
    return Container(
      key: generateKeyForElement('sort_$type'),
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        elevation: dwell ? 4 : (sel ? 2 : 1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: sel
                ? Colors.blue.shade600
                : (dwell ? Colors.blue.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: dwell
                  ? Colors.blue.shade300
                  : (sel ? Colors.blue.shade200 : Colors.grey.shade300),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              if (dwell)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _dwellProgress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        sel ? Colors.white : Colors.blue.shade600),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 16,
                      color: sel
                          ? Colors.white
                          : (dwell
                              ? Colors.blue.shade600
                              : Colors.grey.shade600)),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        color: sel
                            ? Colors.white
                            : (dwell
                                ? Colors.blue.shade600
                                : Colors.grey.shade700),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noteCard(LectureNote note, int index) {
    final dwell = _currentDwellingElement == 'note_$index';
    return Container(
      key: generateKeyForElement('note_$index'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: dwell ? 8 : 2,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: dwell ? Colors.blue.shade400 : Colors.grey.shade200,
              width: dwell ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.note_alt,
                      color: Colors.blue.shade600, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.title,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.schedule,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(_fmtDur(note.duration),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(_fmtDate(note.timestamp),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                      ]),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 16,
                    color: dwell ? Colors.blue.shade600 : Colors.grey.shade400),
              ]),
              const SizedBox(height: 16),
              Text(
                note.content.length > 150
                    ? '${note.content.substring(0, 150)}...'
                    : note.content,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.text_fields,
                          size: 12, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text('${note.content.split(' ').length} words',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500)),
                    ])),
                const Spacer(),
                if (dwell)
                  Row(children: [
                    Icon(Icons.remove_red_eye,
                        size: 12, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text('Look to open',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    SizedBox(
                        width: 40,
                        height: 3,
                        child: LinearProgressIndicator(
                            value: _dwellProgress,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600)))
                  ]),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    final notes = _filtered();
    final totalTime = notes.fold(Duration.zero, (a, n) => a + n.duration);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        _header(),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
                child: Column(children: [
              Text('${notes.length}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const Text('Notes',
                  style: TextStyle(fontSize: 12, color: Colors.black54))
            ])),
            Container(width: 1, height: 40, color: Colors.grey.shade300),
            Expanded(
                child: Column(children: [
              Text(_fmtDur(totalTime),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const Text('Total Time',
                  style: TextStyle(fontSize: 12, color: Colors.black54))
            ])),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20, top: 10),
          child: const Text('Sort by:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            _sortButton('recent', 'Recent', Icons.access_time),
            _sortButton('oldest', 'Oldest', Icons.history),
            _sortButton('title', 'Title', Icons.sort_by_alpha),
            _sortButton('duration', 'Duration', Icons.timer),
          ]),
        ),
        Expanded(
          child: notes.isEmpty
              ? Center(
                  child: Text(
                      _searchQuery.isNotEmpty
                          ? 'No notes found for "$_searchQuery"'
                          : 'No notes saved yet',
                      style: const TextStyle(fontSize: 16, color: Colors.grey)),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: notes.length,
                  itemBuilder: (_, i) => _noteCard(notes[i], i),
                ),
        ),
      ]),
    );
  }
}
