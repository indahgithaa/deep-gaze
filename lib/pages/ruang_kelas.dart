// File: lib/pages/ruang_kelas.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../models/subject.dart';
import '../models/topic.dart';
import '../models/question.dart';
import '../services/global_seeso_service.dart';
import '../widgets/gaze_point_widget.dart';
import '../widgets/status_info_widget.dart';
import 'subject_details_page.dart';

class RuangKelas extends StatefulWidget {
  const RuangKelas({super.key});

  @override
  State<RuangKelas> createState() => _RuangKelasState();
}

class _RuangKelasState extends State<RuangKelas> {
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

  // Button boundaries for automatic detection
  final Map<String, Rect> _buttonBounds = {};

  @override
  void initState() {
    super.initState();
    print("DEBUG: RuangKelas initState - mengambil service global");

    _eyeTrackingService = GlobalSeesoService();
    _eyeTrackingService.addListener(_onEyeTrackingUpdate);
    _eyeTrackingService.debugPrintStatus();

    _initializeEyeTracking();
    _initializeButtonBounds();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dwellTimer?.cancel();
    _dwellTimer = null;

    if (_eyeTrackingService.hasListeners) {
      _eyeTrackingService.removeListener(_onEyeTrackingUpdate);
    }

    print("DEBUG: RuangKelas disposed, service tetap hidup");
    super.dispose();
  }

  void _initializeButtonBounds() {
    // Define button boundaries - will be updated dynamically
    _buttonBounds['english'] = const Rect.fromLTWH(20, 250, 350, 120);
    _buttonBounds['math'] = const Rect.fromLTWH(20, 390, 350, 120);
    _buttonBounds['science'] = const Rect.fromLTWH(20, 530, 350, 120);
  }

