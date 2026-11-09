import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/callkit_service.dart';
import '../../../core/services/vosk_offline_service.dart';
import '../../call/screens/active_call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final CallKitService _callKitService;
  late final VoskOfflineService _voskService;

  bool _isGuardianActive = false;
  bool _isLoading = false;
  String _statusText = "Guardian Standby: Listening is paused";
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _callKitService = CallKitService();
    _voskService = VoskOfflineService();

    // Setup pulsing glow animation for Guardian button
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Initialize CallKit event listeners for Accept/Decline
    _callKitService.listenToCallEvents();
    _callKitService.onCallAccepted = (callerName, dialogue) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ActiveCallScreen(
              callerName: callerName,
              phoneNumber: '+8801700000000',
              dialogueText: dialogue,
              callKitService: _callKitService,
              ttsService: _callKitService.ttsService,
            ),
          ),
        );
      }
    };

    // Request necessary runtime permissions safely after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _voskService.dispose();
    super.dispose();
  }

  /// Request Microphone & Notification permissions
  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    final notifStatus = await Permission.notification.request();

    if (micStatus.isDenied && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Microphone permission is required for trigger word detection."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (notifStatus.isDenied && mounted) {
      debugPrint("Notification permission was denied.");
    }
  }

  /// Toggle Guardian Mode (offline speech listening)
  Future<void> _toggleGuardianMode() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_isGuardianActive) {
        await _voskService.stopListening();
        setState(() {
          _isGuardianActive = false;
          _statusText = "Guardian Standby: Listening is paused";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Guardian Mode deactivated."),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } else {
        // Ensure mic permission is granted
        final micStatus = await Permission.microphone.status;
        if (!micStatus.isGranted) {
          final req = await Permission.microphone.request();
          if (!req.isGranted) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Microphone access is required to activate Guardian Mode."),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            return;
          }
        }

        setState(() {
          _statusText = "Loading offline speech model...";
        });

        // Start listening with callback to trigger fake call
        await _voskService.startListening(() {
          debugPrint("Guardian detected trigger phrase! Triggering incoming call...");
          _callKitService.showFakeCall(callerName: 'Boss');
        });

        setState(() {
          _isGuardianActive = true;
          _statusText = "Guardian Active: Listening for rescue words...";
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Guardian Active! Say 'tara ache' or 'have to go' to trigger call."),
              backgroundColor: Colors.tealAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Guardian mode error: $e");
      setState(() {
        _isGuardianActive = false;
        _statusText = "Offline model not found or failed to load.";
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Vosk Model Notice", style: TextStyle(color: Colors.white)),
            content: const Text(
              "Could not start offline listening. Please ensure the Vosk offline model folder "
              "(e.g., small-en or small-bn) is placed in 'assets/models/vosk-model/' and declared in pubspec.yaml.\n\n"
              "You can still test fake calls manually anytime using the 'Test Fake Call' button below!",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Manually trigger a fake call for instant testing/debugging
  Future<void> _testFakeCall() async {
    try {
      await _callKitService.showFakeCall(callerName: 'Boss');
    } catch (e) {
      debugPrint("Error triggering fake call: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to trigger fake call: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14), // High-tech deep dark background
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 2,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isGuardianActive
                    ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                    : Colors.white10,
              ),
              child: Icon(
                Icons.security_rounded,
                color: _isGuardianActive ? const Color(0xFF00E5FF) : Colors.cyanAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ShadowCall',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isGuardianActive
                        ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                        : Colors.white24,
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isGuardianActive
                            ? const Color(0xFF00E676)
                            : Colors.orangeAccent,
                        boxShadow: [
                          BoxShadow(
                            color: (_isGuardianActive
                                    ? const Color(0xFF00E676)
                                    : Colors.orangeAccent)
                                .withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isGuardianActive ? "STATUS: ACTIVE GUARDIAN" : "STATUS: STANDBY",
                            style: TextStyle(
                              color: _isGuardianActive
                                  ? const Color(0xFF00E5FF)
                                  : Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Trigger Phrases Info Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F29),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mic_none_rounded, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Voice Trigger Phrases (বাংলা & English)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTriggerChip("amar tara ache"),
                        _buildTriggerChip("tara ache"),
                        _buildTriggerChip("have to go"),
                        _buildTriggerChip("emergency"),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Glowing Guardian Button
              Center(
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _isGuardianActive
                                ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                                : const Color(0xFF7C4DFF).withValues(alpha: 0.45),
                            blurRadius: _glowAnimation.value,
                            spreadRadius: _glowAnimation.value / 3,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isLoading ? null : _toggleGuardianMode,
                          child: Ink(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isGuardianActive
                                    ? [const Color(0xFF00B0FF), const Color(0xFF00E5FF)]
                                    : [const Color(0xFF651FFF), const Color(0xFF7C4DFF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isGuardianActive
                                              ? Icons.stop_rounded
                                              : Icons.power_settings_new_rounded,
                                          size: 52,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _isGuardianActive
                                              ? "Stop\nGuardian"
                                              : "Start\nGuardian Mode",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // Manual Test Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF7C4DFF)],
                  ),
                ),
                padding: const EdgeInsets.all(1.5),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF161B22),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _testFakeCall,
                  icon: const Icon(Icons.phone_callback_rounded, color: Colors.cyanAccent),
                  label: const Text(
                    'Test Fake Call Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriggerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        "\"$label\"",
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
