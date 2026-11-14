import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate, CBPeripheralManagerDelegate {
  private var peripheralManager: CBPeripheralManager?
  private var serviceUUID = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
  private var characteristicUUID = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 初始化 BLE 外设
    peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 蓝牙状态改变回调
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    if peripheral.state == .poweredOn {
      // 开启广播
      let service = CBMutableService(type: serviceUUID, primary: true)
      let characteristic = CBMutableCharacteristic(
        type: characteristicUUID,
        properties: [.write],
        value: nil,
        permissions: [.writeable]
      )
      service.characteristics = [characteristic]
      peripheral.add(service)
      
      peripheral.startAdvertising([
        CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
        CBAdvertisementDataLocalNameKey: "MyDialer_B"
      ])
    }
  }

  // 收到 A 端写入的数据
  func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    for request in requests {
      // 关键修复：加上 `?` 进行可选链解包，防止 nil 崩溃
      peripheral.respond(to: request, withResult: .success)
      
      if let data = request.value, let command = String(data: data, encoding: .utf8) {
        print("iOS 收到指令: \(command)")
        // 这里可以发送通知给 Flutter 层触发变脸
        if let controller = window?.rootViewController as? FlutterViewController {
          let channel = FlutterMethodChannel(name: "com.example.my_dialer/command_channel", binaryMessenger: controller.binaryMessenger)
          channel.invokeMethod("onBleCommand", arguments: command)
        }
      }
    }
  }
}