import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const SignSpeaksApp());
}

class AppColors {
  static const Color background = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1A1A1A);
  static const Color primary = Color(0xFF1E90FF);
  // Add a slight glow effect to cards
  static List<BoxShadow> glowShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.15),
      blurRadius: 20,
      spreadRadius: 1,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppStyles {
  static const double cardRadius = 24.0;
  static const EdgeInsets cardPadding = EdgeInsets.all(20.0);
}

class SignSpeaksApp extends StatefulWidget {
  const SignSpeaksApp({super.key});

  @override
  State<SignSpeaksApp> createState() => _SignSpeaksAppState();
}

class _SignSpeaksAppState extends State<SignSpeaksApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignSpeaks Premium',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.cardBackground,
          onSurface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: MainScreen(onThemeChanged: toggleTheme),
    );
  }
}

class MainScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  const MainScreen({super.key, required this.onThemeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const LiveDetectionScreen(),
      const TextToSignScreen(),
      const HistoryScreen(),
      SettingsScreen(onThemeChanged: widget.onThemeChanged),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackground.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.black12,
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.videocam_rounded, 'Live', 0, isDark),
              _buildNavItem(Icons.text_fields_rounded, 'Text', 1, isDark),
              _buildNavItem(Icons.history_rounded, 'History', 2, isDark),
              _buildNavItem(Icons.settings_rounded, 'Settings', 3, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? Colors.grey : Colors.black54);
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. LIVE DETECTION SCREEN
// ==========================================
class LiveDetectionScreen extends StatefulWidget {
  const LiveDetectionScreen({super.key});

  @override
  State<LiveDetectionScreen> createState() => _LiveDetectionScreenState();
}

class _LiveDetectionScreenState extends State<LiveDetectionScreen> {
  static const String _webBackendUrl = String.fromEnvironment(
    'SIGN_SPEAKS_API_URL',
    defaultValue: 'http://127.0.0.1:8000/predict',
  );

  Process? _pythonProcess;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;
  CameraController? _cameraController;
  Timer? _webFrameTimer;

  bool _isStarting = false;
  bool _isRunning = false;
  bool _isSendingFrame = false;
  List<Offset> _handLandmarks = const [];
  String _status = 'Tap Start Detection to begin.';
  String _detectedWord = '--';
  double _confidence = 0.0;
  String _aiResponse = 'Detection output will appear here.';

  @override
  void dispose() {
    _webFrameTimer?.cancel();
    _cameraController?.dispose();
    _stopDetection();
    super.dispose();
  }

  Future<void> _initializeWebCamera() async {
    if (_cameraController?.value.isInitialized == true) {
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No camera found for web target.');
    }

    final selectedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();
    _cameraController = controller;
  }

  Future<void> _sendFrameToWebBackend(Uint8List bytes) async {
    final request = http.MultipartRequest('POST', Uri.parse(_webBackendUrl))
      ..files.add(
        http.MultipartFile.fromBytes('frame', bytes, filename: 'frame.jpg'),
      );

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception('Backend error (${streamedResponse.statusCode}): $body');
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final word = (decoded['word'] as String?) ?? '--';
    final confidence = (decoded['confidence'] as num?)?.toDouble() ?? 0.0;
    final status = (decoded['status'] as String?) ?? 'Detecting...';
    final handDetected = (decoded['hand_detected'] as bool?) ?? false;
    final landmarksRaw = (decoded['landmarks'] as List<dynamic>? ?? const []);

    final landmarks = landmarksRaw
        .whereType<Map<String, dynamic>>()
        .map((point) {
          final x = (point['x'] as num?)?.toDouble();
          final y = (point['y'] as num?)?.toDouble();
          if (x == null || y == null) {
            return null;
          }
          return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
        })
        .whereType<Offset>()
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _detectedWord = word.toUpperCase();
      _confidence = confidence.clamp(0.0, 1.0);
      _status = handDetected ? status : 'No hand detected. Show hand in frame.';
      _handLandmarks = landmarks;
      _aiResponse =
          'Detected "$word" with ${(confidence * 100).toStringAsFixed(1)}% confidence.';
    });
  }

  Future<void> _captureAndSendWebFrame() async {
    if (!_isRunning || _isSendingFrame) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _isSendingFrame = true;
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      await _sendFrameToWebBackend(bytes);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status =
            'Web detection failed. Start Python API: python web_api.py (${error.toString()})';
      });
    } finally {
      _isSendingFrame = false;
    }
  }

  Future<void> _startWebDetection() async {
    setState(() {
      _isStarting = true;
      _status = 'Initializing web camera...';
      _aiResponse = 'Connecting to Python API at $_webBackendUrl';
    });

    try {
      await _initializeWebCamera();

      if (!mounted) return;
      setState(() {
        _isRunning = true;
        _isStarting = false;
        _status = 'Camera started. Sending frames to Python API...';
      });

      _webFrameTimer?.cancel();
      _webFrameTimer = Timer.periodic(
        const Duration(milliseconds: 120),
        (_) => _captureAndSendWebFrame(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isStarting = false;
        _status = 'Could not start web detection: ${error.toString()}';
      });
    }
  }

  Future<Process?> _startPythonProcess() async {
    final candidatesForScript = <String>[
      '${Directory.current.path}${Platform.pathSeparator}app.py',
      '${Directory.current.path}${Platform.pathSeparator}sign_speaks${Platform.pathSeparator}app.py',
    ];

    String? scriptPath;
    for (final path in candidatesForScript) {
      if (File(path).existsSync()) {
        scriptPath = path;
        break;
      }
    }

    if (scriptPath == null) {
      return null;
    }

    final workingDirectory = File(scriptPath).parent.path;
    final candidates = <List<String>>[
      ['python', scriptPath],
      ['py', scriptPath],
    ];

    for (final command in candidates) {
      try {
        return await Process.start(
          command.first,
          command.sublist(1),
          workingDirectory: workingDirectory,
          runInShell: true,
        );
      } catch (_) {}
    }
    return null;
  }

  void _handlePythonLine(String line) {
    if (!mounted || line.trim().isEmpty) return;

    if (line.startsWith('DETECTION|')) {
      final parts = line.split('|');
      final values = <String, String>{};

      for (final part in parts.skip(1)) {
        final kv = part.split('=');
        if (kv.length == 2) {
          values[kv[0]] = kv[1];
        }
      }

      final word = values['word'] ?? '--';
      final confidence = double.tryParse(values['confidence'] ?? '') ?? 0.0;

      setState(() {
        _detectedWord = word.toUpperCase();
        _confidence = confidence.clamp(0.0, 1.0);
        _status = 'Detecting...';
        _aiResponse = 'Detected "$word" with ${(confidence * 100).toStringAsFixed(1)}% confidence.';
      });
      return;
    }

    if (line.startsWith('STATUS|')) {
      final statusValue = line.replaceFirst('STATUS|', '');
      setState(() {
        _status = 'Status: $statusValue';
      });
      return;
    }
  }

  Future<void> _startDetection() async {
    if (_isRunning || _isStarting) return;

    if (kIsWeb) {
      await _startWebDetection();
      return;
    }

    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      setState(() {
        _status =
            'Python integration works on desktop app targets only (Windows/Linux/macOS).';
      });
      return;
    }

    setState(() {
      _isStarting = true;
      _status = 'Starting Python detector...';
      _aiResponse = 'Launching camera and model...';
    });

    final process = await _startPythonProcess();
    if (!mounted) return;

    if (process == null) {
      setState(() {
        _isStarting = false;
        _status = 'Could not start Python. Ensure python/py is installed and in PATH.';
      });
      return;
    }

    _pythonProcess = process;
    _stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handlePythonLine);

    _stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (!mounted || line.trim().isEmpty) return;
          setState(() {
            _status = 'Python: $line';
          });
        });

    setState(() {
      _isStarting = false;
      _isRunning = true;
      _status = 'Detector started. Camera should open now.';
    });

    process.exitCode.then((_) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _status = 'Detector stopped.';
      });
    });
  }

  Future<void> _stopDetection() async {
    _webFrameTimer?.cancel();
    _webFrameTimer = null;
    await _cameraController?.dispose();
    _cameraController = null;

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;

    final process = _pythonProcess;
    _pythonProcess = null;
    process?.kill(ProcessSignal.sigterm);

    if (mounted) {
      setState(() {
        _isRunning = false;
        _isStarting = false;
        _status = 'Detection stopped.';
        _handLandmarks = const [];
      });
    }
  }

  double _cameraAspectRatio() {
    if (kIsWeb &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      return _cameraController!.value.aspectRatio;
    }
    return 4 / 3;
  }

  Widget _buildCameraPreviewSurface() {
    final hasWebCamera =
        kIsWeb && _cameraController != null && _cameraController!.value.isInitialized;

    if (!hasWebCamera) {
      return const Icon(
        Icons.camera_alt_outlined,
        color: Colors.white24,
        size: 80,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: AspectRatio(
            aspectRatio: _cameraAspectRatio(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppStyles.cardRadius - 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_cameraController!),
                  CustomPaint(
                    painter: _HandLandmarksPainter(
                      landmarks: _handLandmarks,
                      color: Colors.greenAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardBackground : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Live Detection',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Real-time sign recognition with visual hand tracking',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                    boxShadow: isDark
                        ? AppColors.glowShadow
                        : [
                            const BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildCameraPreviewSurface(),
                      const Positioned(
                        top: 40,
                        bottom: 40,
                        left: 40,
                        right: 40,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.fromBorderSide(
                              BorderSide(color: AppColors.primary, width: 2),
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: _isRunning ? Colors.redAccent : Colors.grey,
                                size: 10,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isRunning ? 'LIVE' : 'IDLE',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
              const SizedBox(height: 20),
              Container(
                padding: AppStyles.cardPadding,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                  boxShadow: isDark
                      ? []
                      : [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _detectedWord,
                        key: ValueKey(_detectedWord),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Confidence',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _confidence,
                              backgroundColor: Colors.white12,
                              color: AppColors.primary,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(_confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _aiResponse,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isStarting
                    ? null
                    : (_isRunning ? _stopDetection : _startDetection),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _isStarting
                      ? 'Starting...'
                      : (_isRunning ? 'Stop Detection' : 'Start Detection'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandLandmarksPainter extends CustomPainter {
  final List<Offset> landmarks;
  final Color color;

  _HandLandmarksPainter({required this.landmarks, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final connections = <List<int>>[
      [0, 1], [1, 2], [2, 3], [3, 4],
      [0, 5], [5, 6], [6, 7], [7, 8],
      [5, 9], [9, 10], [10, 11], [11, 12],
      [9, 13], [13, 14], [14, 15], [15, 16],
      [13, 17], [17, 18], [18, 19], [19, 20],
      [0, 17],
    ];

    Offset toCanvasPoint(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);

    for (final edge in connections) {
      final startIndex = edge[0];
      final endIndex = edge[1];
      if (startIndex >= landmarks.length || endIndex >= landmarks.length) {
        continue;
      }
      canvas.drawLine(
        toCanvasPoint(landmarks[startIndex]),
        toCanvasPoint(landmarks[endIndex]),
        linePaint,
      );
    }

    for (final point in landmarks) {
      canvas.drawCircle(toCanvasPoint(point), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HandLandmarksPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks || oldDelegate.color != color;
  }
}

// ==========================================
// 2. HISTORY SCREEN
// ==========================================
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardBackground : Colors.white;

    final dummyHistory = [
      {'gesture': 'HELLO', 'time': '10:42 AM', 'conf': '95%'},
      {'gesture': 'THANK YOU', 'time': '10:38 AM', 'conf': '92%'},
      {'gesture': 'PLEASE', 'time': '10:15 AM', 'conf': '88%'},
      {'gesture': 'YES', 'time': '09:50 AM', 'conf': '98%'},
      {'gesture': 'NO', 'time': '09:48 AM', 'conf': '97%'},
      {'gesture': 'HELP', 'time': '09:20 AM', 'conf': '85%'},
      {'gesture': 'FRIEND', 'time': '08:15 AM', 'conf': '91%'},
      {'gesture': 'GOOD', 'time': 'Yesterday', 'conf': '94%'},
      {'gesture': 'MORNING', 'time': 'Yesterday', 'conf': '89%'},
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Recent Detections',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: dummyHistory.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = dummyHistory[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isDark
                            ? []
                            : [
                                const BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 5,
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.history_edu,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['gesture']!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['time']!,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['conf']!,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. TEXT TO SIGN SCREEN
// ==========================================
class TextToSignScreen extends StatelessWidget {
  const TextToSignScreen({super.key});

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://prvpwhcm-5000.inc1.devtunnels.ms/');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardBackground : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Text to Sign Language',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: AppStyles.cardPadding,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                    boxShadow: isDark
                        ? []
                        : [
                            const BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome to the Text to Indian Sign Language module of our Signspeaks app. This module converts your given english text into corresponding indian sign language. To experience and use the feature, click the button below. Thanks for choosing our app !",
                        style: TextStyle(fontSize: 16, height: 1.5),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: ElevatedButton(
                          onPressed: _launchURL,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Try Text to Sign'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatefulWidget {
  final VoidCallback onThemeChanged;
  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cameraEnabled = true;
  bool _realtimeTranslation = true;
  bool _textToSpeech = false;
  String _selectedModel = 'Standard AI (Fast)';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardBackground : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // AI Features Group
                _buildSectionHeader('AI Features'),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        'Real-time Translation',
                        _realtimeTranslation,
                        (val) => setState(() => _realtimeTranslation = val),
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      _buildSwitchTile(
                        'Text-to-Speech (Beta)',
                        _textToSpeech,
                        (val) => setState(() => _textToSpeech = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Device Group
                _buildSectionHeader('Device'),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        'Camera Enabled',
                        _cameraEnabled,
                        (val) => setState(() => _cameraEnabled = val),
                      ),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'AI Model',
                              style: TextStyle(fontSize: 16),
                            ),
                            DropdownButton<String>(
                              value: _selectedModel,
                              underline: const SizedBox(),
                              dropdownColor: isDark
                                  ? AppColors.cardBackground
                                  : Colors.white,
                              items:
                                  [
                                    'Standard AI (Fast)',
                                    'Premium AI (Accurate)',
                                  ].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setState(() => _selectedModel = newValue);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Appearance Group
                _buildSectionHeader('Appearance'),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppStyles.cardRadius),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    title: const Text(
                      'Dark Theme',
                      style: TextStyle(fontSize: 16),
                    ),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (val) => widget.onThemeChanged(),
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
    );
  }
}
