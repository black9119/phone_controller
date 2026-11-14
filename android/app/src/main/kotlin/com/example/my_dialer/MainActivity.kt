package com.example.my_dialer

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.my_dialer/command_channel"
    private val MY_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private var serverSocket: BluetoothServerSocket? = null
    private var flutterChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        flutterChannel?.setMethodCallHandler { call, result ->
            if (call.method == "startFloatingWindow") {
                if (!Settings.canDrawOverlays(this)) {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                    startActivity(intent)
                    result.error("NO_PERMISSION", "Need overlay permission", null)
                } else {
                    val serviceIntent = Intent(this, FloatingWindowService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(serviceIntent) else startService(serviceIntent)
                    result.success("Started")
                }
            } else if (call.method == "startBleServer") {
                startBluetoothServer()
                result.success("Listening")
            } else {
                result.notImplemented()
            }
        }
    }

    private fun startBluetoothServer() {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return
        Thread {
            try {
                serverSocket = adapter.listenUsingRfcommWithServiceRecord("MyDialer_B", MY_UUID)
                while (true) {
                    val socket = serverSocket?.accept() ?: break
                    listenToSocket(socket)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun listenToSocket(socket: BluetoothSocket) {
        Thread {
            try {
                val reader = BufferedReader(InputStreamReader(socket.inputStream))
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    val command = line?.trim()
                    if (!command.isNullOrEmpty()) {
                        runOnUiThread {
                            flutterChannel?.invokeMethod("onBleCommand", command)
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()
    }
}