import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/notif.dart';
import 'core/state.dart';
import 'ui/history.dart';
import 'ui/home.dart';
import 'ui/settings.dart';
import 'ui/stats.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notif.init();
  await AppState.i.init();
  runApp(const SalahApp());
}

ThemeData _theme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F7A4D), brightness: b),
    );

class SalahApp extends StatelessWidget {
  const SalahApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (_, __) => MaterialApp(
        title: 'Salah Reminder',
        debugShowCheckedModeBanner: false,
        themeMode: AppState.i.themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: Locale(AppState.i.cfg.lang),
        supportedLocales: const [Locale('en'), Locale('ar'), Locale('fa'), Locale('ps')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int idx = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Notif.requestPerms();
      await AppState.i.load();
      await Notif.rescheduleAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await AppState.i.load();
      await Notif.rescheduleAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (_, __) => Scaffold(
        appBar: AppBar(title: Text(t('app'))),
        body: IndexedStack(index: idx, children: const [HomePage(), HistoryPage(), StatsPage(), SettingsPage()]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: idx,
          onDestinationSelected: (i) => setState(() => idx = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: t('home')),
            NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: t('history')),
            NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: t('stats')),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: t('settings')),
          ],
        ),
      ),
    );
  }
}
