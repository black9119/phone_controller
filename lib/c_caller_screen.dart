import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'call_log_manager.dart';
import 'voice_changer_panel.dart';

class CCallerScreen extends StatefulWidget {
  const CCallerScreen({super.key});
  @override
  State<CCallerScreen> createState() => _CCallerScreenState();
}

class _CCallerScreenState extends State<CCallerScreen> {
  bool _isInCall = false;
  bool _isRinging = false;
  String _incomingNumber = '';
  String _roomID = '';
  int _callDuration = 0;
  Timer? _timer;
  bool _isMuted = false;

  // ⚠️ 填入你的 ZEGO 配置
  final int appID = 000000000;
  final String appSign = "your_app_sign_here";
  final String _controlRoomID = "CALL_CONTROL_ROOM_888";

  @override
  void initState() {
    super.initState();
    _initZego();
  }

  Future<void> _initZego() async {
    // 初始化 ZEGO 引擎
    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(appID, ZegoScenario.StandardVoiceCall,
          appSign: appSign),
    );

    // 开启耳返（如果你戴蓝牙耳机，能实时听到自己变声）
    await ZegoExpressEngine.instance.enableHeadphoneMonitor(true);

    // 监听 B 端发来的呼叫信令 (修复：使用正确的 3 个参数)
    ZegoExpressEngine.onIMRecvCustomCommand =
        (String roomID, ZegoUser fromUser, String command) {
      final json = jsonDecode(command);
      if (json['action'] == 'incoming_call') {
        setState(() {
          _isRinging = true;
          _incomingNumber = json['number'] ?? '未知号码';
          _roomID = json['room_id'];
        });
      }
    };

    // 登录控制房间待命
    await ZegoExpressEngine.instance
        .loginRoom(_controlRoomID, ZegoUser("C_user", "C端"));
  }

  Future<void> _acceptCall() async {
    setState(() {
      _isRinging = false;
      _isInCall = true;
    });
    _startTimer();

    // 退出控制房间，进入通话房间
    await ZegoExpressEngine.instance.logoutRoom(_controlRoomID);
    await ZegoExpressEngine.instance
        .loginRoom(_roomID, ZegoUser("C_user", "C端"));
    await ZegoExpressEngine.instance.startPublishingStream("C_stream");

    // 监听房间内 B 端的流并拉取
    ZegoExpressEngine.onRoomStreamUpdate =
        (roomID, updateType, streamList, extendedData) {
      if (updateType == ZegoUpdateType.Add) {
        for (var stream in streamList) {
          if (stream.streamID.contains("B_stream")) {
            ZegoExpressEngine.instance.startPlayingStream(stream.streamID);
          }
        }
      }
    };
  }

  void _startTimer() {
    _callDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted)
        setState(() {
          _callDuration++;
        });
    });
  }

  void _stopCall() {
    _timer?.cancel();
    ZegoExpressEngine.instance.stopPublishingStream();
    ZegoExpressEngine.instance.logoutRoom(_roomID);
    // 挂断后回到控制房间待命
    ZegoExpressEngine.instance
        .loginRoom(_controlRoomID, ZegoUser("C_user", "C端"));

    // 保存通话记录
    CallLogManager.saveRecord({
      'number': _incomingNumber,
      'time': DateTime.now().toIso8601String(),
      'duration': _callDuration,
      'type': '呼入',
    });

    setState(() {
      _isInCall = false;
      _incomingNumber = '';
      _callDuration = 0;
    });
  }

  void _showVoiceChanger() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceChangerPanel(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    // 修复：使用静态方法销毁引擎
    ZegoExpressEngine.destroyEngine();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isRinging) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_in_talk, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text('来自: $_incomingNumber',
                  style: const TextStyle(fontSize: 32, color: Colors.white)),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(24)),
                    onPressed: () => setState(() => _isRinging = false),
                    child: const Icon(Icons.call_end,
                        color: Colors.white, size: 36),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(24)),
                    onPressed: _acceptCall,
                    child:
                        const Icon(Icons.call, color: Colors.white, size: 36),
                  ),
                ],
              )
            ],
          ),
        ),
      );
    }

    if (_isInCall) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 60, child: Icon(Icons.person, size: 70)),
            const SizedBox(height: 20),
            Text(_incomingNumber,
                style: const TextStyle(fontSize: 32, color: Colors.white)),
            const SizedBox(height: 10),
            Text(_formatDuration(_callDuration),
                style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionIcon(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: "静音",
                  isActive: _isMuted,
                  onTap: () {
                    setState(() {
                      _isMuted = !_isMuted;
                    });
                    ZegoExpressEngine.instance.muteMicrophone(_isMuted);
                  },
                ),
                _buildActionIcon(
                    icon: Icons.tune,
                    label: "变声调音台",
                    isActive: true,
                    onTap: _showVoiceChanger),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(24)),
              onPressed: _stopCall,
              child: const Icon(Icons.call_end, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 50),
          ],
        ),
      );
    }

    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
          child: Text('C端待命中...',
              style: TextStyle(color: Colors.green, fontSize: 18))),
    );
  }

  Widget _buildActionIcon(
      {required IconData icon,
      required String label,
      required bool isActive,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  isActive ? Colors.green.withOpacity(0.3) : Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isActive ? Colors.greenAccent : Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
