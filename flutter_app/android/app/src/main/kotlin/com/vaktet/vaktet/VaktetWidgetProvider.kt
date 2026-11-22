package com.vaktet.vaktet

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

class VaktetWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TICK = "com.vaktet.vaktet.ACTION_WIDGET_TICK"
        private const val PREFS_NAME = "vaktet_widget_schedule"
        private const val KEY_ROWS = "rows_json"
        private const val TICK_REQ_CODE = 55001

        fun saveScheduleAndRefresh(context: Context, items: List<Map<String, Any>>) {
            val arr = JSONArray()
            for (item in items) {
                arr.put(
                    JSONObject().apply {
                        put("name", item["name"] as String)
                        put("instantMs", (item["instantMs"] as Number).toLong())
                    }
                )
            }
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_ROWS, arr.toString())
                .apply()
            refreshAll(context)
        }

        fun refreshAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, VaktetWidgetProvider::class.java))
            if (ids.isEmpty()) {
                cancelTick(context)
                return
            }
            val (name, remaining, urgent) = computeNext(context)
            for (id in ids) {
                updateSingle(context, mgr, id, name, remaining, urgent)
            }
            scheduleNextMinuteTick(context)
        }

        private fun updateSingle(
            context: Context,
            mgr: AppWidgetManager,
            widgetId: Int,
            prayerName: String,
            remainingText: String,
            urgent: Boolean
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_vaktet_ghost)
            views.setTextViewText(R.id.widget_prayer_name, prayerName)
            views.setTextViewText(R.id.widget_remaining, remainingText)
            views.setTextColor(
                R.id.widget_remaining,
                Color.parseColor(if (urgent) "#FFBE6B" else "#FFF4D2")
            )

            val launch = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(
                context,
                widgetId,
                launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)
            mgr.updateAppWidget(widgetId, views)
        }

        private fun computeNext(context: Context): Triple<String, String, Boolean> {
            val raw = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_ROWS, null) ?: return Triple("Vaktet", "Hap", false)
            val now = System.currentTimeMillis()
            try {
                val arr = JSONArray(raw)
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    val target = obj.getLong("instantMs")
                    if (target > now) {
                        val name = obj.getString("name")
                        val diffMs = target - now
                        // Round up to remaining minutes (no seconds shown)
                        val totalMin = ((diffMs + 59999L) / 60000L).toInt().coerceAtLeast(1)
                        val h = totalMin / 60
                        val m = totalMin % 60
                        val formatted = when {
                            h > 0 && m > 0 -> "${h}h ${m}m"
                            h > 0 -> "${h}h"
                            else -> "${m}m"
                        }
                        val urgent = totalMin <= 20
                        return Triple(name, formatted, urgent)
                    }
                }
            } catch (_: Exception) {
                // Fallback if JSON is unreadable
            }
            return Triple("Vaktet", "Hap", false)
        }

        /**
         * Schedules a non-waking RTC alarm at the next whole minute boundary.
         * Never wakes the CPU while the phone is asleep in your pocket (0% battery drain),
         * and refreshes immediately when the lock screen wakes up.
         */
        private fun scheduleNextMinuteTick(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val now = System.currentTimeMillis()
            val nextMin = ((now / 60000L) + 1L) * 60000L + 200L
            val intent = Intent(context, VaktetWidgetProvider::class.java).apply {
                action = ACTION_TICK
            }
            val pi = PendingIntent.getBroadcast(
                context,
                TICK_REQ_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                am.canScheduleExactAlarms()
            } else {
                true
            }
            if (canExact) {
                am.setExact(AlarmManager.RTC, nextMin, pi)
            } else {
                am.set(AlarmManager.RTC, nextMin, pi)
            }
        }

        private fun cancelTick(context: Context) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, VaktetWidgetProvider::class.java).apply {
                action = ACTION_TICK
            }
            val pi = PendingIntent.getBroadcast(
                context,
                TICK_REQ_CODE,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        refreshAll(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        refreshAll(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelTick(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (action == ACTION_TICK ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_USER_PRESENT
        ) {
            refreshAll(context)
        }
    }
}
