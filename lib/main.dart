import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/widgets/main_scaffold.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use platform-specific fonts
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    return MaterialApp(
      title: 'Parlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Use SF Pro on iOS, default system font on Android
        fontFamily: isIOS ? '.SF Pro Display' : null,
        // Apply SF Pro Text for text styles on iOS
        textTheme: isIOS 
            ? Theme.of(context).textTheme.apply(
                fontFamily: '.SF Pro Text',
                displayColor: Colors.black87,
                bodyColor: Colors.black87,
              )
            : null,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainScaffold(),
    );
  }
}
