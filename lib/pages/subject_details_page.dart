// File: lib/pages/subject_details_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import '../mixins/responsive_bounds_mixin.dart';
import 'quiz_page.dart';
import 'tugas_page.dart';
import 'material_reader_page.dart';

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

  // Dwell time selection state
  String? _currentDwellingElement;
  double _dwellProgress = 0.0;
  Timer? _dwellTimer;
  DateTime? _dwellStartTime;

  // Dwell time configuration - 1.5 seconds
  static const int _dwellTimeMs = 1500;
  static const int _dwellUpdateIntervalMs = 50;

  // Current selected tab
  String _selectedTab = 'Semua';

  // Override mixin configuration
  @override
  double get boundsUpdateDelay => 200.0; // Longer delay for ListView items

  @override
  bool get enableBoundsLogging => true;

  @override
  void initState() {
    super.initState();
    print("DEBUG: SubjectDetailsPage initState");
    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);

    // Initialize element keys using mixin
    _initializeElementKeys();

    _initializeEyeTracking();

    // Calculate bounds after build using mixin
    updateBoundsAfterBuild();
  }

  void _initializeElementKeys() {
    // Generate key for back button
    generateKeyForElement('back_button');

    // Generate keys for all topics using mixin
    for (final topic in widget.subject.topics) {
      generateKeyForElement(topic.id);
    }

    print("DEBUG: Generated ${elementCount} element keys using mixin");
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;
    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }

    // Clean up mixin resources
    clearBounds();

    print("DEBUG: SubjectDetailsPage disposed");
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recalculate bounds when dependencies change
    updateBoundsAfterBuild();
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);

    // Use mixin's precise hit detection
    String? hoveredElement = getElementAtPoint(currentGazePoint);

    if (hoveredElement != null) {
      if (_currentDwellingElement != hoveredElement) {
        if (hoveredElement == 'back_button') {
          _startDwellTimer(hoveredElement, _goBack);
        } else {
          // Find the topic
          final topic = widget.subject.topics.firstWhere(
            (t) => t.id == hoveredElement,
            orElse: () => widget.subject.topics.first,
          );
          _startDwellTimer(hoveredElement, () => _handleTopicSelection(topic));
        }
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

  Future<void> _initializeEyeTracking() async {
    if (_isDisposed || !mounted) return;

    try {
      print("DEBUG: Initializing eye tracking di SubjectDetailsPage");
      await _eyeTrackingService.initialize(context);
      print(
          "DEBUG: Eye tracking berhasil diinisialisasi di SubjectDetailsPage");
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

  // UPDATED: Complete topic selection handling for all types
  void _handleTopicSelection(Topic topic) {
    if (_isDisposed || !mounted) return;
    _stopDwellTimer();

    // Clean up listeners before navigation to prevent conflicts
    _eyeTrackingService.removeListener(_onEyeTrackingUpdate);

    if (topic.type == 'Kuis' && topic.questions != null) {
      // Navigate to quiz page
      Navigator.of(context)
          .push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => QuizPage(
            subject: widget.subject,
            topic: topic,
            questions: topic.questions!,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      )
          .then((_) {
        // Re-add listener when returning from quiz
        if (!_isDisposed && mounted) {
          _eyeTrackingService.addListener(_onEyeTrackingUpdate);
          // Recalculate bounds when returning
          updateBoundsAfterBuild();
        }
      });
    } else if (topic.type == 'Tugas') {
      // Navigate to tugas (assignment) page with eye-controlled keyboard
      Navigator.of(context)
          .push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => TugasPage(
            subject: widget.subject,
            topic: topic,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      )
          .then((_) {
        // Re-add listener when returning from tugas
        if (!_isDisposed && mounted) {
          _eyeTrackingService.addListener(_onEyeTrackingUpdate);
          // Recalculate bounds when returning
          updateBoundsAfterBuild();
        }
      });
    } else if (topic.type == 'Materi') {
      // Navigate to material reader page with eye-controlled navigation
      Navigator.of(context)
          .push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              MaterialReaderPage(
            subject: widget.subject,
            topic: topic,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: animation.drive(
                Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      )
          .then((_) {
        // Re-add listener when returning from material reader
        if (!_isDisposed && mounted) {
          _eyeTrackingService.addListener(_onEyeTrackingUpdate);
          // Recalculate bounds when returning
          updateBoundsAfterBuild();
        }
      });
    } else {
      // Handle unknown topic types or show info
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('${topic.name} - ${topic.type} will be available soon!'),
          duration: const Duration(seconds: 2),
          backgroundColor: topic.isCompleted ? Colors.green : Colors.blue,
        ),
      );

      // Re-add listener immediately since we're not navigating
      if (!_isDisposed && mounted) {
        _eyeTrackingService.addListener(_onEyeTrackingUpdate);
      }
    }
  }

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

  Widget _buildTopicCard(Topic topic, int index) {
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
        iconColor = Colors.green; // Changed to green for better distinction
        break;
      case 'Kuis':
        iconData = Icons.quiz;
        iconColor = Colors.purple; // Changed to purple for better distinction
        break;
      default:
        iconData = Icons.circle;
        iconColor = Colors.grey;
    }

    return Container(
      key: generateKeyForElement(topic.id), // Use mixin for key
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
                      color: iconColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Topic content
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconData,
                      color: iconColor,
                      size: 24,
                    ),
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
                            if (topic.type == 'Materi') ...[
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (topic.isCompleted)
                        //   Container(
                        //     padding: const EdgeInsets.all(8),
                        //     decoration: BoxDecoration(
                        //       color: Colors.green.withOpacity(0.1),
                        //       shape: BoxShape.circle,
                        //     ),
                        //     child: const Icon(
                        //       Icons.check,
                        //       color: Colors.green,
                        //       size: 20,
                        //     ),
                        //   ),
                        // const SizedBox(height: 8),
                        // Type-specific action hint
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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

  @override
  Widget build(BuildContext context) {
    final filteredTopics = _getFilteredTopics();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with subject info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(int.parse(
                              '0xFF${widget.subject.colors[0].substring(1)}')),
                          Color(int.parse(
                              '0xFF${widget.subject.colors[1].substring(1)}')),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              key: generateKeyForElement(
                                  'back_button'), // Use mixin
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
                                      color: Colors.white.withOpacity(0.8),
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
                  // Tabs
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    child: Row(
                      children: ['Semua', 'Materi', 'Tugas & Kuis'].map((tab) {
                        final isSelected = _selectedTab == tab;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTab = tab;
                              });
                              // Recalculate bounds when tab changes
                              updateBoundsAfterBuild();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tab,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Enhanced topics list with better visual indicators
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredTopics.length,
                      itemBuilder: (context, index) {
                        return _buildTopicCard(filteredTopics[index], index);
                      },
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
          // // Status information
          // StatusInfoWidget(
          //   statusMessage: _eyeTrackingService.statusMessage,
          //   currentPage: 2,
          //   totalPages: 3,
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
