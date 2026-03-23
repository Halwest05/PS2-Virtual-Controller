import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pad_screen.dart';
import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set fullscreen
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  // Set landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final prefs = await SharedPreferences.getInstance();
  final appState = AppState(prefs);

  runApp(Ps2ControllerApp(appState: appState));
}

class Ps2ControllerApp extends StatefulWidget {
  final AppState appState;

  const Ps2ControllerApp({Key? key, required this.appState}) : super(key: key);

  @override
  State<Ps2ControllerApp> createState() => _Ps2ControllerAppState();
}

class _Ps2ControllerAppState extends State<Ps2ControllerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.appState.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden || 
        state == AppLifecycleState.paused || 
        state == AppLifecycleState.detached) {
      widget.appState.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PS2 Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: PadScreen(appState: widget.appState),
    );
  }
}
