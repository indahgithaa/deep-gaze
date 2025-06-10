// File: lib/pages/note_detail_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../mixins/responsive_bounds_mixin.dart';
import '../models/lecture_note.dart'; // Import from the shared model

class NoteDetailPage extends StatefulWidget {
  final LectureNote note;

  const NoteDetailPage({
    super.key,
    required this.note,
  });

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage>
    with ResponsiveBoundsMixin {
  late GlobalSeesoService _eyeTrackingService;
  bool _isDisposed = false;

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration
  static const int _navigationDwellTimeMs = 800;
  static const int _buttonDwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Reading state
  final ScrollController _scrollController = ScrollController();
  bool _isDarkMode = false;
  double _fontSize = 16.0;
  bool _isAutoScrolling = false;
  bool _isFavorite = false;

  // Auto-scroll configuration
  Timer? _autoScrollTimer;
  static const Duration _autoScrollSpeed = Duration(milliseconds: 50);

  // Navigation zone configuration
  final double _navigationZoneHeight = 60.0;
  final double _headerHeight = 120.0;

  // Override mixin configuration
  @override
  double get boundsUpdateDelay => 150.0;

  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    print("DEBUG: NoteDetailPage initState");
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.setActivePage('note_detail', _onEyeTrackingUpdate);

    _initializeElementKeys();
    _initializeEyeTracking();
    updateBoundsAfterBuild();
  }

  void _initializeElementKeys() {
    // Generate keys for all interactive elements
    generateKeyForElement('scroll_up_zone');
    generateKeyForElement('scroll_down_zone');
    generateKeyForElement('back_button');
    generateKeyForElement('dark_mode_button');
    generateKeyForElement('font_increase');
    generateKeyForElement('font_decrease');
    generateKeyForElement('favorite_button');
    generateKeyForElement('share_button');

    print("DEBUG: Generated ${elementCount} element keys using mixin");
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollController.dispose();

    _eyeTrackingService.removePage('note_detail');
    clearBounds();

    print("DEBUG: NoteDetailPage disposed");
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateBoundsAfterBuild();
  }

