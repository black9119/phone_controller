import 'package:flutter/material.dart';
import 'dialer_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '伪装电话',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white),
      darkTheme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      themeMode: ThemeMode.system,
      home: const DialerScreen(),
    );
  }
}