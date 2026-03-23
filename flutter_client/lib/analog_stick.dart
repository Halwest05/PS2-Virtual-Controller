import 'package:flutter/material.dart';
import 'app_state.dart';
import 'dart:math';

class AnalogStick extends StatefulWidget {
  final String id;
  final String stickName;
  final double defaultLeft;
  final double defaultTop;
  final AppState appState;

  const AnalogStick({
    Key? key,
    required this.id,
    required this.stickName,
    required this.defaultLeft,
    required this.defaultTop,
    required this.appState,
  }) : super(key: key);

  @override
  State<AnalogStick> createState() => _AnalogStickState();
}

class _AnalogStickState extends State<AnalogStick> {
  Offset thumbPos = Offset.zero;

  void _sendState(double dx, double dy, double maxRadius) {
    // x, y in range -1.0 to 1.0 (y is inverted for standard gamepad)
    double nx = dx / maxRadius;
    double ny = -(dy / maxRadius);
    widget.appState.sendMessage({
      "type": "stick",
      "stick": widget.stickName,
      "x": nx,
      "y": ny
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, child) {
        double currentLeft = widget.appState.getLeft(widget.id, widget.defaultLeft);
        double currentTop = widget.appState.getTop(widget.id, widget.defaultTop);
        double currentScale = widget.appState.getScale(widget.id);

        double baseRadius = 60 * currentScale;
        double thumbRadius = 25 * currentScale;
        double maxTravel = baseRadius - thumbRadius;

        Widget stickContent = SizedBox(
          width: baseRadius * 2,
          height: baseRadius * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2 * currentScale),
                ),
              ),
              Transform.translate(
                offset: thumbPos,
                child: Container(
                  width: thumbRadius * 2,
                  height: thumbRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black54,
                        offset: Offset(0, 4 * currentScale),
                        blurRadius: 4 * currentScale,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (widget.appState.isEditMode) {
          return Positioned(
            left: currentLeft,
            top: currentTop,
            child: GestureDetector(
              onPanStart: (_) => widget.appState.selectElement(widget.id),
              onPanUpdate: (details) {
                setState(() {
                  widget.appState.savePosition(
                      widget.id,
                      currentLeft + details.delta.dx,
                      currentTop + details.delta.dy);
                });
              },
              child: Opacity(
                opacity: 0.7,
                child: stickContent,
              ),
            ),
          );
        }

        return Positioned(
          left: currentLeft,
          top: currentTop,
          child: GestureDetector(
            onPanStart: (details) {
              _updateThumbPos(details.localPosition, baseRadius, maxTravel);
            },
            onPanUpdate: (details) {
              _updateThumbPos(details.localPosition, baseRadius, maxTravel);
            },
            onPanEnd: (details) {
              setState(() {
                thumbPos = Offset.zero;
              });
              _sendState(0, 0, maxTravel);
            },
            onPanCancel: () {
              setState(() {
                thumbPos = Offset.zero;
              });
              _sendState(0, 0, maxTravel);
            },
            child: stickContent,
          ),
        );
      },
    );
  }

  void _updateThumbPos(Offset localPosition, double baseRadius, double maxTravel) {
    double dx = localPosition.dx - baseRadius;
    double dy = localPosition.dy - baseRadius;
    final dist = sqrt(dx * dx + dy * dy);
    
    if (dist > maxTravel) {
      dx = (dx / dist) * maxTravel;
      dy = (dy / dist) * maxTravel;
    }
    
    setState(() {
      thumbPos = Offset(dx, dy);
    });
    
    _sendState(dx, dy, maxTravel);
  }
}
