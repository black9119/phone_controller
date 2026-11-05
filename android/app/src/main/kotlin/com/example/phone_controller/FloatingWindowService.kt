package com.example.phone_controller

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.Toast
import androidx.core.app.NotificationCompat
import okhttp3.*
import java.util.concurrent.TimeUnit

class FloatingWindowService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: LinearLayout
    private var webSocket: WebSocket? = null
    private var isConnected = false
    private val client = OkHttpClient.Builder().pingInterval(10, TimeUnit.SECONDS).build()

    private var bPhoneIp = "127.0.0.1"
    private val bPhonePort = "8080"
    private var isInitialized = false

    override fun onCreate() {
        super.onCreate()
        // 注意：这里不能写 intent，因为 Service 的 onCreate 没有这个变量
    }

    // 必须在这里接收 Intent！
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val intentIP = intent?.getStringExtra("TARGET_IP")
        if (intentIP != null && intentIP.isNotEmpty()) {
            bPhoneIp = intentIP
        }

        if (!isInitialized) {
            initFloatingWindow()
            isInitialized = true
        }

        return START_STICKY
    }

    private fun initFloatingWindow() {
        startForegroundService()
        connectToB()

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        floatingView = createFloatingView()
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT
        ).apply { gravity = Gravity.TOP or Gravity.START; x = 100; y = 300 }
        
        try {
            windowManager.addView(floatingView, params)
        } catch (e: Exception) {
            e.printStackTrace()
            showToast("悬浮窗创建失败: $e")
        }
    }

    private fun connectToB() {
        val request = Request.Builder().url("ws://$bPhoneIp:$bPhonePort").build()
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                isConnected = true
                showToast("已连接 B 端: $bPhoneIp")
                webSocket.send("""{"action": "register", "role": "A"}""")
            }
            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                isConnected = false
            }
        })
    }

    private fun startForegroundService() {
        val channelId = "command_app_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "指挥端服务", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("指挥端运行中").setContentText("连接 IP: $bPhoneIp").setSmallIcon(android.R.drawable.ic_menu_compass).build()
        startForeground(1, notification)
    }

    private fun createFloatingView(): LinearLayout {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xB3000000.toInt())
            setPadding(20, 20, 20, 20)
        }
        
        val buttons = listOf(
            "APP语音拨号" to """{"action": "switch_ui", "ui": "voip_dialer"}""",
            "真实电话拨号" to """{"action": "switch_ui", "ui": "cellular_dialer"}""",
            "播放忙音" to """{"action": "play_audio", "audio": "busy"}""",
            "播放空号" to """{"action": "play_audio", "audio": "empty"}""",
            "播放正忙" to """{"action": "play_audio", "audio": "user_busy"}""",
            "静音控制" to """{"action": "set_mute", "is_muted": true}""",
            "↩️ 返回拨号盘" to "RETURN_TO_DIALER"
        )

        for ((text, json) in buttons) {
            val btn = Button(this).apply {
                this.text = text
                if (json == "RETURN_TO_DIALER") setTextColor(Color.RED)
                setOnClickListener { 
                    if (json == "RETURN_TO_DIALER") {
                        try {
                            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            prefs.edit().remove("flutter.device_role").apply()
                        } catch (e: Exception) { e.printStackTrace() }
                        val intent = Intent(this@FloatingWindowService, MainActivity::class.java)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                        startActivity(intent)
                        showToast("已返回拨号盘")
                        stopSelf()
                        return@setOnClickListener
                    }
                    
                    if (!isConnected) {
                        showToast("尚未连接B端，请确保 IP ($bPhoneIp) 正确")
                        return@setOnClickListener
                    }
                    webSocket?.send(json)
                    showToast("发送指令: $text")
                }
            }
            layout.addView(btn)
        }
        return layout
    }

    private fun showToast(msg: String) {
        android.os.Handler(mainLooper).post { Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show() }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::floatingView.isInitialized) windowManager.removeView(floatingView)
        webSocket?.close(1000, "Service Destroyed")
    }
    override fun onBind(intent: Intent?): IBinder? = null
}