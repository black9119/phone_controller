import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BleService {
  // 统一的服务 UUID
  static final Guid serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid charUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  BluetoothDevice? connectedDevice;
  
  // B端接收指令的回调
  Function(String command)? onCommandReceived;

  // ================= A 端（安卓）：扫描并连接 =================
  Future<bool> scanAndConnect() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      BluetoothDevice? target;

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // 找 B 端的广播名字
          if (r.device.advName.contains("MyDialer_B") || r.device.name.contains("MyDialer_B")) {
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
      print("发送失败: $e");
    }
  }

  // ================= B 端（苹果）：开启真正的广播 =================
  Future<void> startBroadcasting() async {
    try {
      // 监听 A 端发来的数据
      _peripheral.onDataReceived.listen((event) {
        if (onCommandReceived != null) {
          // 将收到的字节转为字符串触发回调
          String cmd = String.fromCharCodes(event.data);
          onCommandReceived!(cmd);
        }
      });

      // 开启广播，让安卓能搜到
      await _peripheral.startAdvertising(
        advertiseData: AdvertiseData(
          serviceUuid: "0000ffe0-0000-1000-8000-00805f9b34fb",
          localName: "MyDialer_B",
        ),
        settings: const AdvertiseSettings(
          connectable: true,
          timeout: Duration(minutes: 0), // 永不超时
        ),
      );
      print("B端广播已开启，设备名: MyDialer_B");
    } catch (e) {
      print("B端开启广播失败: $e");
    }
  }

  // 停止广播
  Future<void> stopBroadcasting() async {
    await _peripheral.stopAdvertising();
  }
}