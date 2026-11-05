import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class VoiceChangerPanel extends StatefulWidget {
  const VoiceChangerPanel({super.key});

  @override
  State<VoiceChangerPanel> createState() => _VoiceChangerPanelState();
}

class _VoiceChangerPanelState extends State<VoiceChangerPanel> {
  double _pitch = 0.0;
  String _currentPresetName = '原声';

  List<Map<String, dynamic>> _myPresets = [];
  static const String _prefsKey = 'my_voice_presets';

  @override
  void initState() {
    super.initState();
    _loadMyPresets();
  }

  Future<void> _loadMyPresets() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> strList = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) {
      setState(() {
        _myPresets =
            strList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      });
    }
  }

  // 修复：只传 pitch，去掉 formant
  void _applyDetailedPreset(String name, double pitch) async {
    setState(() {
      _currentPresetName = name;
      _pitch = pitch;
    });
    // 修复：枚举必须用 .None (首字母大写)
    await ZegoExpressEngine.instance
        .setVoiceChangerPreset(ZegoVoiceChangerPreset.None);
    ZegoVoiceChangerParam param = ZegoVoiceChangerParam(pitch);
    await ZegoExpressEngine.instance.setVoiceChangerParam(param);
  }

  void _applyCustom() async {
    setState(() {
      _currentPresetName = '手动微调';
    });
    await ZegoExpressEngine.instance
        .setVoiceChangerPreset(ZegoVoiceChangerPreset.None);
    ZegoVoiceChangerParam param = ZegoVoiceChangerParam(_pitch);
    await ZegoExpressEngine.instance.setVoiceChangerParam(param);
  }

  Future<void> _saveCurrentAsPreset() async {
    if (_pitch == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('原声不需要保存')));
      return;
    }
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('保存为专属预设', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
              hintText: '给声音起个名字', hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newPreset = {'name': controller.text, 'pitch': _pitch};
                final prefs = await SharedPreferences.getInstance();
                List<String> strList = prefs.getStringList(_prefsKey) ?? [];
                strList.add(jsonEncode(newPreset));
                await prefs.setStringList(_prefsKey, strList);
                if (mounted) {
                  Navigator.pop(context);
                  _loadMyPresets();
                  setState(() {
                    _currentPresetName = newPreset['name'] as String;
                  });
                }
              }
            },
            child:
                const Text('保存', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePreset(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> strList = prefs.getStringList(_prefsKey) ?? [];
    strList.removeAt(index);
    await prefs.setStringList(_prefsKey, strList);
    _loadMyPresets();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xF21A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🎛️ 高级变声调音台',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                Text(_currentPresetName,
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
              children: [
                _buildPresetBtn('原声', 0, Colors.grey[800]),
                _buildPresetBtn('甜美女声', 5, Colors.pink[800]),
                _buildPresetBtn('成熟男声', -4, Colors.blue[800]),
                _buildPresetBtn('稚嫩男童', 5, Colors.orange[800]),
                _buildPresetBtn('可爱女童', 8, Colors.pinkAccent[700]),
                _buildPresetBtn('沧桑男老', -4, Colors.brown[700]),
                _buildPresetBtn('慈祥女老', -2, Colors.purple[700]),
                _buildPresetBtn('机械电音', -2, Colors.teal[700]),
                _buildPresetBtn('外星音效', 8, Colors.green[800]),
              ],
            ),
            const Divider(color: Colors.white24, height: 30),
            if (_myPresets.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('⭐ 我的专属预设',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _myPresets.length,
                  itemBuilder: (context, index) {
                    final preset = _myPresets[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InputChip(
                        backgroundColor: Colors.blueGrey[800],
                        label: Text(preset['name'],
                            style: const TextStyle(color: Colors.white)),
                        onPressed: () => _applyDetailedPreset(
                            preset['name'], preset['pitch']),
                        onDeleted: () => _deletePreset(index),
                        deleteIconColor: Colors.redAccent,
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white24, height: 30),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🎚️ 高级微调',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _saveCurrentAsPreset,
                      icon: const Icon(Icons.save,
                          color: Colors.greenAccent, size: 16),
                      label: const Text('保存当前',
                          style: TextStyle(color: Colors.greenAccent)),
                    ),
                    TextButton(
                      onPressed: () => _applyDetailedPreset('原声', 0),
                      child: const Text('重置',
                          style: TextStyle(color: Colors.grey)),
                    )
                  ],
                )
              ],
            ),
            _buildSlider('音调 (Pitch)', _pitch, -12.0, 12.0, (val) {
              setState(() {
                _pitch = val;
              });
              _applyCustom();
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetBtn(String label, double pitch, Color? color) {
    bool isSelected = _currentPresetName == label;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[900],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 1)),
      ),
      onPressed: () => _applyDetailedPreset(label, pitch),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label : ${value.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Colors.greenAccent,
            inactiveColor: Colors.grey[800],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
