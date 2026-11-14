import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _role = '未分配';
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      setState(() => _role = prefs.getString('device_role') ?? '未分配');
    });
  }

  Future<void> _setRole(String role) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_role', role);
    setState(() => _role = role);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已选为 $role 端，重启App生效')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐藏设置页')),
      body: ListView(
        children: [
          ListTile(title: const Text('当前角色'), subtitle: Text(_role, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
          const Divider(),
          ListTile(title: const Text('选为 A 端 (安卓控制端)'), onTap: () => _setRole('A')),
          ListTile(title: const Text('选为 B 端 (苹果执行端)'), onTap: () => _setRole('B')),
          ListTile(title: const Text('选为 C 端 (变声端)'), onTap: () => _setRole('C')),
        ],
      ),
    );
  }
}