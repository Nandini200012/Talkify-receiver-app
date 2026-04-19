import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _animationController;
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startRingtoneAndVibration();
  }

  Future<void> _startRingtoneAndVibration() async {
    try {
      debugPrint("Attempting to play ringtone...");

      _ringtonePlayer.onPlayerStateChanged.listen((state) {
        debugPrint("Ringtone Player State: $state");
      });

      await _ringtonePlayer.setVolume(1.0);
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);

      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('ringtone.mp3'));

      debugPrint("Play command issued.");

      if (await Vibration.hasVibrator()) {
        debugPrint("Starting vibration pattern...");
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
    } catch (e) {
      debugPrint("FATAL ERROR in ringtone/vibration: $e");
    }
  }

  void _stopRingtoneAndVibration() {
    _ringtonePlayer.stop();
    Vibration.cancel();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopRingtoneAndVibration();
    _ringtonePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final call = callProvider.currentCall;

    if (call == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final String callType = call.callType.toLowerCase();
    final bool isVideo = callType == 'video';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: isVideo
                ? Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://images.unsplash.com/photo-1511367461989-f85a21fda167?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(color: Colors.black.withOpacity(0.5)),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1A1A32), Color(0xFF0F0F1E)],
                      ),
                    ),
                  ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),

                Column(
                  children: [
                    Icon(
                      isVideo ? Icons.videocam : Icons.mic,
                      color: Colors.white70,
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'INCOMING ${call.callType.toUpperCase()} CALL',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    ...List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          double delay = index * 0.3;
                          double val =
                              (_animationController.value + delay) % 1.0;
                          return Container(
                            width: 140 + (100 * val),
                            height: 140 + (100 * val),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(
                                  0.15 * (1 - val),
                                ),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      );
                    }),

                    CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: CircleAvatar(
                        radius: 64,
                        backgroundColor: Colors.indigo.shade400,
                        child: Text(
                          call.callerName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Text(
                  call.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Talkify Call',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),

                const Spacer(),

                if (_isProcessing)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCallButton(
                          icon: Icons.close,
                          label: 'Decline',
                          color: Colors.red.shade400,
                          onTap: () async {
                            setState(() => _isProcessing = true);
                            await callProvider.rejectCall();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Call rejected')),
                              );
                              callProvider.setShowingIncomingUI(false);
                              Navigator.pop(context);
                            }
                          },
                        ),
                        _buildCallButton(
                          icon: isVideo ? Icons.videocam : Icons.call,
                          label: 'Accept',
                          color: Colors.greenAccent.shade400,
                          onTap: () async {
                            setState(() => _isProcessing = true);
                            try {
                              final accepted = await callProvider.acceptCall();

                              if (mounted) {
                                if (accepted) {
                                  Navigator.pushReplacement(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => const CallScreen(),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            );
                                          },
                                      transitionDuration: const Duration(
                                        milliseconds: 250,
                                      ),
                                    ),
                                  );
                                } else {
                                  setState(() => _isProcessing = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Failed to connect call. Please try again.",
                                      ),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted)
                                setState(() => _isProcessing = false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
