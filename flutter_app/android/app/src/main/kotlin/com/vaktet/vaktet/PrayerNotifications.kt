package com.vaktet.vaktet

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

object PrayerNotifications {
    const val CHANNEL_ID = "vaktet_prayers"
    private const val CHANNEL_NAME = "Kohët e namazit"
    private const val CHANNEL_DESC = "Njoftime për hyrjen e vakteve të namazit në Kosovë"
    private const val PREFS_NAME = "vaktet_scheduled_alarms"
    private const val KEY_ALARMS = "alarms_json"

    const val EXTRA_ID = "alarm_id"
    const val EXTRA_TITLE = "alarm_title"
    const val EXTRA_BODY = "alarm_body"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttr = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
            description = CHANNEL_DESC
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 180, 120, 180)
            setSound(soundUri, audioAttr)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannel(channel)
    }

    fun scheduleAll(context: Context, items: List<Map<String, Any>>) {
        ensureChannel(context)
        cancelExistingAlarms(context)

        val now = System.currentTimeMillis()
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val saved = JSONArray()

        for (item in items) {
            val id = (item["id"] as Number).toInt()
            val triggerAt = (item["triggerAtMs"] as Number).toLong()
            val title = item["title"] as String
            val body = item["body"] as String
            if (triggerAt <= now) continue

            scheduleSingle(context, am, id, triggerAt, title, body)
            saved.put(
                JSONObject().apply {
                    put("id", id)
                    put("triggerAtMs", triggerAt)
                    put("title", title)
                    put("body", body)
                }
            )
        }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ALARMS, saved.toString())
            .apply()
    }

    fun cancelAll(context: Context) {
        cancelExistingAlarms(context)
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_ALARMS)
            .apply()
    }

    fun reschedulePersisted(context: Context) {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ALARMS, null) ?: return
        ensureChannel(context)
        val now = System.currentTimeMillis()
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val triggerAt = obj.getLong("triggerAtMs")
                if (triggerAt <= now) continue
                scheduleSingle(
                    context,
                    am,
                    obj.getInt("id"),
                    triggerAt,
                    obj.getString("title"),
                    obj.getString("body")
                )
            }
        } catch (_: Exception) {
            // Ignore malformed stored JSON
        }
    }

    private fun cancelExistingAlarms(context: Context) {
        val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_ALARMS, null) ?: return
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        try {
            val arr = JSONArray(raw)
            for (i in 0 until arr.length()) {
                val id = arr.getJSONObject(i).getInt("id")
                val intent = Intent(context, PrayerAlarmReceiver::class.java)
                val pi = PendingIntent.getBroadcast(
                    context,
                    id,
                    intent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                )
                if (pi != null) {
                    am.cancel(pi)
                    pi.cancel()
                }
            }
        } catch (_: Exception) {
            // Ignore malformed stored JSON
        }
    }

    private fun scheduleSingle(
        context: Context,
        am: AlarmManager,
        id: Int,
        triggerAtMs: Long,
        title: String,
        body: String
    ) {
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        val pi = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.canScheduleExactAlarms()
        } else {
            true
        }

        if (canExact) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
        }
    }

    fun showNotification(context: Context, id: Int, title: String, body: String) {
        ensureChannel(context)
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPi = PendingIntent.getActivity(
            context,
            id,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                .setVibrate(longArrayOf(0, 180, 120, 180))
                .setPriority(Notification.PRIORITY_HIGH)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_vaktet)
            .setColor(Color.parseColor("#13625A"))
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentPi)
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(id, notification)
    }
}

class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(PrayerNotifications.EXTRA_ID, 1001)
        val title = intent.getStringExtra(PrayerNotifications.EXTRA_TITLE) ?: "Vaktet"
        val body = intent.getStringExtra(PrayerNotifications.EXTRA_BODY) ?: "Ka hyrë koha e namazit"
        PrayerNotifications.showNotification(context, id, title, body)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            PrayerNotifications.reschedulePersisted(context)
            VaktetWidgetProvider.refreshAll(context)
        }
    }
}
