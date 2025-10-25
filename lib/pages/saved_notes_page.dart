// File: lib/pages/saved_notes_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../models/lecture_note.dart'; // Import the shared model
import 'note_detail_page.dart';

class SavedNotesPage extends StatefulWidget {
  final List<LectureNote> savedNotes;

  const SavedNotesPage({
    super.key,
    required this.savedNotes,
  });

  @override
  State<SavedNotesPage> createState() => _SavedNotesPageState();
}

class _SavedNotesPageState extends State<SavedNotesPage>
    with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _dwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Search and filter state
  String _searchQuery = '';
  String _sortBy = 'recent'; // 'recent', 'oldest', 'title', 'duration'
  final ScrollController _scrollController = ScrollController();

  // Override mixin configuration
  @override
  double get boundsUpdateDelay => 150.0;

  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    print("DEBUG: SavedNotesPage initState");
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('saved_notes', _onEyeTrackingUpdate);

    _initializeElementKeys();
    _initializeEyeTracking();
    updateBoundsAfterBuild();
  }

  void _initializeElementKeys() {
    // Generate keys for navigation and control elements
    generateKeyForElement('back_button');
    generateKeyForElement('search_button');
    generateKeyForElement('sort_recent');
    generateKeyForElement('sort_oldest');
    generateKeyForElement('sort_title');
    generateKeyForElement('sort_duration');

    // Generate keys for each note item
    for (int i = 0; i < widget.savedNotes.length; i++) {
      generateKeyForElement('note_$i');
    }

    print("DEBUG: Generated ${elementCount} element keys for SavedNotesPage");
    updateBoundsAfterBuild();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _scrollController.dispose();
    _eyeTrackingService.removePage('saved_notes');
    clearBounds();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateBoundsAfterBuild();
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    String? hoveredElement = getElementAtPoint(currentGazePoint);

    if (hoveredElement != null) {
      if (_currentDwellingElement != hoveredElement) {
        print("DEBUG: SavedNotesPage - Started dwelling on: $hoveredElement");
        _handleElementHover(hoveredElement);
      }
    } else {
      if (_currentDwellingElement != null) {
        _stopDwellTimer();
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  void _handleElementHover(String elementId) {
    VoidCallback action;

    if (elementId == 'back_button') {
      action = _goBack;
    } else if (elementId == 'search_button') {
      action = _showSearch;
    } else if (elementId.startsWith('sort_')) {
      final sortType = elementId.substring(5);
      action = () => _changeSortBy(sortType);
    } else if (elementId.startsWith('note_')) {
      final noteIndex = int.parse(elementId.substring(5));
      final filteredNotes = _getFilteredAndSortedNotes();
      if (noteIndex < filteredNotes.length) {
        final note = filteredNotes[noteIndex];
        action = () => _openNoteDetail(note);
      } else {
        return;
      }
    } else {
      return;
    }

    _startDwellTimer(elementId, action);
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      print("DEBUG: Initializing eye tracking in SavedNotesPage");
      await _eyeTrackingService.initialize(context);
      print("DEBUG: Eye tracking successfully initialized in SavedNotesPage");
    } catch (e) {
      print('Eye tracking initialization failed: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Eye tracking initialization failed: ${e.toString()}"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startDwellTimer(String elementId, VoidCallback action) {
    if (_isDisposed || !mounted) return;
    if (_currentDwellingElement == elementId) return;

    _stopDwellTimer();

    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = elementId;
        _dwellProgress = 0.0;
      });
    }

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
        final progress = (elapsed / _dwellTimeMs).clamp(0.0, 1.0);

        if (mounted && !_isDisposed) {
          setState(() {
            _dwellProgress = progress;
          });
        }

        if (progress >= 1.0) {
          timer.cancel();
          if (mounted && !_isDisposed) {
            action();
          }
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

  void _goBack() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    Navigator.of(context).pop();
  }

  void _showSearch() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Notes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search by title or content...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _changeSortBy(String sortType) {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    setState(() {
      _sortBy = sortType;
    });

    String sortName;
    switch (sortType) {
      case 'recent':
        sortName = 'Most Recent';
        break;
      case 'oldest':
        sortName = 'Oldest First';
        break;
      case 'title':
        sortName = 'Title A-Z';
        break;
      case 'duration':
        sortName = 'Duration';
        break;
      default:
        sortName = 'Recent';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sorted by: $sortName'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _openNoteDetail(LectureNote note) {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    // Remove current page from active listening
    _eyeTrackingService.removePage('saved_notes');

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => NoteDetailPage(note: note),
      ),
    )
        .then((_) {
      // Re-activate this page when returning
      if (!_isDisposed && mounted) {
        _eyeTrackingService.setActivePage('saved_notes', _onEyeTrackingUpdate);
        updateBoundsAfterBuild();
      }
    });
  }

  List<LectureNote> _getFilteredAndSortedNotes() {
    List<LectureNote> filteredNotes = widget.savedNotes;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredNotes = filteredNotes.where((note) {
        return note.title.toLowerCase().contains(_searchQuery) ||
            note.content.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'recent':
        filteredNotes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'oldest':
        filteredNotes.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        break;
      case 'title':
        filteredNotes.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'duration':
        filteredNotes.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }

    return filteredNotes;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatDate(DateTime date) {
    final months = [
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

    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSortButton(String sortType, String label, IconData icon) {
    final isSelected = _sortBy == sortType;
    final isCurrentlyDwelling = _currentDwellingElement == 'sort_$sortType';

    return Container(
      key: generateKeyForElement('sort_$sortType'),
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        elevation: isCurrentlyDwelling ? 4 : (isSelected ? 2 : 1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isSelected
                ? Colors.blue.shade600
                : (isCurrentlyDwelling ? Colors.blue.shade50 : Colors.white),
            border: isCurrentlyDwelling
                ? Border.all(color: Colors.blue.shade300, width: 2)
                : Border.all(color: Colors.grey.shade300),
          ),
          child: Stack(
            children: [
              if (isCurrentlyDwelling)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: _dwellProgress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          isSelected ? Colors.white : Colors.blue.shade600),
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isCurrentlyDwelling
                            ? Colors.blue.shade600
                            : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isCurrentlyDwelling
                              ? Colors.blue.shade600
                              : Colors.grey.shade700),
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

  Widget _buildNoteCard(LectureNote note, int index) {
    final isCurrentlyDwelling = _currentDwellingElement == 'note_$index';

    return Container(
      key: generateKeyForElement('note_$index'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: isCurrentlyDwelling ? 8 : 2,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: isCurrentlyDwelling
                ? Border.all(color: Colors.blue.shade400, width: 2)
                : Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            children: [
              // Progress indicator for dwell time
              if (isCurrentlyDwelling)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    height: 3,
                    width: (MediaQuery.of(context).size.width - 80) *
                        _dwellProgress,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Note content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.note_alt,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(note.duration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _formatDate(note.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: isCurrentlyDwelling
                            ? Colors.blue.shade600
                            : Colors.grey.shade400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preview:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.content.length > 150
                              ? '${note.content.substring(0, 150)}...'
                              : note.content,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.text_fields,
                              size: 12,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${note.content.split(' ').length} words',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isCurrentlyDwelling)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.remove_red_eye,
                                size: 12,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Look to open',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotes = _getFilteredAndSortedNotes();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          key: generateKeyForElement('back_button'),
                          onTap: _goBack,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Saved Notes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        GestureDetector(
                          key: generateKeyForElement('search_button'),
                          onTap: _showSearch,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.search,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stats row
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${filteredNotes.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Notes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                _formatDuration(
                                  filteredNotes.fold(
                                    Duration.zero,
                                    (total, note) => total + note.duration,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Total Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Main content area
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sort options
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sort by:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildSortButton('recent', 'Recent',
                                          Icons.access_time),
                                      _buildSortButton(
                                          'oldest', 'Oldest', Icons.history),
                                      _buildSortButton('title', 'Title',
                                          Icons.sort_by_alpha),
                                      _buildSortButton(
                                          'duration', 'Duration', Icons.timer),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Notes list
                          Expanded(
                            child: filteredNotes.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.note_add,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'No notes found for "${_searchQuery}"'
                                              : 'No notes saved yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'Try a different search term'
                                              : 'Record a lecture to create your first note',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                      bottom: 20,
                                    ),
                                    itemCount: filteredNotes.length,
                                    itemBuilder: (context, index) {
                                      return _buildNoteCard(
                                          filteredNotes[index], index);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gaze point indicator
          GazePointWidget(
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            isVisible: _eyeTrackingService.isTracking,
          ),

          // Status information
          // StatusInfoWidget(
          //   statusMessage: _eyeTrackingService.statusMessage,
          //   currentPage: 5,
          //   totalPages: 5,
          //   gazeX: _eyeTrackingService.gazeX,
          //   gazeY: _eyeTrackingService.gazeY,
          //   currentDwellingElement: _currentDwellingElement,
          //   dwellProgress: _dwellProgress,
          // ),
        ],
      ),
    );
  }
}
