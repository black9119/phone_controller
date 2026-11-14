import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  // 自定义的 BLE 服务与特征值 UUID
  static final Guid serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid charUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  BluetoothDevice? connectedDevice;
  Function(String command)? onCommandReceived;

  // ================= A 端（安卓）：搜索并连接 B 端 =================
  Future<bool> scanAndConnect() async {
    try {
      // 开启扫描
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      BluetoothDevice? target;
      
      // 监听扫描结果
      var subscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.advName.contains("MyDialer_B")) {
            target = r.device;
            break;
          }
        }
      });

      // 等待扫描结束
      await Future.delayed(const Duration(seconds: 10));
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      if (target != null) {
        await target!.connect();
        connectedDevice = target;
        return true;
      }
    } catch (e) {
      print("扫描连接异常: $e");
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
            if (c.uuid == charUuid) {
              await c.write(utf8.encode(cmd));
              return;
            }
          }
        }
      }
    } catch (e) {
      print("发送失败: $e");
    }
  }

  // ================= B 端（苹果）：开启广播等待连接 =================
  Future<void> startPeripheral() async {
    try {
      // 注意：flutter_blue_plus 在 iOS 上作为外设广播需要通过特定 API
      // 为了让 B 端能接收，这里开启 BLE 广播
      await FlutterBluePlus.startAdvertising(
        advName: "MyDialer_B",
      );
      print("B端已开启BLE广播等待连接");
      
      // 在真实生产环境中，iOS 端的特征值写入监听需要原生配合
      // 为了快速跑通，如果 A 端连上了 B 端的广播，你可以触发后续逻辑
      
    } catch (e) {
      print("B端广播失败: $e");
    }
  }
}