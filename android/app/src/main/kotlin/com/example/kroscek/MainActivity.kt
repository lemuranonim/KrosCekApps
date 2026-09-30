package com.example.kroscek

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.FirebaseApp

class MainActivity : FlutterActivity() {
    private val appControlChannel = "com.example.kroscek/app_control"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            FirebaseApp.initializeApp(this)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            appControlChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "restartApp" -> scheduleApplicationRestart(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleApplicationRestart(result: MethodChannel.Result) {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent == null) {
            result.error("NO_LAUNCH_INTENT", "KC tidak dapat dimulai ulang", null)
            return
        }

        launchIntent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
        )

        val pendingIntent = PendingIntent.getActivity(
            this,
            9049,
            launchIntent,
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.set(
            AlarmManager.RTC,
            System.currentTimeMillis() + 700L,
            pendingIntent,
        )

        result.success(true)
        Handler(Looper.getMainLooper()).postDelayed({
            finishAffinity()
            Process.killProcess(Process.myPid())
        }, 220L)
    }
}
