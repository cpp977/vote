package com.dev.vote

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and exposes the launcher icon switch.
 *
 * Android picks the launcher icon from the currently enabled
 * `<activity-alias>` in AndroidManifest.xml. Exactly one alias is enabled at
 * a time; enabling a different one makes the launcher replace the home screen
 * icon with that alias' icon.
 */
class MainActivity : FlutterActivity() {
    private fun setLauncherIcon(aliasName: String): Boolean {
        val packageManager = packageManager
        val packageName = packageName

        if (aliasName !in LAUNCHER_ICONS) {
            // Unknown alias: leave the current state untouched rather than
            // ending up with no launcher entry point at all.
            return false
        }

        for (alias in LAUNCHER_ICONS) {
            val componentName = ComponentName(packageName, alias)
            val state = if (alias == aliasName) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            packageManager.setComponentEnabledSetting(
                componentName,
                state,
                PackageManager.DONT_KILL_APP,
            )
        }
        return true
    }

    /**
     * Returns the enabled alias, falling back to the manifest default when no
     * alias has been switched explicitly yet.
     */
    private fun getActiveLauncherIcon(): String {
        val packageManager = packageManager
        val packageName = packageName

        for (alias in LAUNCHER_ICONS) {
            val componentName = ComponentName(packageName, alias)
            val isEnabled = when (packageManager.getComponentEnabledSetting(componentName)) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED -> false
                // COMPONENT_ENABLED_STATE_DEFAULT: the manifest decides, and
                // only the default alias is enabled there.
                else -> alias == DEFAULT_LAUNCHER_ICON
            }
            if (isEnabled) {
                return alias
            }
        }

        return DEFAULT_LAUNCHER_ICON
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setLauncherIcon" -> {
                        val aliasName = call.argument<String>("alias")
                        if (aliasName == null) {
                            result.error("INVALID_ARGUMENT", "No alias provided", null)
                        } else if (!setLauncherIcon(aliasName)) {
                            result.error("INVALID_ARGUMENT", "Unknown alias: $aliasName", null)
                        } else {
                            result.success(null)
                        }
                    }
                    "getLauncherIcon" -> result.success(getActiveLauncherIcon())
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CHANNEL = "com.dev.vote/launcher_icons"

        /**
         * The `<activity-alias>` names declared in AndroidManifest.xml.
         *
         * Must stay in sync with `LauncherIconService.icons`, which is the
         * Dart-side source of truth for the icon list.
         */
        val LAUNCHER_ICONS = listOf(
            "com.dev.vote.ic_launcher_deep_purple",
            "com.dev.vote.ic_launcher_blue",
            "com.dev.vote.ic_launcher_teal",
            "com.dev.vote.ic_launcher_green",
            "com.dev.vote.ic_launcher_orange",
            "com.dev.vote.ic_launcher_red",
            "com.dev.vote.ic_launcher_pink",
            "com.dev.vote.ic_launcher_cyan",
            "com.dev.vote.ic_launcher_indigo",
            "com.dev.vote.ic_launcher_amber",
        )

        /** The alias that is enabled in AndroidManifest.xml. */
        const val DEFAULT_LAUNCHER_ICON = "com.dev.vote.ic_launcher_deep_purple"
    }
}
