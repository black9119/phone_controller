import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';
import 'ble_service.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  int _currentIndex = 3; 
  String _inputNumber = '';
  String _role = '';
  bool _isCalling = false;
  final BleService _ble = BleService();
  
  static const platform = MethodChannel('com.example.my_dialer/command_channel');

  final Map<String, String> _letters = {
    '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL', '6': 'MNO',
    '7': 'PQRS', '8': 'TUV', '9': 'WXYZ', '0': '+'
  };

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String role = prefs.getString('device_role') ?? '未分配';
    setState(() => _role = role);

    // 根据角色初始化蓝牙
    if (role == 'A') {
      _ble.connectToB().then((success) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('蓝牙已连接 B 端')));
        }
      });
    } else if (role == 'B') {
      _ble.startBroadcast();
      _ble.onCommandReceived = (command) {
        if (command == 'start_call') {
          setState(() {
            _isCalling = true;
            _inputNumber = '10086'; // 伪装号码
          });
        }
      };
    }
  }

  Future<void> _startFloatingWindow() async {
    try {
      await platform.invokeMethod('startFloatingWindow');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('悬浮窗已启动，请切回桌面')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('拉起失败: $e')));
    }
  }

  void _onNumberPress(String num) {
    setState(() => _inputNumber += num);
    if (_inputNumber == '999999999') {
      _inputNumber = ''; 
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) => _loadRole());
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color bgColorTop = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    Color bgColorBottom = isDark ? const Color(0xFF151515) : const Color(0xFFF2F2F7);
    Color textColor = isDark ? Colors.white : Colors.black;
    Color keyBgColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA);
    Color keyTextColor = isDark ? Colors.white : Colors.black;

    if (_isCalling) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: isDark ? [const Color(0xFF2C2C2E), const Color(0xFF000000)] : [Colors.white, const Color(0xFFF2F2F7)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Text('正在呼叫...', style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 16, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Text(_inputNumber, style: TextStyle(color: textColor, fontSize: 44, fontWeight: FontWeight.w400, letterSpacing: 2)),
                const Spacer(flex: 2),
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isCalling = false),
                      child: Container(
                        width: 75, height: 75,
                        decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('结束', style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [bgColorTop, bgColorBottom],
          ),
        ),
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildInternalTab('个人收藏', Icons.star_border, textColor),
              _buildInternalTab('最近通话', Icons.access_time, textColor),
              _buildInternalTab('通讯录', Icons.person_outline, textColor),
              _buildDialerTab(textColor, keyBgColor, keyTextColor),
              _buildInternalTab('语音留言', Icons.voicemail, textColor),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(isDark, textColor),
    );
  }

  Widget _buildBottomNavBar(bool isDark, Color textColor) {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12, width: 0.5)),
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

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    bool isActive = _currentIndex == index;
    Color activeColor = const Color(0xFF0A84FF);
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon, color: isActive ? activeColor : Colors.grey, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? activeColor : Colors.grey, fontWeight: isActive ? FontWeight.w500 : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildInternalTab(String title, IconData icon, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('暂无$title', style: const TextStyle(color: Colors.grey, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildDialerTab(Color textColor, Color keyBgColor, Color keyTextColor) {
    return Column(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            alignment: Alignment.center,
            child: Text(_inputNumber, style: TextStyle(fontSize: 42, color: textColor, letterSpacing: 3, fontWeight: FontWeight.w400)),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRow(['1', '2', '3'], keyBgColor, keyTextColor),
                _buildRow(['4', '5', '6'], keyBgColor, keyTextColor),
                _buildRow(['7', '8', '9'], keyBgColor, keyTextColor),
                _buildRow(['*', '0', '#'], keyBgColor, keyTextColor),
              ],
            ),
          ),
        ),
        Container(
          height: 110,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 75,
                child: _role == 'A' 
                  ? GestureDetector(
                      onTap: _startFloatingWindow,
                      child: Container(
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.layers, color: Colors.blue, size: 28),
                      ),
                    )
                  : const SizedBox(),
              ),
              GestureDetector(
                onTap: () {
                  if (_inputNumber.isNotEmpty) {
                    if (_role == 'A') {
                      // A 端：触发蓝牙发送指令
                      _ble.sendCommand('start_call');
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('蓝牙指令已发送')));
                    } else if (_role == 'B') {
                      // B 端：本地伪装
                      setState(() => _isCalling = true);
                    }
                  }
                },
                child: Container(
                  width: 75, height: 75,
                  decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                  child: const Icon(Icons.call, color: Colors.white, size: 32),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (_inputNumber.isNotEmpty) {
                    setState(() => _inputNumber = _inputNumber.substring(0, _inputNumber.length - 1));
                  }
                },
                child: Container(
                  width: 75, alignment: Alignment.center,
                  child: _inputNumber.isNotEmpty ? Icon(Icons.backspace_outlined, color: textColor, size: 28) : const SizedBox(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildRow(List<String> keys, Color bgColor, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key, bgColor, textColor)).toList(),
    );
  }

  Widget _buildKey(String key, Color bgColor, Color textColor) {
    String letter = _letters[key] ?? '';
    return GestureDetector(
      onTap: () => _onNumberPress(key),
      child: Container(
        width: 78, height: 78,
        decoration: BoxDecoration(
          color: bgColor, 
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(key, style: TextStyle(fontSize: 34, color: textColor, fontWeight: FontWeight.w400)),
            if (letter.isNotEmpty)
              Text(letter, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}