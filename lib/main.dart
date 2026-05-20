import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/class_service.dart';
import 'services/student_service.dart';
import 'services/attendance_service.dart';
import 'services/statistics_service.dart';
import 'services/marks_service.dart';
import 'services/profile_service.dart';
import 'services/demo_service.dart';
import 'services/subscription_service.dart';
import 'services/device_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen_new.dart';
import 'screens/statistics_selection_screen.dart';
import 'screens/attendance_calendar_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/account_type_selection_screen.dart';
import 'screens/organization_payment_screen.dart';
import 'screens/organization_admin_screen.dart';
import 'models/class_model.dart';
import 'utils/app_theme.dart';
import 'screens/attendance_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ClassService()),
        ChangeNotifierProvider(create: (_) => StudentService()),
        ChangeNotifierProvider(create: (_) => AttendanceService()),
        ChangeNotifierProvider(create: (_) => StatisticsService()),
        ChangeNotifierProvider(create: (_) => MarksService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => DemoService()),
        ChangeNotifierProvider(create: (_) => SubscriptionService()),
        ChangeNotifierProvider(create: (_) => DeviceService()),
      ],
      child: MaterialApp(
        title: 'Edu Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreenNew(),
          '/statistics': (context) => const StatisticsSelectionScreen(),
          '/attendance': (context) => const AttendanceSelectionScreen(),
          '/account-type': (context) => const AccountTypeSelectionScreen(),
          // '/payment' handled in onGenerateRoute for pre-fill support
          '/organization-payment': (context) => const OrganizationPaymentScreen(),
          '/admin': (context) => const AdminPanelScreen(),
          '/organization-admin': (context) => const OrganizationAdminScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/payment') {
            final args = settings.arguments as Map<String, String?>?;
            return MaterialPageRoute(
              builder: (context) => PaymentScreen(
                prefillName: args?['name'],
                prefillEmail: args?['email'],
                prefillPhone: args?['phone'],
              ),
            );
          }
          if (settings.name == '/attendance') {
            final classItem = settings.arguments as ClassModel;
            return MaterialPageRoute(
              builder: (context) => AttendanceCalendarScreen(classItem: classItem),
            );
          }
          return null;
        },
      ),
    );
  }
}
