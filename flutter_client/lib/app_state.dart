import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:vibration/vibration.dart';

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  WebSocketChannel? _channel;
  bool isConnected = false;
  bool _isConnecting = false;
  String playerIndex = "[P?]";
  bool isEditMode = false;
  String errorMessage = "";  String? selectedElementId;

  RawDatagramSocket? _udpSocket;

  AppState(this.prefs) {
    _startAutoDiscovery();
  }

  void _startAutoDiscovery() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8001);
      _udpSocket!.listen((RawSocketEvent e) {
        if (e == RawSocketEvent.read) {
          Datagram? dg = _udpSocket!.receive();
          if (dg != null) {
            String msg = String.fromCharCodes(dg.data);
            if (msg == "PS2_CONTROLLER_SERVER" && !isConnected && !_isConnecting) {
              connectToServer(dg.address.address);
            }
          }
        }
      });
    } catch (e) {
      print("Error listening for UDP: $e");
    }
  }

  void connectToServer(String ip) {
    if (isConnected || _isConnecting) return;
    ip = ip.trim();
    if (ip.isEmpty) return;
    
    _isConnecting = true;
    final wsUrl = Uri.parse('ws://$ip:8000/ws');
    try {
      errorMessage = "Connecting to $ip...";
      notifyListeners();
      
      if (_channel != null) {
        _channel!.sink.close();
        _channel = null;
      }
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'assign_index') {
              isConnected = true;
              _isConnecting = false;
              errorMessage = "";
              playerIndex = "[P${data['index']}]";
              notifyListeners();
            } else if (data['type'] == 'rumble') {
              _handleRumble(data['large'], data['small']);
            }
          } catch (e) {
            print("Error parsing msg: $e");
          }
        },
        onDone: () {
          isConnected = false;
          _isConnecting = false;
          playerIndex = "[P?]";
          errorMessage = "Disconnected from server.";
          notifyListeners();
        },
        onError: (err) {
          isConnected = false;
          _isConnecting = false;
          playerIndex = "[P?]";
          errorMessage = "Connection error: $err";
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnecting = false;
      errorMessage = "Could not connect: $e";
      notifyListeners();
    }
  }

  void _handleRumble(int large, int small) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    bool? hasCustom = await Vibration.hasCustomVibrationsSupport();
    int maxIntensity = large > small ? large : small;

    if (maxIntensity > 0) {
      // Scale duration slightly by intensity if we want, or keep it fixed (e.g., 150ms)
      // The host updates frequently during rumble
      if (hasCustom == true) {
        Vibration.vibrate(duration: 150, amplitude: maxIntensity);
      } else {
        Vibration.vibrate(duration: 150);
      }
    } else {
      Vibration.cancel();
    }
  }

  void sendMessage(Map<String, dynamic> msg) {
    if (isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  void toggleEditMode() {
    isEditMode = !isEditMode;
    if (!isEditMode) {
      selectedElementId = null;
    }
    notifyListeners();
  }

  void selectElement(String? id) {
    selectedElementId = id;
    notifyListeners();
  }

  void disconnect() {
    if (_channel != null) {
      _channel!.sink.close();
      _channel = null;
    }
    isConnected = false;
    _isConnecting = false;
    playerIndex = "[P?]";
    errorMessage = "Disconnected.";
    Vibration.cancel();
    notifyListeners();
  }

  // Layout save/load
  double getLeft(String id, double defaultVal) {
    return prefs.getDouble('${id}_left') ?? defaultVal;
  }

  double getTop(String id, double defaultVal) {
    return prefs.getDouble('${id}_top') ?? defaultVal;
  }

  double getScale(String id) {
    return prefs.getDouble('${id}_scale') ?? 1.0;
  }

  void savePosition(String id, double left, double top) {
    prefs.setDouble('${id}_left', left);
    prefs.setDouble('${id}_top', top);
  }

  void saveScale(String id, double scale) {
    prefs.setDouble('${id}_scale', scale);
    notifyListeners();
  }

  void resetLayout() {
    prefs.clear();
    notifyListeners();
  }
}
