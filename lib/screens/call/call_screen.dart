import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final call = callProvider.currentCall;

    debugPrint(
      "CallScreen Build: Joined=${callProvider.isJoined}, RemoteUID=${callProvider.remoteUid}",
    );

    if (call == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.popUntil(context, (route) => route.isFirst);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: !callProvider.isEngineInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                Positioned.fill(child: _remoteVideo(callProvider)),

                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            call.callerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              callProvider.formattedDuration,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Local Video (Floating) - Only for video calls
                if (call.callType == 'video')
                  Positioned(
                    top: 60,
                    right: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 120,
                        height: 180,
                        color: Colors.black54,
                        child: callProvider.isJoined
                            ? (callProvider.isCameraOff
                                  ? Container(
                                      color: Colors.black,
                                      child: const Center(
                                        child: Icon(
                                          Icons.videocam_off,
                                          color: Colors.white38,
                                          size: 40,
                                        ),
                                      ),
                                    )
                                  : AgoraVideoView(
                                      controller: VideoViewController(
                                        rtcEngine: callProvider.engine!,
                                        canvas: const VideoCanvas(uid: 0),
                                      ),
                                    ))
                            : const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                      ),
                    ),
                  ),

                // Bottom Controls
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _toolbar(callProvider),
                ),
              ],
            ),
    );
  }

  Widget _remoteVideo(CallProvider callProvider) {
    if (!callProvider.isEngineInitialized) return const SizedBox();

    final isVideo = callProvider.currentCall?.callType == 'video';

    if (!isVideo) {
      return Container(
        color: const Color(0xFF0F0F1E),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 80,
                backgroundColor: Colors.white.withOpacity(0.1),
                child: CircleAvatar(
                  radius: 72,
                  backgroundColor: Colors.indigo.shade400,
                  child: Text(
                    callProvider.currentCall?.callerName[0].toUpperCase() ??
                        '?',
                    style: const TextStyle(
                      fontSize: 60,
                      color: Colors.white,
                      fontWeight: FontWeight.w200,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Audio Call Active',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (callProvider.remoteUid != null) {
      if (callProvider.isRemoteVideoOff) {
        return Container(
          color: const Color(0xFF0F0F1E),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  child: const Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Remote Camera Off',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: callProvider.engine!,
          canvas: VideoCanvas(uid: callProvider.remoteUid),
          connection: RtcConnection(
            channelId: callProvider.currentCall!.channelName,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.grey.shade900,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                'Waiting for ${callProvider.currentCall?.callerName} to join...',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _toolbar(CallProvider callProvider) {
    final isVideo = callProvider.currentCall?.callType == 'video';

    return Container(
      padding: const EdgeInsets.only(bottom: 50, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _circleButton(
                onPressed: callProvider.toggleMute,
                icon: callProvider.muted ? Icons.mic_off : Icons.mic,
                color: callProvider.muted
                    ? Colors.red.shade400
                    : Colors.white24,
                label: callProvider.muted ? 'Muted' : 'Mute',
              ),
              _circleButton(
                onPressed: callProvider.toggleSpeaker,
                icon: callProvider.isSpeakerOn
                    ? Icons.volume_up
                    : Icons.volume_down,
                color: callProvider.isSpeakerOn
                    ? Colors.green.shade700
                    : Colors.white24,
                label: 'Speaker',
              ),
              if (isVideo)
                _circleButton(
                  onPressed: callProvider.switchCamera,
                  icon: Icons.flip_camera_ios,
                  color: Colors.white24,
                  label: 'Flip',
                ),
              if (isVideo)
                _circleButton(
                  onPressed: callProvider.toggleCamera,
                  icon: callProvider.isCameraOff
                      ? Icons.videocam_off
                      : Icons.videocam,
                  color: callProvider.isCameraOff
                      ? Colors.red.shade400
                      : Colors.white24,
                  label: 'Camera',
                ),
            ],
          ),
          const SizedBox(height: 30),
          RawMaterialButton(
            onPressed: () async {
              await callProvider.endCall();
              if (mounted)
                Navigator.popUntil(context, (route) => route.isFirst);
            },
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(20.0),
            child: const Icon(Icons.call_end, color: Colors.white, size: 40.0),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      children: [
        RawMaterialButton(
          onPressed: onPressed,
          shape: const CircleBorder(),
          elevation: 0,
          fillColor: color,
          padding: const EdgeInsets.all(12.0),
          child: Icon(icon, color: Colors.white, size: 24.0),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
        ),
      ],
    );
  }
}
