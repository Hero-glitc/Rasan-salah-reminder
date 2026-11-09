import re

# ---- AndroidManifest: permissions, receivers, app name ----
m = 'android/app/src/main/AndroidManifest.xml'
s = open(m, encoding='utf-8').read()
perms = ''.join(
    f'<uses-permission android:name="android.permission.{p}"/>'
    for p in ['POST_NOTIFICATIONS', 'SCHEDULE_EXACT_ALARM', 'USE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED',
              'VIBRATE', 'WAKE_LOCK', 'ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION'])
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
print('android patched')
