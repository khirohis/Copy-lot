import 'package:flutter/material.dart';

void main() {
  runApp(const CopyLotApp());
}

class CopyLotApp extends StatelessWidget {
  const CopyLotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Copy-lot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Copy-lot'),
      ),
      body: const Center(
        child: Text('Copy-lot Ready'),
      ),
    );
  }
}
