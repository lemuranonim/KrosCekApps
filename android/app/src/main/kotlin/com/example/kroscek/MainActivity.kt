package com.example.kroscek

import android.app.AlarmManager
import android.app.ActivityOptions
import android.app.DownloadManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.Process
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.FirebaseApp

class MainActivity : FlutterActivity() {
    private val appControlChannel = "com.example.kroscek/app_control"
    private val fullUpdateChannel = "com.example.kroscek/full_update"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        clearRestartFallback()
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            fullUpdateChannel,
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "enqueue" -> enqueueFullUpdate(
                        url = requireNotNull(call.argument<String>("url")),
                        fileName = requireNotNull(call.argument<String>("fileName")),
                        version = requireNotNull(call.argument<String>("version")),
                        result = result,
                    )
                    "query" -> queryFullUpdate(
                        downloadId = requireNotNull(call.argument<Number>("downloadId")).toLong(),
                        result = result,
                    )
                    "remove" -> removeFullUpdate(
                        downloadId = requireNotNull(call.argument<Number>("downloadId")).toLong(),
                        result = result,
                    )
                    "openInstaller" -> openFullUpdateInstaller(
                        fileName = requireNotNull(call.argument<String>("fileName")),
                        result = result,
                    )
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "FULL_UPDATE_ERROR",
                    error.message ?: "Operasi update APK gagal",
                    error.javaClass.simpleName,
                )
            }
        }
    }

    private fun enqueueFullUpdate(
        url: String,
        fileName: String,
        version: String,
        result: MethodChannel.Result,
    ) {
        requireSafeApkFileName(fileName)
        val downloadUri = Uri.parse(url)
        require(downloadUri.scheme.equals("https", ignoreCase = true) && !downloadUri.host.isNullOrBlank()) {
            "URL update harus menggunakan HTTPS"
        }
        val request = DownloadManager.Request(downloadUri).apply {
            setTitle("Pembaruan KC $version")
            setDescription("Mengunduh pembaruan aplikasi")
            setMimeType(APK_MIME_TYPE)
            setAllowedOverMetered(true)
            setAllowedOverRoaming(true)
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            setDestinationInExternalFilesDir(
                this@MainActivity,
                Environment.DIRECTORY_DOWNLOADS,
                fileName,
            )
        }
        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        result.success(downloadManager.enqueue(request))
    }

    private fun queryFullUpdate(downloadId: Long, result: MethodChannel.Result) {
        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) {
                result.success(mapOf("status" to "missing"))
                return
            }

            val status = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
            )
            val reason = cursor.getInt(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
            )
            val downloadedBytes = cursor.getLong(
                cursor.getColumnIndexOrThrow(
                    DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                ),
            )
            val totalBytes = cursor.getLong(
                cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES),
            )
            val statusName = when (status) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "running"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "missing"
            }
            result.success(
                mapOf(
                    "status" to statusName,
                    "reason" to reason,
                    "downloadedBytes" to downloadedBytes,
                    "totalBytes" to totalBytes,
                ),
            )
        }
    }

    private fun removeFullUpdate(downloadId: Long, result: MethodChannel.Result) {
        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        result.success(downloadManager.remove(downloadId))
    }

    private fun openFullUpdateInstaller(fileName: String, result: MethodChannel.Result) {
        requireSafeApkFileName(fileName)
        val downloadsDir = requireNotNull(
            getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
        ) { "Folder unduhan aplikasi tidak tersedia" }
        val apkFile = File(downloadsDir, fileName).canonicalFile
        require(apkFile.parentFile == downloadsDir.canonicalFile) {
            "Lokasi APK tidak valid"
        }
        require(apkFile.isFile && apkFile.length() > 0L) {
            "File APK belum tersedia"
        }
        val archiveInfo = packageManager.getPackageArchiveInfo(apkFile.path, 0)
        require(archiveInfo?.packageName == packageName) {
            "APK update tidak valid untuk aplikasi KC"
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, APK_MIME_TYPE)
            clipData = ClipData.newRawUri("Pembaruan KC", apkUri)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(installIntent)
        result.success(true)
    }

    private fun requireSafeApkFileName(fileName: String) {
        require(fileName == File(fileName).name && fileName.endsWith(".apk", true)) {
            "Nama file APK tidak valid"
        }
    }

    private fun scheduleApplicationRestart(result: MethodChannel.Result) {
        val launchIntent = createRestartLaunchIntent()
        if (launchIntent == null) {
            result.error("NO_LAUNCH_INTENT", "KC tidak dapat dimulai ulang", null)
            return
        }

        val pendingIntent = createRestartPendingIntent(
            launchIntent,
            PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ) ?: run {
            result.error("NO_RESTART_INTENT", "KC tidak dapat dijadwalkan ulang", null)
            return
        }

        runCatching {
            showRestartFallbackNotification(pendingIntent)
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = System.currentTimeMillis() + RESTART_DELAY_MS
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarmManager.canScheduleExactAlarms()) {
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            } catch (_: SecurityException) {
                scheduleInexactRestart(alarmManager, triggerAt, pendingIntent)
            }
        } else {
            scheduleInexactRestart(alarmManager, triggerAt, pendingIntent)
        }

        result.success(true)
        Handler(Looper.getMainLooper()).postDelayed({
            finishAffinity()
            Process.killProcess(Process.myPid())
        }, PROCESS_STOP_DELAY_MS)
    }

    private fun scheduleInexactRestart(
        alarmManager: AlarmManager,
        triggerAt: Long,
        pendingIntent: PendingIntent,
    ) {
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            pendingIntent,
        )
    }

    private fun createRestartLaunchIntent(): Intent? {
        return packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun createRestartPendingIntent(
        launchIntent: Intent,
        flags: Int,
    ): PendingIntent? {
        val options = if (Build.VERSION.SDK_INT >= 35) {
            ActivityOptions.makeBasic().apply {
                pendingIntentCreatorBackgroundActivityStartMode =
                    if (Build.VERSION.SDK_INT >= 36) {
                        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS
                    } else {
                        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                    }
            }.toBundle()
        } else {
            null
        }

        return PendingIntent.getActivity(
            this,
            RESTART_REQUEST_CODE,
            launchIntent,
            flags,
            options,
        )
    }

    private fun showRestartFallbackNotification(contentIntent: PendingIntent) {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    RESTART_NOTIFICATION_CHANNEL_ID,
                    "Pembaruan aplikasi",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Membuka kembali KC setelah patch diterapkan"
                },
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, RESTART_NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_patch_restart)
            .setContentTitle("Patch KC siap diterapkan")
            .setContentText("Jika KC tidak terbuka otomatis, ketuk notifikasi ini.")
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SYSTEM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .apply {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    @Suppress("DEPRECATION")
                    setPriority(Notification.PRIORITY_HIGH)
                }
            }
            .build()

        notificationManager.notify(RESTART_NOTIFICATION_ID, notification)
    }

    private fun clearRestartFallback() {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(RESTART_NOTIFICATION_ID)

        val launchIntent = createRestartLaunchIntent() ?: return
        val pendingIntent = createRestartPendingIntent(
            launchIntent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    companion object {
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val RESTART_NOTIFICATION_CHANNEL_ID = "patch_restart_channel"
        private const val RESTART_NOTIFICATION_ID = 9050
        private const val RESTART_REQUEST_CODE = 9049
        private const val RESTART_DELAY_MS = 1_000L
        private const val PROCESS_STOP_DELAY_MS = 250L
    }
}
