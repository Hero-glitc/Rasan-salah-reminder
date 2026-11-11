import glob
import re

# ---- AndroidManifest: permissions, receivers, app name ----
m = 'android/app/src/main/AndroidManifest.xml'
s = open(m, encoding='utf-8').read()
perms = ''.join(
    f'<uses-permission android:name="android.permission.{p}"/>'
    for p in ['POST_NOTIFICATIONS', 'SCHEDULE_EXACT_ALARM', 'USE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED',
              'VIBRATE', 'WAKE_LOCK'])
recv = '''
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON" />
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
'''
if 'ScheduledNotificationReceiver' not in s:
    s = s.replace('<application', perms + '<application', 1)
    s = s.replace('</application>', recv + '</application>', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Salah Reminder"', s, count=1)
open(m, 'w', encoding='utf-8').write(s)

# ---- app/build.gradle: core library desugaring (required by flutter_local_notifications) ----
g = 'android/app/build.gradle'
t = open(g, encoding='utf-8').read()
if 'coreLibraryDesugaringEnabled' not in t:
    t = t.replace('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true', 1)
    t += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n"
open(g, 'w', encoding='utf-8').write(t)

# ---- MainActivity.kt: native notification-sound picker (phone ringtone chooser) ----
KT = r'''package __PKG__

import android.app.Activity
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "salah/ringtone").setMethodCallHandler { call, result ->
            if (call.method == "pick") {
                if (pending != null) {
                    result.error("busy", "Picker already open", null)
                    return@setMethodCallHandler
                }
                pending = result
                val i = Intent(RingtoneManager.ACTION_RINGTONE_PICKER)
                i.putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                i.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                i.putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                val cur = call.argument<String>("current")
                if (cur != null && cur.isNotEmpty()) {
                    i.putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(cur))
                }
                startActivityForResult(i, 4711)
            } else if (call.method == "title") {
                val u = call.argument<String>("uri")
                var title = ""
                try {
                    if (u != null && u.isNotEmpty()) {
                        title = RingtoneManager.getRingtone(this, Uri.parse(u)).getTitle(this)
                    }
                } catch (e: Exception) {
                }
                result.success(title)
            } else {
                result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun pickedUri(data: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= 33) {
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI, Uri::class.java)
        } else {
            data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 4711) {
            val r = pending
            pending = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val uri = pickedUri(data)
                r?.success(uri?.toString() ?: "")
            } else {
                r?.success(null)
            }
        }
    }
}
'''
files = glob.glob('android/app/src/main/kotlin/**/MainActivity.kt', recursive=True)
if files:
    path = files[0]
    src = open(path, encoding='utf-8').read()
    pkg = re.search(r'^package\s+([\w.]+)', src, re.M).group(1)
    open(path, 'w', encoding='utf-8').write(KT.replace('__PKG__', pkg))
    print('MainActivity patched:', path)
else:
    print('WARNING: MainActivity.kt not found; sound picker will not work')
print('android patched')