  void _stopAutoScrollIfNotInZone(String? hoveredElement) {
    if (_isAutoScrolling &&
        (hoveredElement == null || !hoveredElement.contains('scroll'))) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      _isAutoScrolling = false;
      print("DEBUG: Auto-scroll stopped - gaze left scroll zones");

      if (mounted) {
        setState(() {
          _isAutoScrolling = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-scroll stopped'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // Bounds validation
    final screenSize = MediaQuery.of(context).size;
    if (currentGazePoint.dx < 0 ||
        currentGazePoint.dy < 0 ||
        currentGazePoint.dx > screenSize.width ||
        currentGazePoint.dy > screenSize.height) {
      _stopAutoScrollIfNotInZone(null);
      return;
    }

    // Use mixin's precise hit detection
    String? hoveredElement = getElementAtPoint(currentGazePoint);

    // Check if we should stop auto-scrolling
    _stopAutoScrollIfNotInZone(hoveredElement);

    // Debug logging for navigation zones
    if (hoveredElement != null && hoveredElement.contains('scroll')) {
      print(
          "DEBUG: Gaze detected on $hoveredElement at (${currentGazePoint.dx.toInt()}, ${currentGazePoint.dy.toInt()})");
    }

    // Only process if hover state changed
    if (hoveredElement != _currentDwellingElement) {
      if (hoveredElement != null) {
        print("DEBUG: Started dwelling on: $hoveredElement");
        _handleElementHover(hoveredElement);
      } else if (_currentDwellingElement != null) {
        print("DEBUG: Stopped dwelling on: $_currentDwellingElement");
        _stopDwellTimer();
      }
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  void _handleElementHover(String elementId) {
    VoidCallback action;
    int dwellTime = _buttonDwellTimeMs;

    switch (elementId) {
      case 'back_button':
        action = _goBack;
        break;
      case 'dark_mode_button':
        action = _toggleDarkMode;
        break;
      case 'font_increase':
        action = _increaseFontSize;
        break;
      case 'font_decrease':
        action = _decreaseFontSize;
        break;
      case 'favorite_button':
        action = _toggleFavorite;
        break;
      case 'share_button':
        action = _shareNote;
        break;
      case 'scroll_up_zone':
        action = () => _startAutoScroll(isUp: true);
        dwellTime = _navigationDwellTimeMs;
        print("DEBUG: Scroll up action assigned");
        break;
      case 'scroll_down_zone':
        action = () => _startAutoScroll(isUp: false);
        dwellTime = _navigationDwellTimeMs;
        print("DEBUG: Scroll down action assigned");
        break;
      default:
        print("DEBUG: Unknown element: $elementId");
        return;
    }

    _startDwellTimer(elementId, action, dwellTime);
  }

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      print("DEBUG: Initializing eye tracking in NoteDetailPage");
      await _eyeTrackingService.initialize(context);
      print("DEBUG: Eye tracking successfully initialized in NoteDetailPage");
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

  void _startDwellTimer(
      String elementId, VoidCallback action, int dwellTimeMs) {
    if (_isDisposed || !mounted) return;
    if (_currentDwellingElement == elementId) return;

    _stopDwellTimer();

    if (mounted && !_isDisposed) {
      setState(() {
        _currentDwellingElement = elementId;
        _dwellProgress = 0.0;
      });
    }

    print("DEBUG: Starting dwell timer for: $elementId (${dwellTimeMs}ms)");
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
        final progress = (elapsed / dwellTimeMs).clamp(0.0, 1.0);

        if (mounted && !_isDisposed) {
          setState(() {
            _dwellProgress = progress;
          });
        }

        if (progress >= 1.0) {
          timer.cancel();
          print(
              "DEBUG: Dwell timer completed for: $elementId, executing action");
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

    // Stop auto-scroll if user looks away from scroll zones
    if (_isAutoScrolling &&
        _currentDwellingElement != null &&
        !_currentDwellingElement!.contains('scroll')) {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
      _isAutoScrolling = false;
      print("DEBUG: Auto-scroll stopped - user looked away from scroll zones");

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-scroll stopped'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.grey,
          ),
        );
      }
    }

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

  void _toggleDarkMode() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_isDarkMode ? 'Dark' : 'Light'} mode enabled'),
        duration: const Duration(seconds: 1),
        backgroundColor: _isDarkMode ? Colors.grey.shade800 : Colors.blue,
      ),
    );
  }

  void _increaseFontSize() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _fontSize = (_fontSize + 2.0).clamp(12.0, 28.0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Font size increased: ${_fontSize.toInt()}px'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _decreaseFontSize() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _fontSize = (_fontSize - 2.0).clamp(12.0, 28.0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Font size decreased: ${_fontSize.toInt()}px'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _toggleFavorite() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();
    setState(() {
      _isFavorite = !_isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
        duration: const Duration(seconds: 1),
        backgroundColor: _isFavorite ? Colors.red : Colors.grey,
      ),
    );
  }

  void _shareNote() {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share "${widget.note.title}"?'),
            const SizedBox(height: 16),
            const Text('Note content will be copied to clipboard.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Here you would implement actual sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note copied to clipboard'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _startAutoScroll({required bool isUp}) {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    if (_isAutoScrolling) {
      print("DEBUG: Already auto-scrolling, ignoring");
      return;
    }

    // Check if scrolling is possible
    if (!_scrollController.hasClients) {
      print("DEBUG: ScrollController has no clients");
      return;
    }

    final currentOffset = _scrollController.offset;
    final maxOffset = _scrollController.position.maxScrollExtent;

    if (isUp && currentOffset <= 0) {
      print("DEBUG: Already at top, cannot scroll up");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already at the top'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!isUp && currentOffset >= maxOffset) {
      print("DEBUG: Already at bottom, cannot scroll down");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already at the bottom'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAutoScrolling = true;
    });

    print("DEBUG: Starting smooth auto-scroll ${isUp ? 'UP' : 'DOWN'}");

    // Show feedback
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-scrolling ${isUp ? 'up' : 'down'}...'),
        duration: const Duration(seconds: 4),
        backgroundColor: isUp ? Colors.purple : Colors.teal,
      ),
    );

