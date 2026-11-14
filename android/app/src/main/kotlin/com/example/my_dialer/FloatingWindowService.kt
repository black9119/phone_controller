package com.example.my_dialer

import android.app.*
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
import io.flutter.plugin.common.MethodChannel

class FloatingWindowService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: LinearLayout
    private val CHANNEL = "com.example.my_dialer/command_channel"

    override fun onCreate() {
        super.onCreate()
        startForegroundServiceCompat()
        initFloatingWindow()
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
            Toast.makeText(this, "悬浮窗添加失败，请检查权限", Toast.LENGTH_LONG).show()
        }
    }

    private fun createFloatingView(): LinearLayout {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xB3000000.toInt())
            setPadding(20, 20, 20, 20)
        }
        
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
                    
                    try {
                        val engine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get("main_engine")
                        if (engine != null) {
                            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("onSendBleCommand", cmd)
                            showToast("已交由系统发送: $text")
                        } else {
                            showToast("Flutter引擎未就绪")
                        }
                    } catch (e: Exception) {
                        showToast("通信失败: ${e.message}")
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
    }
    override fun onBind(intent: Intent?): IBinder? = null
}