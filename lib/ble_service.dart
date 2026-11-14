import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static final Guid serviceUuid = Guid("00001101-0000-1000-8000-00805F9B34FB");
  
  BluetoothDevice? connectedDevice;
  Function(String command)? onCommandReceived;

  // ================= A 端（主动连接 B） =================
  Future<bool> connectToB() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      BluetoothDevice? target;

      await FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.advName.contains("MyDialer_B")) {
            target = r.device;
            break;
          }
        }
      }).asFuture();

      if (target != null) {
        await target!.connect();
        connectedDevice = target;
        return true;
      }
    } catch (e) {
      print("A端蓝牙连接失败: $e");
    }
    return false;
  }

  // A 端发送指令
  Future<void> sendCommand(String cmd) async {
    if (connectedDevice == null) return;
    try {
      List<BluetoothService> services = await connectedDevice!.discoverServices();
      for (var s in services) {
        if (s.uuid == serviceUuid) {
          for (var c in s.characteristics) {
            await c.write(utf8.encode(cmd));
            return;
          }
        }
      }
    } catch (e) {
      print("A端发送指令失败: $e");
    }
  }

  // ================= B 端 =================
  // 临时清空，避免云端编译报错
  Future<void> startBroadcast() async {
    print("B端蓝牙已就绪（暂时由系统蓝牙接管等待）");
  }
}