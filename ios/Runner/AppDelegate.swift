import UIKit
import Flutter
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate, CBPeripheralManagerDelegate {
  var peripheralManager: CBPeripheralManager?
  var characteristic: CBMutableCharacteristic?
  var flutterChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller = window?.rootViewController as! FlutterViewController
    flutterChannel = FlutterMethodChannel(name: "com.example.my_dialer/command_channel", binaryMessenger: controller.binaryMessenger)
    
    flutterChannel?.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "startIosBleBroadcast" {
            self?.startAdvertising()
            result("Started")
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func startAdvertising() {
    peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    if peripheral.state == .poweredOn {
      // 设置特征值，允许 A 端写入
      characteristic = CBMutableCharacteristic(
        type: CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB"),
        properties: [.write, .read, .notify],
        value: nil,
        permissions: [.writeable, .readable]
      )

      let service = CBMutableService(type: CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB"), primary: true)
      service.characteristics = [characteristic!]
      peripheralManager?.add(service)

      // 开始广播，名字叫 MyDialer_B
      peripheralManager?.startAdvertising([
        CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")],
        CBAdvertisementDataLocalNameKey: "MyDialer_B"
      ])
      print("iOS BLE 广播已启动")
    }
  }

  // 监听 A 端发来的数据
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    for request in requests {
      if let data = request.value {
        let command = String(data: data, encoding: .utf8)
        if command == "real" {
          // 给 Flutter 发送指令，触发变脸
          flutterChannel?.invokeMethod("onBleCommand", arguments: "real")
        }
      }
      peripheralManager.respond(to: request, withResult: .success)
    }
  }
}