  void _onEyeTrackingUpdate() {
    if (_isDisposed || !mounted) return;

    final currentGazePoint =
        Offset(_eyeTrackingService.gazeX, _eyeTrackingService.gazeY);
    String? hoveredButton;

    // Check which subject card is being gazed at
    for (final entry in _buttonBounds.entries) {
      if (entry.value.contains(currentGazePoint)) {
        hoveredButton = entry.key;
        break;
      }
    }

    if (hoveredButton != null) {
      if (_currentDwellingElement != hoveredButton) {
        final subjects = _getSubjects();
        final subject = subjects.firstWhere((s) => s.id == hoveredButton);
        _startDwellTimer(
            hoveredButton, () => _navigateToSubjectDetails(subject));
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
      print("DEBUG: Initializing eye tracking di RuangKelas");
      await _eyeTrackingService.initialize(context);
      print("DEBUG: Eye tracking berhasil diinisialisasi di RuangKelas");
      _eyeTrackingService.debugPrintStatus();
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

  void _navigateToSubjectDetails(Subject subject) {
    if (_isDisposed || !mounted) return;

    _stopDwellTimer();

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SubjectDetailsPage(subject: subject),
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
    );
  }

  List<Subject> _getSubjects() {
    return [
      Subject(
        id: 'english',
        name: 'Bahasa Inggris',
        teacher: 'Mr. Andang Budiman',
        iconName: 'En',
        colors: ['#9C27B0', '#E91E63'],
        topics: [
          Topic(
            id: 'simple_past_1',
            name: 'Simple Past Tense',
            type: 'Tugas',
            isCompleted: true,
          ),
          Topic(
            id: 'simple_past_2',
            name: 'Simple Past Tense',
            type: 'Materi',
            isCompleted: true,
          ),
          Topic(
            id: 'simple_present_quiz',
            name: 'Simple Present Tense',
            type: 'Kuis',
            isCompleted: true,
            questions: _getEnglishQuestions(),
          ),
          Topic(
            id: 'simple_present_material',
            name: 'Simple Present Tense',
            type: 'Materi',
            isCompleted: true,
          ),
        ],
      ),
      Subject(
        id: 'math',
        name: 'Matematika',
        teacher: 'Mrs. Ratna Kusumasari',
        iconName: '+−×',
        colors: ['#FF5722', '#FF9800'],
        topics: [
          Topic(
            id: 'algebra_quiz',
            name: 'Aljabar Dasar',
            type: 'Kuis',
            questions: _getMathQuestions(),
          ),
          Topic(
            id: 'geometry_material',
            name: 'Geometri',
            type: 'Materi',
          ),
        ],
      ),
      Subject(
        id: 'science',
        name: 'Ilmu Pengetahuan Alam',
        teacher: 'Mr. Wayan Aditya',
        iconName: '⚗',
        colors: ['#2196F3', '#00BCD4'],
        topics: [
          Topic(
            id: 'biology_quiz',
            name: 'Biologi Sel',
            type: 'Kuis',
            questions: _getScienceQuestions(),
          ),
          Topic(
            id: 'physics_material',
            name: 'Fisika Dasar',
            type: 'Materi',
          ),
        ],
      ),
    ];
  }

  List<Question> _getEnglishQuestions() {
    return [
      Question(
        id: 'q1',
        questionText: 'How many students in your class ___ from Indonesia?',
        options: ['come', 'comes', 'are coming', 'came'],
        correctAnswerIndex: 0,
        explanation: 'Use "come" for plural subjects in simple present tense.',
      ),
      Question(
        id: 'q2',
        questionText: 'She ___ to school every day.',
        options: ['go', 'goes', 'going', 'went'],
        correctAnswerIndex: 1,
        explanation:
            'Use "goes" for third person singular in simple present tense.',
      ),
      Question(
        id: 'q3',
        questionText: 'They ___ their homework yesterday.',
        options: ['finish', 'finishes', 'finished', 'finishing'],
        correctAnswerIndex: 2,
        explanation: 'Use "finished" for past actions with "yesterday".',
      ),
      Question(
        id: 'q4',
        questionText: 'I ___ coffee every morning.',
        options: ['drink', 'drinks', 'drank', 'drinking'],
        correctAnswerIndex: 0,
        explanation: 'Use "drink" for first person in simple present tense.',
      ),
      Question(
        id: 'q5',
        questionText: 'He ___ a book last night.',
        options: ['read', 'reads', 'reading', 'will read'],
        correctAnswerIndex: 0,
        explanation:
            'Use "read" (past tense) for actions that happened "last night".',
      ),
    ];
  }

  List<Question> _getMathQuestions() {
    return [
      Question(
        id: 'q1',
        questionText: 'What is the value of x in the equation: 2x + 5 = 15?',
        options: ['5', '10', '7', '3'],
        correctAnswerIndex: 0,
        explanation: '2x + 5 = 15, so 2x = 10, therefore x = 5.',
      ),
      Question(
        id: 'q2',
        questionText: 'Simplify: 3(x + 2) - 2x',
        options: ['x + 6', '5x + 6', 'x + 2', '3x + 4'],
        correctAnswerIndex: 0,
        explanation: '3(x + 2) - 2x = 3x + 6 - 2x = x + 6.',
      ),
      Question(
        id: 'q3',
        questionText: 'What is 15% of 80?',
        options: ['12', '15', '10', '8'],
        correctAnswerIndex: 0,
        explanation: '15% of 80 = 0.15 × 80 = 12.',
      ),
      Question(
        id: 'q4',
        questionText: 'If y = 2x + 3, what is y when x = 4?',
        options: ['11', '9', '7', '5'],
        correctAnswerIndex: 0,
        explanation: 'y = 2(4) + 3 = 8 + 3 = 11.',
      ),
      Question(
        id: 'q5',
        questionText:
            'What is the area of a rectangle with length 8 and width 5?',
        options: ['40', '26', '13', '45'],
        correctAnswerIndex: 0,
        explanation: 'Area = length × width = 8 × 5 = 40.',
      ),
    ];
  }

  List<Question> _getScienceQuestions() {
    return [
      Question(
        id: 'q1',
        questionText: 'What is the powerhouse of the cell?',
        options: ['Nucleus', 'Mitochondria', 'Ribosome', 'Cytoplasm'],
        correctAnswerIndex: 1,
        explanation: 'Mitochondria produces energy (ATP) for the cell.',
      ),
      Question(
        id: 'q2',
        questionText: 'What gas do plants absorb during photosynthesis?',
        options: ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen'],
        correctAnswerIndex: 2,
        explanation: 'Plants absorb CO2 and release O2 during photosynthesis.',
      ),
      Question(
        id: 'q3',
        questionText: 'What is the chemical symbol for water?',
        options: ['H2O', 'CO2', 'NaCl', 'CH4'],
        correctAnswerIndex: 0,
        explanation: 'Water consists of 2 hydrogen atoms and 1 oxygen atom.',
      ),
      Question(
        id: 'q4',
        questionText: 'Which planet is closest to the Sun?',
        options: ['Venus', 'Earth', 'Mercury', 'Mars'],
        correctAnswerIndex: 2,
        explanation: 'Mercury is the closest planet to the Sun.',
      ),
      Question(
        id: 'q5',
        questionText: 'What is the basic unit of life?',
        options: ['Tissue', 'Organ', 'Cell', 'Organism'],
        correctAnswerIndex: 2,
        explanation:
            'The cell is the basic structural and functional unit of life.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final subjects = _getSubjects();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade400, Colors.purple.shade600],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Ruang Kelas',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
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
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Greeting
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.wb_sunny,
                                  color: Colors.yellow,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'SELAMAT DATANG!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade300,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Indah Citha',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.pink.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Subject Cards
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        final isCurrentlyDwelling =
                            _currentDwellingElement == subject.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Material(
                            elevation: isCurrentlyDwelling ? 8 : 4,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color(int.parse(
                                        '0xFF${subject.colors[0].substring(1)}')),
                                    Color(int.parse(
                                        '0xFF${subject.colors[1].substring(1)}')),
                                  ],
                                ),
                                border: isCurrentlyDwelling
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  // Progress indicator for dwell time
                                  if (isCurrentlyDwelling)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: Container(
                                        height: 4,
                                        width:
                                            (MediaQuery.of(context).size.width -
                                                    40) *
                                                _dwellProgress,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),

                                  // Subject content
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          child: Center(
                                            child: Text(
                                              subject.iconName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                subject.teacher,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                subject.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
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

          // Status information
          StatusInfoWidget(
            statusMessage: _eyeTrackingService.statusMessage,
            currentPage: 1,
            totalPages: 3,
            gazeX: _eyeTrackingService.gazeX,
            gazeY: _eyeTrackingService.gazeY,
            currentDwellingElement: _currentDwellingElement,
            dwellProgress: _dwellProgress,
          ),
        ],
      ),
    );
  }
}
