import 'package:flutter/material.dart';
import 'app_state.dart';

class DPadWidget extends StatefulWidget {
  final AppState appState;
  final double defaultLeft;
  final double defaultTop;

  const DPadWidget({
    Key? key,
    required this.appState,
    required this.defaultLeft,
    required this.defaultTop,
  }) : super(key: key);

  @override
  State<DPadWidget> createState() => _DPadWidgetState();
}

class _DPadWidgetState extends State<DPadWidget> {
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
    double tileSize = 50 * scale;
    double x = localPos.dx;
    double y = localPos.dy;
    
    Set<String> pressed = {};

    if (x < 0 || y < 0 || x > tileSize * 3 || y > tileSize * 3) {
      return pressed;
    }

    int col = (x / tileSize).floor();
    int row = (y / tileSize).floor();

    if (row == 0 && col == 1) pressed.add("UP");
    if (row == 2 && col == 1) pressed.add("DOWN");
    if (row == 1 && col == 0) pressed.add("LEFT");
    if (row == 1 && col == 2) pressed.add("RIGHT");
    
    if (row == 0 && col == 0) { pressed.add("UP"); pressed.add("LEFT"); }
    if (row == 0 && col == 2) { pressed.add("UP"); pressed.add("RIGHT"); }
    if (row == 2 && col == 0) { pressed.add("DOWN"); pressed.add("LEFT"); }
    if (row == 2 && col == 2) { pressed.add("DOWN"); pressed.add("RIGHT"); }

    return pressed;
  }

  Widget _buildDpadSegment(IconData icon, String name, double scale, BoxConstraints constraints) {
    bool isActive = _activeButtons.contains(name);
    return Container(
      width: 50 * scale,
      height: 50 * scale,
      decoration: BoxDecoration(
        color: isActive ? Colors.grey.shade400 : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(5 * scale),
        border: Border.all(color: Colors.white24, width: 2 * scale),
        boxShadow: [
          if (!isActive)
            BoxShadow(
              color: Colors.black54,
              offset: Offset(0, 2 * scale),
              blurRadius: 2 * scale,
            ),
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 28 * scale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, child) {
        String id = "dpad_group";
        double currentLeft = widget.appState.getLeft(id, widget.defaultLeft);
        double currentTop = widget.appState.getTop(id, widget.defaultTop);
        double currentScale = widget.appState.getScale(id);

        double totalSize = 150 * currentScale;
        BoxConstraints sizeConstraints = BoxConstraints(maxWidth: totalSize, maxHeight: totalSize);

        Widget content = SizedBox(
          width: totalSize,
          height: totalSize,
          child: Stack(
            children: [
              Positioned(left: 50 * currentScale, top: 0, child: _buildDpadSegment(Icons.keyboard_arrow_up, "UP", currentScale, sizeConstraints)),
              Positioned(left: 50 * currentScale, top: 100 * currentScale, child: _buildDpadSegment(Icons.keyboard_arrow_down, "DOWN", currentScale, sizeConstraints)),
              Positioned(left: 0, top: 50 * currentScale, child: _buildDpadSegment(Icons.keyboard_arrow_left, "LEFT", currentScale, sizeConstraints)),
              Positioned(left: 100 * currentScale, top: 50 * currentScale, child: _buildDpadSegment(Icons.keyboard_arrow_right, "RIGHT", currentScale, sizeConstraints)),
              Positioned(
                left: 50 * currentScale, 
                top: 50 * currentScale, 
                child: Container(
                  width: 50 * currentScale, 
                  height: 50 * currentScale, 
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(5 * currentScale),
                    border: Border.all(color: Colors.white24, width: 2 * currentScale),
                  )
                )
              )
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
