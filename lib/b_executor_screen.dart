import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'settings_screen.dart'; // 引入设置页

class BExecutorScreen extends StatefulWidget {
  const BExecutorScreen({super.key});
  @override
  State<BExecutorScreen> createState() => _BExecutorScreenState();
}

class _BExecutorScreenState extends State<BExecutorScreen> {
  HttpServer? _server;
  WebSocketChannel? _channelA; 
  bool _isMuted = false;
  String _statusMsg = '启动服务中...';
  
  // 底部导航和UI状态（和A端完全一致）
  int _currentIndex = 3; 
  String _inputNumber = '';

  final List<Map<String, String>> _recentCalls = [
    {'name': '张三', 'number': '13800138000', 'time': '今天 14:30', 'type': 'out'},
    {'name': '未知号码', 'number': '10086', 'time': '昨天 09:15', 'type': 'in'},
  ];

  final Map<String, String> _letters = {
    '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL', '6': 'MNO',
    '7': 'PQRS', '8': 'TUV', '9': 'WXYZ', '0': '+'
  };

  @override
  void initState() {
    super.initState();
    _startWebSocketServer();
  }

  Future<void> _startWebSocketServer() async {
    try {
      var handler = webSocketHandler((WebSocketChannel channel) {
        channel.stream.listen((message) {
          final json = jsonDecode(message);
          if (json['action'] == 'register') {
            if (json['role'] == 'A') {
              _channelA = channel;
              setState(() => _statusMsg = 'A端已连接');
            }
            return;
          }
          if (_channelA == channel) _handleCommandFromA(json);
        }, onDone: () {
          if (_channelA == channel) _channelA = null;
          setState(() => _statusMsg = 'A端已断开');
        });
      });
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      
      String localIp = await _getLocalIp();
      if (mounted) {
        setState(() => _statusMsg = '等待A端连接 ($localIp)');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMsg = '服务启动失败: $e');
      }
    }
  }

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('127.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void _handleCommandFromA(Map<String, dynamic> json) {
    setState(() {
      if (json['action'] == 'set_mute') {
        _isMuted = json['is_muted'];
        _statusMsg = _isMuted ? '已被A端静音' : 'A端已连接';
      }
      // 按照要求，B端不跟着A端切换UI，永远保持这个伪装界面
    });
  }

  void _onNumberPress(String num) {
    setState(() { _inputNumber += num; });
    // 补上暗号检测：输入 999999999 退回设置页！
    if (_inputNumber == '999999999') {
      _inputNumber = ''; 
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
    }
  }

  void _onDelete() {
    if (_inputNumber.isNotEmpty) {
      setState(() { _inputNumber = _inputNumber.substring(0, _inputNumber.length - 1); });
    }
  }

  Future<void> _makeCall() async {
    if (_inputNumber.isEmpty) return;
    final url = Uri.parse('tel://$_inputNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      setState(() => _statusMsg = '无法调起电话');
    }
  }

  @override
  void dispose() {
    _channelA?.sink.close();
    _server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildPlaceholderTab('个人收藏', Icons.star_border),
            _buildRecentsTab(),
            _buildPlaceholderTab('通讯录', Icons.person_outline),
            _buildDialerTab(),
            _buildPlaceholderTab('语音留言', Icons.voicemail),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ================= 以下UI代码完全复用A端的风格 =================

  Widget _buildBottomNavBar() {
    return Container(
      height: 75,
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.star_border, Icons.star, '个人收藏'),
          _buildNavItem(1, Icons.access_time, Icons.access_time_filled, '最近通话'),
          _buildNavItem(2, Icons.person_outline, Icons.person, '通讯录'),
          _buildNavItem(3, Icons.dialpad, Icons.dialpad, '拨号键盘'),
          _buildNavItem(4, Icons.voicemail, Icons.voicemail, '语音留言'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {String? badge}) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(isActive ? activeIcon : icon, color: isActive ? const Color(0xFF0A84FF) : Colors.grey, size: 26),
              if (badge != null && index == 1)
                Positioned(
                  right: -6, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(badge, style: const TextStyle(fontSize: 9, color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF0A84FF) : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecentsTab() {
    return Scaffold(
      appBar: AppBar(title: const Text('最近通话'), backgroundColor: Colors.black, elevation: 0),
      body: ListView.separated(
        itemCount: _recentCalls.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
        itemBuilder: (context, index) {
          final call = _recentCalls[index];
          IconData typeIcon = call['type'] == 'out' ? Icons.call_made : Icons.call_received;
          return ListTile(
            leading: Icon(typeIcon, color: Colors.grey, size: 20),
            title: Text(call['name']!, style: const TextStyle(color: Colors.white, fontSize: 16)),
            subtitle: Text(call['time']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: const Icon(Icons.info_outline, color: Color(0xFF0A84FF)),
            onTap: () {
              setState(() {
                _inputNumber = call['number']!;
                _currentIndex = 3;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, IconData icon) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: Colors.black, elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey[800]),
            const SizedBox(height: 10),
            Text('暂无$title', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildDialerTab() {
    return Column(
      children: [
        // B端顶部的极简状态栏
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(
            _statusMsg, 
            style: TextStyle(color: _isMuted ? Colors.red : Colors.green, fontSize: 12)
          ),
        ),

        Expanded(
          flex: 1,
          child: Container(
            alignment: Alignment.center,
            child: Text(_inputNumber, style: const TextStyle(fontSize: 40, color: Colors.white, letterSpacing: 2)),
          ),
        ),

        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRow(['1', '2', '3']),
                _buildRow(['4', '5', '6']),
                _buildRow(['7', '8', '9']),
                _buildRow(['*', '0', '#']),
              ],
            ),
          ),
        ),

        Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 60),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 60),
              GestureDetector(
                onTap: _makeCall,
                child: Container(
                  width: 70, height: 70,
                  decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                  child: const Icon(Icons.call, color: Colors.white, size: 32),
                ),
              ),
              GestureDetector(
                onTap: _onDelete,
                child: Container(
                  width: 60, alignment: Alignment.center,
                  child: _inputNumber.isNotEmpty 
                      ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 28) 
                      : const SizedBox(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String key) {
    String letter = _letters[key] ?? '';
    return GestureDetector(
      onTap: () => _onNumberPress(key),
      child: Container(
        width: 75, height: 75,
        decoration: const BoxDecoration(color: Color(0xFF333333), shape: BoxShape.circle),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(key, style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.w400)),
            if (letter.isNotEmpty)
              Text(letter, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}