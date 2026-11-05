import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CallLogManager {
  static const String _key = 'call_records';

  // 保存一条记录
  static Future<void> saveRecord(Map<String, dynamic> record) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> records = prefs.getStringList(_key) ?? [];
    records.insert(0, jsonEncode(record)); // 最新的插在最前面
    await prefs.setStringList(_key, records);
  }

  // 获取所有记录
  static Future<List<Map<String, dynamic>>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> records = prefs.getStringList(_key) ?? [];
    return records.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }
}
