import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../call/incoming_call_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAndStartCallListener();
  }

  void _checkAndStartCallListener() {
    if (_isListening) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userModel != null) {
      final callProvider = Provider.of<CallProvider>(context, listen: false);
      callProvider.listenForIncomingCalls(auth.userModel!.uid, context);
      callProvider.requestPermissions(); // Request permissions initially
      _isListening = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Background presence is now handled by BackgroundService
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              await auth.logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out successfully')),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkAndStartCallListener();
    final auth = Provider.of<AuthProvider>(context);
    final callProvider = Provider.of<CallProvider>(context);

    // Listen for incoming call in the UI using a more robust method
    if (callProvider.currentCall != null &&
        callProvider.currentCall!.status == 'ringing' &&
        !callProvider.isShowingIncomingUI) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double check condition inside callback
        if (mounted &&
            !callProvider.isShowingIncomingUI &&
            ModalRoute.of(context)?.isCurrent == true) {
          callProvider.setShowingIncomingUI(true);
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const IncomingCallScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 250),
            ),
          );
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.1),
              child: Text(
                auth.userModel?.name.isNotEmpty == true
                    ? auth.userModel!.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Hello, ${auth.userModel?.name.split(' ')[0] ?? 'User'}!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Waiting for calls...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _showLogoutConfirmation,
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A32), Color(0xFF0F0F1E)],
          ),
        ),
        child: Center(
          child: auth.userModel == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.indigo.shade100.withOpacity(
                            0.1,
                          ),
                          child: Text(
                            auth.userModel!.name.isNotEmpty
                                ? auth.userModel!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w200,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: auth.userModel!.isOnline
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F0F1E),
                              width: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome, ${auth.userModel!.name}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.userModel!.isOnline ? 'Online & Ready' : 'Offline',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Waiting for incoming calls...',
                      style: TextStyle(color: Colors.white38, letterSpacing: 1),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
