package com.example.my_dialer

import android.app.*
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.app.NotificationCompat
import java.io.OutputStream
import java.util.UUID

class FloatingWindowService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: LinearLayout
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null
    private var isConnected = false
    
    private val MY_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun onCreate() {
        super.onCreate()
        startForegroundServiceCompat()
        connectToB()
        initFloatingWindow()
    }

    private fun connectToB() {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null || !adapter.isEnabled) {
            showToast("请开启手机蓝牙")
            return
        }

        Thread {
            try {
                var targetDevice: BluetoothDevice? = null
                for (device in adapter.bondedDevices) {
                    if (device.name.contains("B") || device.name.contains("Phone")) {
                        targetDevice = device
                        break
                    }
                }

                if (targetDevice != null) {
                    bluetoothSocket = targetDevice.createRfcommSocketToServiceRecord(MY_UUID)
                    adapter.cancelDiscovery()
                    bluetoothSocket?.connect()
                    outputStream = bluetoothSocket?.outputStream
                    isConnected = true
                    showToast("蓝牙已连接: ${targetDevice.name}")
                } else {
                    showToast("找不到配对设备，请先在系统蓝牙中配对")
                }
            } catch (e: Exception) {
                showToast("蓝牙连接失败: ${e.message}")
            }
        }.start()
    }

    private fun initFloatingWindow() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        floatingView = createFloatingView()
        
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 100; y = 300 }
        
        try {
            windowManager.addView(floatingView, params)
        } catch (e: Exception) {
            showToast("悬浮窗添加失败")
        }
    }

    private fun createFloatingView(): LinearLayout {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xB3000000.toInt())
            setPadding(20, 20, 20, 20)
        }
        
        // 这里就是你想要的 7 个按钮！
        val buttons = listOf(
            "APP语音拨号" to "voip",
            "真实电话拨号" to "real",
            "播放忙音" to "busy",
            "播放空号" to "empty",
            "播放正忙" to "user_busy",
            "静音控制" to "mute",
            "↩️ 返回拨号盘" to "RETURN"
        )

        for ((text, cmd) in buttons) {
            val btn = Button(this).apply {
                this.text = text
                if (cmd == "RETURN") setTextColor(android.graphics.Color.RED)
                setOnClickListener { 
                    if (cmd == "RETURN") {
                        val intent = Intent(this@FloatingWindowService, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        }
                        startActivity(intent)
                        stopSelf()
                        return@setOnClickListener
                    }
                    
                    if (!isConnected) {
                        showToast("蓝牙未连接")
                        return@setOnClickListener
                    }
                    
                    try {
                        outputStream?.write("$cmd\n".toByteArray())
                        showToast("已发送指令: $text")
                    } catch (e: Exception) {
                        showToast("发送失败: ${e.message}")
                        isConnected = false
                    }
                }
            }
            layout.addView(btn)
        }
        return layout
    }

    private fun startForegroundServiceCompat() {
        val channelId = "dialer_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "悬浮窗服务", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("指挥端运行中").setContentText("悬浮窗已启动")
            .setSmallIcon(android.R.drawable.ic_menu_compass).build()
        
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(1, notification)
        }
    }

    private fun showToast(msg: String) {
        android.os.Handler(mainLooper).post { Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show() }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::floatingView.isInitialized) windowManager.removeView(floatingView)
        bluetoothSocket?.close()
    }
    override fun onBind(intent: Intent?): IBinder? = null
}