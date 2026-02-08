import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter/services.dart';


// Note: Folder structure unchanged
import 'screens/splash.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'providers/subscription_provider.dart';
import 'services/revenue_cat_service.dart';
import 'utils/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize RevenueCat
  await RevenueCatService.initialize();

  // Enable Edge-to-Edge for Android 15+
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    Phoenix(
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DataProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Fyllo AI',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: FylloColors.defaultCyan, // New brand color
          brightness: Brightness.dark,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
