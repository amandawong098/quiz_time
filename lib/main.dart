import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/quiz_repository.dart';
import 'core/providers/locale_provider.dart';
import 'core/services/gemini_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quiz_time/l10n/app_localizations.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Silently ignore if .env is not found (e.g. for users who clone the repo)
    // The GeminiService will fall back to SharedPreferences.
  }

  await Supabase.initialize(
    url: 'https://tseptwtbdkdaikmpzmkl.supabase.co',
    anonKey: 'sb_publishable_KoNEhNpkVClSsmAmEMJ0aw_SMndfMv6',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<QuizRepository>(create: (_) => QuizRepository()),

        Provider<GeminiService>(create: (_) => GeminiService()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const QuizTimeApp(),
    ),
  );
}

class QuizTimeApp extends StatelessWidget {
  const QuizTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return MaterialApp.router(
      title: 'QuizTime',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
