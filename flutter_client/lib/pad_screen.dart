import 'package:flutter/material.dart';
import 'app_state.dart';
import 'controller_button.dart';
import 'analog_stick.dart';
import 'dpad_widget.dart';
import 'action_buttons_widget.dart';

class PadScreen extends StatelessWidget {
  final AppState appState;

  const PadScreen({Key? key, required this.appState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, child) {
            return Stack(
              children: [
                // Background
                Container(color: Colors.black),

                // Main Gamepad Area
                if (appState.isConnected || appState.isEditMode)
                  ..._buildGamepad(context),

                // Connection Overlay
                if (!appState.isConnected && !appState.isEditMode)
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.blueAccent),
                          SizedBox(height: 20),
                          Text(
                            "Waiting for Server Broadcast...",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 20),
                          SizedBox(
                            width: 300,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Or enter server IP manually",
                                hintStyle: TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: Colors.white12,
                                border: OutlineInputBorder(),
                              ),
                              style: TextStyle(color: Colors.white),
                              onSubmitted: (value) {
                                if (value.isNotEmpty) appState.connectToServer(value);
                              },
                              onChanged: (value) => appState.errorMessage = "",
                            ),
                          ),
                          if (appState.errorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: Text(
                                appState.errorMessage,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Top Status Bar
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        appState.isConnected ? "Connected" : "Disconnected",
                        style: TextStyle(
                          color: appState.isConnected
                              ? Colors.white54
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        appState.playerIndex,
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit Mode UI
                Positioned(
                  top: 10,
                  right: 10,
                  child: Opacity(
                    opacity: appState.isEditMode ? 1.0 : 0.3,
                    child: IconButton(
                      icon: Icon(
                        appState.isEditMode ? Icons.save : Icons.edit,
                        size: 16,
                      ),
                      color: appState.isEditMode ? Colors.green : Colors.grey,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 12,
                      onPressed: () => appState.toggleEditMode(),
                      tooltip: appState.isEditMode ? "Save Layout" : "Edit Layout",
                    ),
                  ),
                ),

                if (appState.isEditMode)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (appState.selectedElementId != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Scale: ${(appState.getScale(appState.selectedElementId!) * 100).toInt()}%",
                                  style: TextStyle(color: Colors.white),
                                ),
                                SizedBox(
                                  width: 200,
                                  child: Slider(
                                    value: appState.getScale(appState.selectedElementId!),
                                    min: 0.5,
                                    max: 2.5,
                                    divisions: 20,
                                    onChanged: (val) => appState.saveScale(appState.selectedElementId!, val),
                                    activeColor: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => appState.resetLayout(),
                          child: const Text("Reset Layout to Default"),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildGamepad(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return [
      // Grid D-Pad
      DPadWidget(
        appState: appState,
        defaultLeft: 50,
        defaultTop: h - 220,
      ),

      // Grid Face Buttons
      ActionButtonsWidget(
        appState: appState,
        defaultLeft: w - 220,
        defaultTop: h - 220,
      ),

      // Shoulders
      ControllerButton(
        appState: appState,
        id: "L1",
        label: "L1",
        defaultLeft: 50,
        defaultTop: 40,
        defaultWidth: 100,
        defaultHeight: 45,
        borderRadius: 8,
      ),
      ControllerButton(
        appState: appState,
        id: "L2",
        label: "L2",
        isTrigger: true,
        defaultLeft: 160,
        defaultTop: 40,
        defaultWidth: 100,
        defaultHeight: 45,
        borderRadius: 8,
      ),
      ControllerButton(
        appState: appState,
        id: "R1",
        label: "R1",
        defaultLeft: w - 150,
        defaultTop: 40,
        defaultWidth: 100,
        defaultHeight: 45,
        borderRadius: 8,
      ),
      ControllerButton(
        appState: appState,
        id: "R2",
        label: "R2",
        isTrigger: true,
        defaultLeft: w - 260,
        defaultTop: 40,
        defaultWidth: 100,
        defaultHeight: 45,
        borderRadius: 8,
      ),

      // Start / Select
      ControllerButton(
        appState: appState,
        id: "SELECT",
        label: "Sel",
        defaultLeft: w / 2 - 60,
        defaultTop: h - 80,
      ),
      ControllerButton(
        appState: appState,
        id: "START",
        label: "St",
        defaultLeft: w / 2 + 10,
        defaultTop: h - 80,
      ),

      // Analog Sticks
      AnalogStick(
        appState: appState,
        id: "stick-left",
        stickName: "left",
        defaultLeft: 200,
        defaultTop: h - 150,
      ),
      AnalogStick(
        appState: appState,
        id: "stick-right",
        stickName: "right",
        defaultLeft: w - 320,
        defaultTop: h - 150,
      ),

      // Thumb Clicks
      ControllerButton(
        appState: appState,
        id: "L3",
        label: "L3",
        defaultLeft: 240,
        defaultTop: h - 180,
      ),
      ControllerButton(
        appState: appState,
        id: "R3",
        label: "R3",
        defaultLeft: w - 280,
        defaultTop: h - 180,
      ),
    ];
  }
}
