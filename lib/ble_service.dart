import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  // 自定义 BLE 服务与特征值 UUID
  static final Guid serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid charUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  BluetoothDevice? connectedDevice;

  // A 端（安卓）：扫描并连接 B 端
  Future<bool> connectToB() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      BluetoothDevice? target;

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.advName.contains("MyDialer_B")) {
            target = r.device;
            break;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 15));
      await FlutterBluePlus.stopScan();

      if (target != null) {
        await target!.connect();
        connectedDevice = target;
        return true;
      }
    } catch (e) {
      print("A端连接失败: $e");
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
              await c.write(cmd.codeUnits);
              return;
            }
          }
        }
      }
    } catch (e) {
      print("发送指令失败: $e");
    }
  }

  // B 端（iOS）：尝试开启 BLE 广播（如果库支持）
  Future<void> startBleBroadcast() async {
    try {
      // 注意：由于当前锁定的是 1.31.15 版本，部分广播 API 可能不支持
      // 如果报错，需替换为 flutter_ble_peripheral 插件
      // await FlutterBluePlus.startAdvertising(advName: "MyDialer_B");
      print("准备开启 BLE 广播，等待 A 端连接...");
    } catch (e) {
      print("广播异常: $e");
    }
  }
}