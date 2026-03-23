import 'package:flutter/material.dart';
import 'app_state.dart';

class ActionButtonsWidget extends StatefulWidget {
  final AppState appState;
  final double defaultLeft;
  final double defaultTop;

  const ActionButtonsWidget({
    Key? key,
    required this.appState,
    required this.defaultLeft,
    required this.defaultTop,
  }) : super(key: key);

  @override
  State<ActionButtonsWidget> createState() => _ActionButtonsWidgetState();
}

class _ActionButtonsWidgetState extends State<ActionButtonsWidget> {
  final Map<int, Set<String>> _pointerActivations = {};
  final Set<String> _activeButtons = {};

  void _updateActive() {
    Set<String> newActive = {};
    for (var act in _pointerActivations.values) {
      newActive.addAll(act);
    }

    for (String btn in _activeButtons) {
      if (!newActive.contains(btn)) {
        widget.appState.sendMessage({"type": "button", "button": btn, "pressed": false});
      }
    }
    for (String btn in newActive) {
      if (!_activeButtons.contains(btn)) {
        widget.appState.sendMessage({"type": "button", "button": btn, "pressed": true});
      }
    }
    setState(() {
      _activeButtons.clear();
      _activeButtons.addAll(newActive);
    });
  }

  Set<String> _getButtonsForPos(Offset localPos, double scale) {
    double totalSize = 170 * scale; 
    double segment = totalSize / 3;

    double x = localPos.dx;
    double y = localPos.dy;
    
    Set<String> pressed = {};

    if (x < 0 || y < 0 || x > totalSize || y > totalSize) {
      return pressed;
    }

    int col = (x / segment).floor();
    int row = (y / segment).floor();

    if (row == 0 && col == 1) pressed.add("TRIANGLE");
    if (row == 2 && col == 1) pressed.add("CROSS");
    if (row == 1 && col == 0) pressed.add("SQUARE");
    if (row == 1 && col == 2) pressed.add("CIRCLE");
    
    if (row == 0 && col == 0) { pressed.add("TRIANGLE"); pressed.add("SQUARE"); }
    if (row == 0 && col == 2) { pressed.add("TRIANGLE"); pressed.add("CIRCLE"); }
    if (row == 2 && col == 0) { pressed.add("CROSS"); pressed.add("SQUARE"); }
    if (row == 2 && col == 2) { pressed.add("CROSS"); pressed.add("CIRCLE"); }

    return pressed;
  }

  Widget _buildActionButton(String label, String name, double scale, {Color? color}) {
    bool isActive = _activeButtons.contains(name);
    return Container(
      width: 60 * scale,
      height: 60 * scale,
      decoration: BoxDecoration(
        color: isActive ? Colors.grey.shade400 : Colors.grey.shade800,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2 * scale),
        boxShadow: [
          if (!isActive)
            BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 4 * scale),
              blurRadius: 4 * scale,
            ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 26 * scale,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, child) {
        String id = "action_group";
        double currentLeft = widget.appState.getLeft(id, widget.defaultLeft);
        double currentTop = widget.appState.getTop(id, widget.defaultTop);
        double currentScale = widget.appState.getScale(id);

        double totalSize = 170 * currentScale; 
        double half = totalSize / 2;
        double btnSize = 60 * currentScale;

        Widget content = SizedBox(
          width: totalSize,
          height: totalSize,
          child: Stack(
            children: [
              Positioned(left: half - btnSize / 2, top: 0, child: _buildActionButton("△", "TRIANGLE", currentScale, color: Colors.greenAccent)),
              Positioned(left: half - btnSize / 2, top: totalSize - btnSize, child: _buildActionButton("X", "CROSS", currentScale, color: Colors.blueAccent)),
              Positioned(left: 0, top: half - btnSize / 2, child: _buildActionButton("□", "SQUARE", currentScale, color: Colors.purpleAccent)),
              Positioned(left: totalSize - btnSize, top: half - btnSize / 2, child: _buildActionButton("O", "CIRCLE", currentScale, color: Colors.redAccent)),
            ],
          ),
        );

        if (widget.appState.isEditMode) {
          return Positioned(
            left: currentLeft,
            top: currentTop,
            child: GestureDetector(
              onPanStart: (_) => widget.appState.selectElement(id),
              onPanUpdate: (details) {
                setState(() {
                  widget.appState.savePosition(
                      id,
                      currentLeft + details.delta.dx,
                      currentTop + details.delta.dy);
                });
              },
              child: Opacity(opacity: 0.7, child: content),
            ),
          );
        }

        return Positioned(
          left: currentLeft,
          top: currentTop,
          child: Listener(
            onPointerDown: (e) {
              _pointerActivations[e.pointer] = _getButtonsForPos(e.localPosition, currentScale);
              _updateActive();
            },
            onPointerUp: (e) {
              _pointerActivations.remove(e.pointer);
              _updateActive();
            },
            onPointerCancel: (e) {
              _pointerActivations.remove(e.pointer);
              _updateActive();
            },
            child: content,
          ),
        );
      },
    );
  }
}
