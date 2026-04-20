import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'services/data_service.dart';
import 'services/translation_service.dart';
import 'services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode for easier use by elderly users
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialise services
  await DataService().init();
  await AppTranslations().loadSaved();
  await TtsService().init();

  runApp(const ElderlyReaderApp());
}

class ElderlyReaderApp extends StatefulWidget {
  const ElderlyReaderApp({super.key});

  @override
  State<ElderlyReaderApp> createState() => _ElderlyReaderAppState();
}

class _ElderlyReaderAppState extends State<ElderlyReaderApp> {
  // Rebuild the whole app when language changes so all strings update
  void _onLanguageChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTranslations().t('app_name'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: HomeScreen(onLanguageChanged: _onLanguageChanged),
    );
  }
}
