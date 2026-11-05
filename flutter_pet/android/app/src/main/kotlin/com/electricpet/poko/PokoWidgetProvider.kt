package com.electricpet.poko

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

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
         * 小组件刷新专用线程。
         *
         * ⚠️ 刷新必须在**主线程之外**做。
         *
         * refreshAll 是被悬浮宠的 syncPetMood() 调的，而 syncPetMood 又会在
         * 「Dart 每次写盘」时被触发（原生侧注册了 SharedPreferences 变更监听）。
         * 也就是说：**用户每摸一次猫，主线程就要做**——
         *   1 次 SharedPreferences 读 + 1 次 JSON 解析（syncPetMood 自己那次）
         *   + 1 次 SharedPreferences 读 + 1 次 JSON 解析（buildViews 里那次）
         *   + N 次 updateAppWidget 的 binder 调用（每个约 1-3ms，且要过 system_server）
         * 这些全在主线程上串行做，触摸反馈会被拖住。
         */
        private val refreshExecutor = Executors.newSingleThreadExecutor { r ->
            Thread(r, "poko-widget-refresh").apply { isDaemon = true }
        }

        /**
         * 刷新代次：只允许「最新一次」刷新真正落地。
         *
         * ⚠️ 刷新改成异步之后会冒出新的竞态：连续两次刷新可能乱序完成，
         * 老快照后到，把新状态盖成旧状态 —— 小组件上会看到「状态往回退」。
         * 用一个单调递增的代次号把过期的刷新挡掉。
         */
        private val refreshGeneration = AtomicInteger(0)

        /**
         * 主动刷新桌面上的所有小组件。
         *
         * 悬浮宠服务在状态变化（App 写盘、投喂、离线衰减补算）后调用它，
         * 这样小组件不用等 30 分钟的系统周期就能显示最新状态。
         */
        fun refreshAll(context: Context) {
            // ⚠️ 用 applicationContext：任务跑在后台线程上，会比调用方活得久，
            //    拿着 Service 的 context 会把整个服务泄漏出去。
            val appContext = context.applicationContext
            val generation = refreshGeneration.incrementAndGet()
            refreshExecutor.execute {
                try {
                    val manager = AppWidgetManager.getInstance(appContext)
                    val component = ComponentName(appContext, PokoWidgetProvider::class.java)
                    val ids = manager.getAppWidgetIds(component)
                    if (ids.isEmpty()) return@execute
                    val views = buildViews(appContext)
                    // 组装视图的过程中可能又来了一次更新的刷新 —— 这次已经过期，作废
                    if (refreshGeneration.get() != generation) return@execute
                    for (id in ids) {
                        manager.updateAppWidget(id, views)
                    }
                } catch (_: Exception) {
                    // 小组件刷新失败不该影响悬浮宠本体
                }
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
