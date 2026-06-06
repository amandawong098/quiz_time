import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_android/image_picker_android.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/quiz_repository.dart';
import 'data/repositories/discussion_repository.dart';
import 'data/repositories/friendship_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ImagePickerPlatform imagePickerImplementation =
      ImagePickerPlatform.instance;
  if (imagePickerImplementation is ImagePickerAndroid) {
    imagePickerImplementation.useAndroidPhotoPicker = true;
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
        Provider<DiscussionRepository>(create: (_) => DiscussionRepository()),
        ChangeNotifierProvider<FriendshipRepository>(
          create: (_) => FriendshipRepository(),
        ),
      ],
      child: const LearnByteApp(),
    ),
  );
}

class LearnByteApp extends StatelessWidget {
  const LearnByteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LearnByte',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
    );
  }
}
