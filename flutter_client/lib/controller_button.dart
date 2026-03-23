import 'package:flutter/material.dart';
import 'app_state.dart';

class ControllerButton extends StatefulWidget {
  final String id;
  final String label;
  final IconData? icon;
  final bool isTrigger;
  final double defaultLeft;
  final double defaultTop;
  final double defaultWidth;
  final double defaultHeight;
  final double borderRadius;
  final AppState appState;

  const ControllerButton({
    Key? key,
    required this.id,
    this.label = '',
    this.icon,
    this.isTrigger = false,
    required this.defaultLeft,
    required this.defaultTop,
    this.defaultWidth = 50.0,
    this.defaultHeight = 50.0,
    this.borderRadius = 25.0,
    required this.appState,
  }) : super(key: key);

  @override
  State<ControllerButton> createState() => _ControllerButtonState();
}

class _ControllerButtonState extends State<ControllerButton> {
  bool isPressed = false;

  void _sendState(bool pressed) {
    if (widget.isTrigger) {
      widget.appState.sendMessage({
        "type": "trigger",
        "trigger": widget.id,
        "value": pressed ? 1.0 : 0.0
      });
    } else {
      widget.appState.sendMessage({
        "type": "button",
        "button": widget.id,
        "pressed": pressed
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, child) {
        double currentLeft = widget.appState.getLeft(widget.id, widget.defaultLeft);
        double currentTop = widget.appState.getTop(widget.id, widget.defaultTop);
        double currentScale = widget.appState.getScale(widget.id);

        Widget buttonContent = Container(
          width: widget.defaultWidth * currentScale,
          height: widget.defaultHeight * currentScale,
          decoration: BoxDecoration(
            color: isPressed ? Colors.grey.shade400 : Colors.grey.shade800,
            borderRadius: BorderRadius.circular(widget.borderRadius * currentScale),
            border: Border.all(color: Colors.white24, width: 2 * currentScale),
            boxShadow: [
              if (!isPressed)
                BoxShadow(
                  color: Colors.black54,
                  offset: Offset(0, 4 * currentScale),
                  blurRadius: 4 * currentScale,
                ),
            ],
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: Colors.white, size: 24 * currentScale)
                : Text(
                    widget.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16 * currentScale,
                    ),
                  ),
          ),
        );

        if (widget.appState.isEditMode) {
          return Positioned(
            left: currentLeft,
            top: currentTop,
            child: GestureDetector(
              onPanStart: (_) => widget.appState.selectElement(widget.id),
              onPanUpdate: (details) {
                // Instantly update to avoid lag
                setState(() {
                  widget.appState.savePosition(
                      widget.id,
                      currentLeft + details.delta.dx,
                      currentTop + details.delta.dy);
                });
              },
              child: Opacity(
                opacity: 0.7,
                child: buttonContent,
              ),
            ),
          );
        }

        return Positioned(
          left: currentLeft,
          top: currentTop,
          child: Listener(
            onPointerDown: (_) {
              setState(() => isPressed = true);
              _sendState(true);
            },
            onPointerUp: (_) {
              setState(() => isPressed = false);
              _sendState(false);
            },
            onPointerCancel: (_) {
              setState(() => isPressed = false);
              _sendState(false);
            },
            child: buttonContent,
          ),
        );
      },
    );
  }
}
