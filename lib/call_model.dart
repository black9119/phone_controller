import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CallRecord {
  final String number;
  final String timeStr;
  final String duration;
  final bool isMissed;

  CallRecord(
      {required this.number,
      required this.timeStr,
      required this.duration,
      this.isMissed = false});

  Map<String, dynamic> toJson() => {
        'number': number,
        'timeStr': timeStr,
        'duration': duration,
        'isMissed': isMissed
      };
  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(
      number: json['number'],
      timeStr: json['timeStr'],
      duration: json['duration'],
      isMissed: json['isMissed'] ?? false);
}

class RecordManager {
  static const String key = 'call_records';

  static Future<List<CallRecord>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return [];
    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) => CallRecord.fromJson(e)).toList();
  }

  static Future<void> addRecord(CallRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await getRecords();
    records.insert(0, record); // 插在最前面
    prefs.setString(key, jsonEncode(records.map((e) => e.toJson()).toList()));
  }
}
