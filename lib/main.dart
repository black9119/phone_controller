import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dialer_screen.dart';
import 'b_executor_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '伪装电话',
      theme: ThemeData.dark(),
      home: const RoleDispatcherScreen(),
    );
  }
}

class RoleDispatcherScreen extends StatefulWidget {
  const RoleDispatcherScreen({super.key});
  @override
  State<RoleDispatcherScreen> createState() => _RoleDispatcherScreenState();
}

class _RoleDispatcherScreenState extends State<RoleDispatcherScreen> {
  static const platform = MethodChannel('com.example.phone_controller/command_channel');
  String _statusMsg = '正在初始化...';
  
  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String role = prefs.getString('device_role') ?? '';
    String targetIp = prefs.getString('target_ip') ?? '10.0.2.2';

    if (!mounted) return;

    if (role == 'A') {
      setState(() { _statusMsg = '正在尝试启动悬浮窗...'; });
      try {
        await platform.invokeMethod('startCommandServer', {'targetIp': targetIp});
        setState(() { _statusMsg = '指挥端后台运行中\n悬浮窗已启动，请切回QQ'; });
      } catch (e) {
        setState(() { _statusMsg = '悬浮窗启动失败: $e\n请检查悬浮窗权限是否开启'; });
      }
    } else if (role == 'B') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BExecutorScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DialerScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Text(_statusMsg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white)),
          ),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                onPressed: () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.remove('device_role');
                  if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DialerScreen()));
                },
                child: const Text('清空角色并返回拨号盘', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}