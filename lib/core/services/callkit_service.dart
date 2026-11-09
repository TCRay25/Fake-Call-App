import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';
import 'ai_service.dart';
import 'tts_service.dart';

class CallKitService {
  final AiService _aiService;
  final TtsService _ttsService;

  CallKitService({
    AiService? aiService,
    TtsService? ttsService,
  })  : _aiService = aiService ?? AiService(),
        _ttsService = ttsService ?? TtsService();

  AiService get aiService => _aiService;
  TtsService get ttsService => _ttsService;

  void Function(String callerName, String dialogue)? onCallAccepted;
  void Function()? onCallEnded;

  /// Show a realistic fake incoming call UI
  Future<void> showFakeCall({
    String callerName = 'Boss',
    String phoneNumber = '+8801700000000',
  }) async {
    final String callId = const Uuid().v4();

    final CallKitParams params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'ShadowCall',
      avatar: 'https://i.pravatar.cc/150?img=68',
      handle: phoneNumber,
      type: 0, // 0 = Audio Call
      duration: 30000, // 30 seconds ring duration
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed Rescue Call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'userId': 'user_shadow_call'},
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'ShadowCall Incoming',
        missedCallNotificationChannelName: 'ShadowCall Missed',
        isShowCallID: false,
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    debugPrint("Triggering fake incoming call from: $callerName");
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Listen to call events: Answer, Decline, Timeout, End
  void listenToCallEvents() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;
      debugPrint("CallKit Event received: ${event.event}");

      switch (event.event) {
        case Event.actionCallAccept:
          debugPrint("Call accepted! Fetching dynamic dialogue from Gemini AI...");
          try {
            final dialogue = await _aiService.getInitialDialogue();
            debugPrint("AI Dialogue ready: $dialogue");
            await _ttsService.speak(dialogue);
            onCallAccepted?.call('Boss', dialogue);
          } catch (e) {
            debugPrint("Error processing call accept dialogue: $e");
          }
          break;

        case Event.actionCallDecline:
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          debugPrint("Call declined, ended or timed out. Stopping TTS playback...");
          await _ttsService.stop();
          onCallEnded?.call();
          break;

        default:
          break;
      }
    });
  }

  /// Dismiss all active calls and silence TTS
  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
    await _ttsService.stop();
  }
}
