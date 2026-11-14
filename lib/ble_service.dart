import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BleService {
  static final Guid serviceUuid = Guid("0000ffe0-0000-1000-8000-00805f9b34fb");
  static final Guid charUuid = Guid("0000ffe1-0000-1000-8000-00805f9b34fb");

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  BluetoothDevice? connectedDevice;
  Function(String command)? onCommandReceived;

  // A 端扫描连接（保持不变）
  Future<bool> scanAndConnect() async {
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

  // B 端广播（3.x 标准写法）
  Future<void> startBroadcasting() async {
    try {
      _peripheral.onDataReceived.listen((data) {
        if (onCommandReceived != null) {
          onCommandReceived!(String.fromCharCodes(data));
        }
      });

      await _peripheral.start(
        advertiseData: const AdvertiseDataCore(
          localName: "MyDialer_B",
          serviceUuid: "0000ffe0-0000-1000-8000-00805f9b34fb",
        ),
        gattServer: const GattServerSettings(),
      );
      print("B端广播已开启");
    } catch (e) {
      print("B端广播失败: $e");
    }
  }

  Future<void> stopBroadcasting() async {
    await _peripheral.stop();
  }
}