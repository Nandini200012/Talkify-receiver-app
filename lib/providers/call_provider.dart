import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call_model.dart';
import '../services/webhook_service.dart';

class CallProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WebhookService _webhookService = WebhookService();

  RtcEngine? _engine;
  static const String appId = "96329987950b40fd9ee8a20dad682cdb";

  CallModel? _currentCall;
  bool _isJoined = false;
  bool _isEngineInitialized = false;
  bool _muted = false;
  bool _isCameraOff = false;
  bool _isRemoteVideoOff = false;
  int? _remoteUid;
  int _callDuration = 0;
  bool _isSpeakerOn = false;

  CallModel? get currentCall => _currentCall;
  bool get isJoined => _isJoined;
  bool get isEngineInitialized => _isEngineInitialized;
  bool get muted => _muted;
  bool get isCameraOff => _isCameraOff;
  bool get isRemoteVideoOff => _isRemoteVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  int? get remoteUid => _remoteUid;
  String get formattedDuration {
    final minutes = (_callDuration / 60).floor().toString().padLeft(2, '0');
    final seconds = (_callDuration % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  StreamSubscription? _callSubscription;
  String? _currentCallDocId;
  Timer? _timeoutTimer;
  Timer? _callDurationTimer;

  StreamSubscription? _activeCallSubscription;

  void listenForIncomingCalls(String receiverId, BuildContext context) {
    _callSubscription?.cancel();

    _callSubscription = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: receiverId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty && _currentCall == null) {
            final results = snapshot.docs.where((doc) {
              final data = doc.data();
              if (data['timestamp'] == null) return false;

              DateTime callTime;
              final ts = data['timestamp'];
              if (ts is Timestamp) {
                callTime = ts.toDate();
              } else if (ts is String) {
                callTime = DateTime.parse(ts);
              } else {
                return false;
              }

              final diff = DateTime.now().difference(callTime).abs();
              final isRecent = diff.inMinutes < 1;

              debugPrint(
                "Call Filter: ID=${doc.id}, Time=$callTime, Now=${DateTime.now()}, Diff=${diff.inSeconds}s, Recent=$isRecent",
              );
              return isRecent;
            }).toList();

            if (results.isEmpty) {
              debugPrint("No recent ringing calls found.");
              return;
            }

            final callDoc = results.first;
            debugPrint("Picking up call: ${callDoc.id}");
            _currentCall = CallModel.fromMap(callDoc.data());
            _currentCallDocId = callDoc.id;

            _timeoutTimer?.cancel();
            _timeoutTimer = Timer(const Duration(seconds: 30), () {
              if (_currentCall != null && _currentCall!.status == 'ringing') {
                rejectCall();
              }
            });

            _startActiveCallListener(_currentCallDocId!);

            notifyListeners();
          }
        });
  }

  void _startActiveCallListener(String callId) {
    _activeCallSubscription?.cancel();
    _activeCallSubscription = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) {
          if (doc.exists) {
            final updatedCall = CallModel.fromMap(
              doc.data() as Map<String, dynamic>,
            );

            if (updatedCall.status == 'ended' ||
                updatedCall.status == 'rejected') {
              endCall();
            } else if (updatedCall.status == 'accepted' &&
                _currentCall?.status != 'accepted') {
              _currentCall = updatedCall;
              _timeoutTimer?.cancel();
              notifyListeners();
            }
          } else {
            endCall();
          }
        });
  }

  void _startTimer() {
    _callDurationTimer?.cancel();
    _callDuration = 0;
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDuration++;
      notifyListeners();
    });
  }

  Future<void> initAgora() async {
    try {
      if (_isEngineInitialized && _engine != null) {
        debugPrint("Agora Engine already initialized.");
        return;
      }

      if (_currentCall == null) {
        debugPrint("Cannot initialize Agora: _currentCall is null");
        return;
      }

      debugPrint("Initializing Agora for ${_currentCall!.callType} call...");

      if (_currentCall!.callType == 'video') {
        final statuses = await [
          Permission.camera,
          Permission.microphone,
        ].request();
        if (statuses[Permission.microphone] != PermissionStatus.granted) {
          debugPrint(
            "WARNING: Microphone permission NOT granted: ${statuses[Permission.microphone]}",
          );
        }
        if (statuses[Permission.camera] != PermissionStatus.granted) {
          debugPrint(
            "WARNING: Camera permission NOT granted: ${statuses[Permission.camera]}",
          );
        }
      } else {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          debugPrint("WARNING: Microphone permission NOT granted: $status");
        }
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        const RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          audioScenario: AudioScenarioType.audioScenarioDefault,
        ),
      );

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
              "SUCCESS: Joined channel ${connection.channelId} with UID ${connection.localUid}",
            );
            _isJoined = true;
            _startTimer();
            _engine?.setEnableSpeakerphone(_isSpeakerOn);
            notifyListeners();
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("REMOTE USER JOINED: $remoteUid");
            _remoteUid = remoteUid;
            notifyListeners();
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                debugPrint("REMOTE USER OFFLINE: $remoteUid, reason: $reason");
                _remoteUid = null;
                _isRemoteVideoOff = false;
                notifyListeners();
                if (reason == UserOfflineReasonType.userOfflineQuit) {
                  endCall();
                }
              },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("AGORA ERROR: $err - $msg");
          },
        ),
      );

      if (_currentCall!.callType == 'video') {
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        await _engine!.enableAudio();
      }

      _isEngineInitialized = true;
      notifyListeners();
      debugPrint("Agora Engine initialization complete.");
    } catch (e) {
      debugPrint("CRITICAL ERROR in initAgora: $e");
      _isEngineInitialized = false;
      _engine = null;
      rethrow;
    }
  }

  Future<void> requestPermissions() async {
    if (_currentCall?.callType == 'video') {
      await [Permission.camera, Permission.microphone].request();
    } else {
      await Permission.microphone.request();
    }
  }

  Future<bool> acceptCall() async {
    if (_currentCall == null || _currentCallDocId == null) {
      debugPrint(
        "ABORT: acceptCall failed - _currentCall or _currentCallDocId is null",
      );
      return false;
    }

    _timeoutTimer?.cancel();

    try {
      debugPrint("Accepting call ${_currentCallDocId}...");

      final success = await _webhookService.updateCallStatus(
        callId: _currentCallDocId!,
        status: 'accepted',
      );

      if (!success) {
        debugPrint("ABORT: Failed to update Firestore status to 'accepted'");
        return false;
      }

      _currentCall = _currentCall!.copyWith(status: 'accepted');
      _isShowingIncomingUI = false;

      await initAgora();

      if (_engine == null) {
        debugPrint("ABORT: Agora Engine is null after initAgora()");
        return false;
      }

      final token = _currentCall!.agoraToken ?? '';
      final channelId = _currentCall!.channelName;

      debugPrint("Joining channel: $channelId (Token length: ${token.length})");

      await _engine!.joinChannel(
        token: token,
        channelId: channelId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: _currentCall!.callType == 'video',
          autoSubscribeAudio: true,
          autoSubscribeVideo: _currentCall!.callType == 'video',
        ),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("FATAL EXCEPTION in acceptCall: $e");
      return false;
    }
  }

  Future<void> rejectCall() async {
    if (_currentCallDocId == null) return;

    _timeoutTimer?.cancel();

    await _webhookService.updateCallStatus(
      callId: _currentCallDocId!,
      status: 'rejected',
    );

    _cleanup();
  }

  Future<void> endCall() async {
    if (_currentCallDocId != null) {
      await _webhookService.updateCallStatus(
        callId: _currentCallDocId!,
        status: 'ended',
      );
    }
    _cleanup();
  }

  bool _isShowingIncomingUI = false;
  bool get isShowingIncomingUI => _isShowingIncomingUI;
  void setShowingIncomingUI(bool value) {
    _isShowingIncomingUI = value;
    notifyListeners();
  }

  void _cleanup() async {
    _callDurationTimer?.cancel();
    _activeCallSubscription?.cancel();
    if (_isEngineInitialized && _engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
    }
    _isEngineInitialized = false;
    _isJoined = false;
    _remoteUid = null;
    _currentCall = null;
    _currentCallDocId = null;
    _isShowingIncomingUI = false;
    _isCameraOff = false;
    _isRemoteVideoOff = false;
    _muted = false;
    _isSpeakerOn = false;
    notifyListeners();
  }

  void toggleMute() {
    _muted = !_muted;
    _engine?.muteLocalAudioStream(_muted);
    notifyListeners();
  }

  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    _engine?.muteLocalVideoStream(_isCameraOff);
    _engine?.enableLocalVideo(!_isCameraOff);
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _engine?.setEnableSpeakerphone(_isSpeakerOn);
    notifyListeners();
  }

  void switchCamera() {
    _engine?.switchCamera();
  }

  RtcEngine? get engine => _engine;

  @override
  void dispose() {
    _callSubscription?.cancel();
    _timeoutTimer?.cancel();
    _callDurationTimer?.cancel();
    _cleanup();
    super.dispose();
  }
}
