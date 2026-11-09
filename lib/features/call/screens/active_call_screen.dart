import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/callkit_service.dart';
import '../../../core/services/tts_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final String callerName;
  final String phoneNumber;
  final String dialogueText;
  final CallKitService callKitService;
  final TtsService ttsService;

  const ActiveCallScreen({
    super.key,
    required this.callerName,
    required this.phoneNumber,
    required this.dialogueText,
    required this.callKitService,
    required this.ttsService,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen>
    with SingleTickerProviderStateMixin {
  late Timer _durationTimer;
  int _secondsElapsed = 0;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isOnHold = false;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    // Start in-call elapsed timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });

    // Audio waveform pulsing animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _durationTimer.cancel();
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  Future<void> _endCall() async {
    await widget.ttsService.stop();
    await widget.callKitService.endAllCalls();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Caller Details Header
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.phoneNumber,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_secondsElapsed),
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 30),

              // Caller Avatar with Waveform Glow
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  final glow = _waveController.value * 12 + 6;
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                          blurRadius: glow,
                          spreadRadius: glow / 3,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: const CircleAvatar(
                  radius: 54,
                  backgroundColor: Color(0xFF1F1F1F),
                  child: Icon(
                    Icons.person_rounded,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Simulated Dialogue Transcript Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00E676),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "LIVE AUDIO STREAM",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.dialogueText.isNotEmpty
                            ? "\"${widget.dialogueText}\""
                            : "\"কই তুমি? জলদি আসো!\"",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // In-Call Dialpad & Control Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCallActionButton(
                          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: _isMuted ? "Unmute" : "Mute",
                          isActive: _isMuted,
                          onTap: () => setState(() => _isMuted = !_isMuted),
                        ),
                        _buildCallActionButton(
                          icon: Icons.dialpad_rounded,
                          label: "Keypad",
                          isActive: false,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Keypad opened"),
                                duration: Duration(milliseconds: 600),
                              ),
                            );
                          },
                        ),
                        _buildCallActionButton(
                          icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          label: "Speaker",
                          isActive: _isSpeakerOn,
                          onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCallActionButton(
                          icon: Icons.add_call,
                          label: "Add Call",
                          isActive: false,
                          onTap: () {},
                        ),
                        _buildCallActionButton(
                          icon: Icons.pause_rounded,
                          label: _isOnHold ? "Unhold" : "Hold",
                          isActive: _isOnHold,
                          onTap: () => setState(() => _isOnHold = !_isOnHold),
                        ),
                        _buildCallActionButton(
                          icon: Icons.contacts_rounded,
                          label: "Contacts",
                          isActive: false,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Large Red End Call Button
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF1744),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.call_end_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : const Color(0xFF222222),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

