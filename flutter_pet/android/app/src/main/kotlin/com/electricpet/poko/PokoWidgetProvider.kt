package com.electricpet.poko

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

/**
 * 波可桌面小组件。
 *
 * 职责边界（刻意收窄）：
 *   - **只读**状态。小组件不写盘 —— 状态存档由 App 与悬浮宠服务共同维护，
 *     小组件要是也去写，就会和 Flutter 侧互相覆盖。
 *   - 状态读取复用 [FloatingPetService.readStateSnapshot]，
 *     所以小组件上显示的饿/脏/困和桌面猫身上的完全一致。
 *   - 两个入口：点主体打开小窝（App），点按钮把悬浮猫唤回桌面。
 */
class PokoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context))
        }
    }

    companion object {

        /**
         * 主动刷新桌面上的所有小组件。
         *
         * 悬浮宠服务在状态变化（App 写盘、投喂、离线衰减补算）后调用它，
         * 这样小组件不用等 30 分钟的系统周期就能显示最新状态。
         */
        fun refreshAll(context: Context) {
            try {
                val manager = AppWidgetManager.getInstance(context)
                val component = ComponentName(context, PokoWidgetProvider::class.java)
                val ids = manager.getAppWidgetIds(component)
                if (ids.isEmpty()) return
                val views = buildViews(context)
                for (id in ids) {
                    manager.updateAppWidget(id, views)
                }
            } catch (_: Exception) {
                // 小组件刷新失败不该影响悬浮宠本体
            }
        }

        /** 组装小组件的视图 */
        fun buildViews(context: Context): RemoteViews {
            val state = FloatingPetService.readStateSnapshot(context)
            val views = RemoteViews(context.packageName, R.layout.poko_widget)

            views.setTextViewText(R.id.widget_emoji, state.emoji)
            views.setTextViewText(R.id.widget_name, state.petName)
            views.setTextViewText(R.id.widget_status, state.statusLine)

            // 点主体 -> 打开小窝（App）
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))

            // 点按钮 -> 把悬浮猫唤回桌面
            views.setOnClickPendingIntent(R.id.widget_recall, recallPetIntent(context))

            return views
        }

        /** 打开 App 的 PendingIntent */
        private fun openAppIntent(context: Context): PendingIntent {
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
            return PendingIntent.getActivity(context, 301, launchIntent, flags)
        }

        /**
         * 唤出桌面悬浮猫的 PendingIntent。
         *
         * ⚠️ 必须用 `getForegroundService`（API 26+）：从后台启动服务时
         * `getService` 会抛 IllegalStateException（后台启动限制），
         * 而悬浮宠是前台服务，必须走前台服务的启动通道。
         */
        private fun recallPetIntent(context: Context): PendingIntent {
            val serviceIntent = Intent(context, FloatingPetService::class.java)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(context, 302, serviceIntent, flags)
            } else {
                PendingIntent.getService(context, 302, serviceIntent, flags)
            }
        }
    }
}
