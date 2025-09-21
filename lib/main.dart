import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:Growio/screens/auth/email_confirmation.dart';
import 'package:Growio/screens/events.dart';
import 'package:Growio/screens/plant_analysis_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/guest_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/community_notification_handler.dart';
import 'services/plant_reminder_service.dart';
import 'screens/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
        // Add notification services
        Provider(create: (_) => NotificationService()),
        Provider(create: (_) => CommunityNotificationHandler()),
        Provider(create: (_) => PlantReminderService()),
      ],
      child: const GrowioApp(),
    ),
  );
}

class GrowioApp extends StatelessWidget {
  const GrowioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Growio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/confirm-email': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ConfirmEmailScreen(email: args['email']);
        },
        '/guest': (context) => const GuestHomeScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/notifications': (context) => const NotificationsScreen(), // Add notifications route
        '/events': (context) =>const EventsPage(),
        '/scan_result': (context) => PlantAnalysisScreen(),

      },
    );
  }
}

// Auth wrapper to check authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late CommunityNotificationHandler _notificationHandler;
  late PlantReminderService _plantReminderService;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotificationServices();
  }

  void _initializeNotificationServices() {
    // Initialize notification handlers
    _notificationHandler = CommunityNotificationHandler();
    _plantReminderService = PlantReminderService();

    // Setup notification listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationHandler.setupPostUpvoteListener();
      _notificationHandler.setupCommentListeners();

      // Setup periodic plant reminders (every 6 hours)
      _reminderTimer = Timer.periodic(const Duration(hours: 6), (timer) {
        _plantReminderService.sendRandomPlantReminders();
        _plantReminderService.sendCareTips();
      });
    });
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.getCurrentUser();

    // Show loading screen briefly while checking auth state
    if (authService.isLoading) {
      return _buildLoadingScreen();
    }

    if (user != null) {
      // User is logged in, navigate to home screen
      return const HomeScreen();
    } else {
      // User is not logged in, show welcome screen
      return const WelcomeScreen();
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade700,
              Colors.green.shade800,
              Colors.green.shade600,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Growio...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}