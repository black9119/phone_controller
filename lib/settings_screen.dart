import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentRole = '未分配';
  final TextEditingController _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentRole = prefs.getString('device_role') ?? '未分配';
        _ipController.text = prefs.getString('target_ip') ?? '10.0.2.2';
      });
    }
  }

  Future<void> _setRole(String role) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // 1. 强制写入硬盘
    await prefs.setString('device_role', role);
    
    // 2. 强制等待 1 秒钟（确保安卓系统把文件彻底存死，你手再快也切不断它）
    await Future.delayed(const Duration(seconds: 1)); 
    
    if (mounted) {
      setState(() { _currentRole = role; });
      // 3. 弹出一个醒目的提示框
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 角色已保存为 $role，请立即杀掉后台并重新打开！'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _saveIp(String ip) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('target_ip', ip);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('目标 IP 已保存')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐藏设置页')),
      body: ListView(
        children: [
          ListTile(title: const Text('当前角色'), subtitle: Text(_currentRole, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
          const Divider(),
          ListTile(
            title: const Text('选为 A 端 (指挥端)'),
            trailing: _currentRole == 'A' ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () => _setRole('A'),
          ),
          ListTile(
            title: const Text('选为 B 端 (执行端)'),
            trailing: _currentRole == 'B' ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () => _setRole('B'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('A端填写: 目标 B 端的 IP 地址', style: TextStyle(fontSize: 14, color: Colors.grey)),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _ipController, keyboardType: TextInputType.number)),
                    ElevatedButton(
                      onPressed: () => _saveIp(_ipController.text),
                      child: const Text('保存 IP'),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}