    // Smooth scrolling implementation
    const scrollIncrement = 3.0;
    const frameDuration = Duration(milliseconds: 16); // ~60 FPS

    _autoScrollTimer = Timer.periodic(frameDuration, (timer) {
      if (_isDisposed || !mounted || !_scrollController.hasClients) {
        timer.cancel();
        _isAutoScrolling = false;
        print("DEBUG: Auto-scroll stopped - disposed or no clients");
        return;
      }

      final currentOffset = _scrollController.offset;
      final maxOffset = _scrollController.position.maxScrollExtent;

      // Calculate new offset
      final scrollAmount = isUp ? -scrollIncrement : scrollIncrement;
      double newOffset = currentOffset + scrollAmount;

      // Check boundaries and stop if reached
      if (isUp && newOffset <= 0) {
        newOffset = 0;
        timer.cancel();
        _isAutoScrolling = false;
        print("DEBUG: Reached top of content");
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reached the top'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.purple,
            ),
          );
        }
      } else if (!isUp && newOffset >= maxOffset) {
        newOffset = maxOffset;
        timer.cancel();
        _isAutoScrolling = false;
        print("DEBUG: Reached bottom of content");
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reached the bottom'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.teal,
            ),
          );
        }
      }

      // Perform smooth scroll
      try {
        _scrollController.jumpTo(newOffset);
      } catch (e) {
        print("DEBUG: Error during scroll: $e");
        timer.cancel();
        _isAutoScrolling = false;
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
        }
      }
    });

    // Auto-stop after 8 seconds
    Timer(const Duration(seconds: 8), () {
      if (_autoScrollTimer?.isActive == true) {
        _autoScrollTimer?.cancel();
        _autoScrollTimer = null;
        if (mounted) {
          setState(() {
            _isAutoScrolling = false;
          });
          print("DEBUG: Auto-scroll timeout reached");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto-scroll stopped'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
    });
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildControlButtons() {
    return Positioned(
      top: 50,
      right: 20,
      child: Column(
        children: [
          // Dark mode toggle
          _buildControlButton(
            'dark_mode_button',
            _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            _isDarkMode ? Colors.yellow : Colors.indigo,
            'Toggle ${_isDarkMode ? 'Light' : 'Dark'} Mode',
          ),
          const SizedBox(height: 8),
          // Font size controls
          _buildControlButton(
            'font_increase',
            Icons.text_increase,
            Colors.green,
            'Increase Font',
          ),
          const SizedBox(height: 4),
          _buildControlButton(
            'font_decrease',
            Icons.text_decrease,
            Colors.orange,
            'Decrease Font',
          ),
          const SizedBox(height: 8),
          // Favorite button
          _buildControlButton(
            'favorite_button',
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            _isFavorite ? Colors.red : Colors.grey,
            _isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          ),
          const SizedBox(height: 4),
          // Share button
          _buildControlButton(
            'share_button',
            Icons.share,
            Colors.blue,
            'Share Note',
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      String elementId, IconData icon, Color color, String tooltip) {
    final isCurrentlyDwelling = _currentDwellingElement == elementId;
    final key = generateKeyForElement(elementId);

    return Container(
      key: key,
      width: 48,
      height: 48,
      child: Material(
        elevation: isCurrentlyDwelling ? 8 : 4,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isCurrentlyDwelling
                ? color.withOpacity(0.8)
                : color.withOpacity(0.1),
            border: Border.all(
              color: isCurrentlyDwelling ? color : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              if (isCurrentlyDwelling)
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: _dwellProgress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              Center(
                child: Icon(
                  icon,
                  color: isCurrentlyDwelling ? Colors.white : color,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note metadata
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.grey.shade800.withOpacity(0.5)
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _isDarkMode ? Colors.grey.shade600 : Colors.blue.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.note_alt,
                      color: _isDarkMode
                          ? Colors.blue.shade300
                          : Colors.blue.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.note.title,
                        style: TextStyle(
                          fontSize: _fontSize + 6,
                          fontWeight: FontWeight.bold,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: _isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Duration: ${_formatDuration(widget.note.duration)}',
                        style: TextStyle(
                          fontSize: _fontSize - 2,
                          color: _isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: _isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Recorded: ${_formatDate(widget.note.timestamp)}',
                        style: TextStyle(
                          fontSize: _fontSize - 2,
                          color: _isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.text_fields,
                      size: 16,
                      color: _isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Words: ${widget.note.content.split(' ').length}',
                      style: TextStyle(
                        fontSize: _fontSize - 2,
                        color: _isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          Container(
            height: 1,
            width: double.infinity,
            color: _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),

          const SizedBox(height: 24),

          // Note content
          Text(
            'Transcription:',
            style: TextStyle(
              fontSize: _fontSize + 2,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.note.content,
            style: TextStyle(
              fontSize: _fontSize,
              height: 1.6,
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),

          // Extra space for scrolling
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey.shade900 : Colors.white,
      body: Stack(
        children: [
          // Main content with proper layout
          Column(
            children: [
              // Header
              Container(
                height: _headerHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF6366F1),
                      const Color(0xFF8B5CF6),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _goBack,
                          child: Container(
                            key: generateKeyForElement('back_button'),
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
                            'Note Detail',
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
                  ),
                ),
              ),

              // Scroll up zone
              Container(
                key: generateKeyForElement('scroll_up_zone'),
                height: _navigationZoneHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      (_currentDwellingElement == 'scroll_up_zone'
                          ? Colors.purple.withOpacity(0.5)
                          : Colors.purple.withOpacity(0.2)),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: _currentDwellingElement == 'scroll_up_zone'
                            ? Colors.purple.shade700
                            : Colors.purple.withOpacity(0.7),
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Look here to scroll up',
                          style: TextStyle(
                            color: _currentDwellingElement == 'scroll_up_zone'
                                ? Colors.purple.shade700
                                : Colors.purple.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_currentDwellingElement == 'scroll_up_zone')
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: _dwellProgress,
                            strokeWidth: 2,
                            backgroundColor: Colors.purple.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.purple.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Scrollable content area
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _buildNoteContent(),
                    ),
                  ),
                ),
              ),

              // Scroll down zone
              Container(
                key: generateKeyForElement('scroll_down_zone'),
                height: _navigationZoneHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      (_currentDwellingElement == 'scroll_down_zone'
                          ? Colors.teal.withOpacity(0.5)
                          : Colors.teal.withOpacity(0.2)),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: _currentDwellingElement == 'scroll_down_zone'
                            ? Colors.teal.shade700
                            : Colors.teal.withOpacity(0.7),
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Look here to scroll down',
                          style: TextStyle(
                            color: _currentDwellingElement == 'scroll_down_zone'
                                ? Colors.teal.shade700
                                : Colors.teal.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_currentDwellingElement == 'scroll_down_zone')
                        Container(
                          margin: const EdgeInsets.only(left: 12),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: _dwellProgress,
                            strokeWidth: 2,
                            backgroundColor: Colors.teal.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.teal.shade700),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Control buttons (floating overlay)
          _buildControlButtons(),

          // Gaze point indicator
          GazePointWidget(
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            isVisible: _eyeTrackingService.isTracking,
          ),

          // Auto-scroll indicator
          if (_isAutoScrolling)
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 60,
              left: MediaQuery.of(context).size.width / 2 - 60,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Auto-scrolling...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Look away to stop',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
