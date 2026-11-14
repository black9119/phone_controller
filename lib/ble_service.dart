import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  // 自定义蓝牙服务 UUID
  static final Guid serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid charUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  BluetoothDevice? connectedDevice;
  Function(String command)? onCommandReceived;

  // ================= A 端 =================
  Future<bool> connectToB() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      BluetoothDevice? target;
      
      await FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.advName.contains("Dialer_B") || r.device.platformName.contains("Dialer_B")) {
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

  Future<void> sendCommand(String cmd) async {
    if (connectedDevice == null || !connectedDevice!.isConnected) {
      bool reconnected = await connectToB();
      if (!reconnected) return;
    }
    try {
      List<BluetoothService> services = await connectedDevice!.discoverServices();
      for (var s in services) {
        if (s.uuid == serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid == charUuid) {
              await c.write(utf8.encode(cmd));
              return;
            }
          }
        }
      }
    } catch (e) {
      print("A端发送指令失败: $e");
    }
  }

  // ================= B 端 =================
  Future<void> startBroadcast() async {
    try {
      await FlutterBluePlus.startAdvertising(
        advName: "Dialer_B",
        timeout: const Duration(minutes: 0),
      );
      print("B端广播已开启");
    } catch (e) {
      print("B端开启广播失败: $e");
    }
  }
}