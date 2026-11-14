import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  int _currentIndex = 3; 
  String _inputNumber = '';
  String _role = '';
  bool _isIncoming = false; 
  
  static const platform = MethodChannel('com.example.my_dialer/command_channel');

  final Map<String, String> _letters = {
    '2': 'ABC', '3': 'DEF', '4': 'GHI', '5': 'JKL', '6': 'MNO',
    '7': 'PQRS', '8': 'TUV', '9': 'WXYZ', '0': '+'
  };

  @override
  void initState() {
    super.initState();
    _loadRole();
    
    // 监听原生蓝牙发来的“变脸”指令
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onBleCommand') {
        setState(() {
          _isIncoming = true;
          _inputNumber = '10086';
        });
      }
    });
  }

  Future<void> _loadRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String role = prefs.getString('device_role') ?? '未分配';
    setState(() => _role = role);

    // 如果 B 端是苹果，通知原生开启 BLE 广播
    if (role == 'B') {
      try {
        await platform.invokeMethod('startIosBleBroadcast');
      } catch (e) {
        debugPrint("开启原生广播失败: $e");
      }
    }
  }

  Future<void> _startFloatingWindow() async {
    try {
      await platform.invokeMethod('startFloatingWindow');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('悬浮窗已启动')));
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
    Color bgColor = isDark ? Colors.black : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black;
    Color keyBgColor = isDark ? const Color(0xFF333333) : const Color(0xFFE5E5EA);

    // B端完美接听界面
    if (_role == 'B' && _isIncoming) {
      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text('来电', style: TextStyle(color: Colors.white54, fontSize: 18)),
              const SizedBox(height: 10),
              Text(_inputNumber, style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w300)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isIncoming = false),
                    child: Container(
                      width: 75, height: 75,
                      decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isIncoming = false),
                    child: Container(
                      width: 75, height: 75,
                      decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                      child: const Icon(Icons.call, color: Colors.white, size: 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      );
    }

    // 主界面
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildPlaceholderTab('个人收藏', Icons.star_border, textColor, bgColor),
            _buildPlaceholderTab('最近通话', Icons.access_time, textColor, bgColor),
            _buildPlaceholderTab('通讯录', Icons.person_outline, textColor, bgColor),
            _buildDialerTab(textColor, keyBgColor, textColor),
            _buildPlaceholderTab('语音留言', Icons.voicemail, textColor, bgColor),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(isDark, textColor),
    );
  }

  Widget _buildBottomNavBar(bool isDark, Color textColor) {
    return Container(
      height: 80,
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
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon, color: isActive ? const Color(0xFF0A84FF) : Colors.grey, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? const Color(0xFF0A84FF) : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, IconData icon, Color textColor, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(title: Text(title), backgroundColor: bgColor, elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: Colors.grey[600]),
            const SizedBox(height: 10),
            Text('暂无$title', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
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
            child: Text(_inputNumber, style: TextStyle(fontSize: 40, color: textColor, letterSpacing: 2)),
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
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 70,
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请在悬浮窗上操作')));
                    } else if (_role == 'B') {
                      setState(() => _isIncoming = true);
                    }
                  }
                },
                child: Container(
                  width: 70, height: 70,
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
                  width: 70, alignment: Alignment.center,
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
        width: 75, height: 75,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(key, style: TextStyle(fontSize: 32, color: textColor, fontWeight: FontWeight.w400)),
            if (letter.isNotEmpty)
              Text(letter, style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}