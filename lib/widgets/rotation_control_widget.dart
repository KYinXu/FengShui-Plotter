import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

const int kMiddleMouseButton = 0x04;

class RotationControlWidget extends StatefulWidget {
  final double initialRotation;
  final double minRotation;
  final double maxRotation;
  final ValueChanged<double> onRotationChanged;
  final Widget child;

  const RotationControlWidget({
    super.key,
    required this.initialRotation,
    this.minRotation = -1.5,
    this.maxRotation = 1.5,
    required this.onRotationChanged,
    required this.child,
  });

  @override
  State<RotationControlWidget> createState() => _RotationControlWidgetState();
}

class _RotationControlWidgetState extends State<RotationControlWidget> {
  late double _rotationZ;
  bool _isMiddleMouseDown = false;
  double _lastPointerX = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationZ = widget.initialRotation;
  }

  void _updateRotation(double newRotation) {
    setState(() {
      _rotationZ = newRotation.clamp(widget.minRotation, widget.maxRotation);
    });
    widget.onRotationChanged(_rotationZ);
  }

  void _resetRotation() {
    _updateRotation(widget.initialRotation);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.mouse && event.buttons == kMiddleMouseButton) {
              _isMiddleMouseDown = true;
              _lastPointerX = event.position.dx;
            }
          },
          onPointerMove: (event) {
            if (_isMiddleMouseDown) {
              final dx = event.position.dx - _lastPointerX;
              _lastPointerX = event.position.dx;
              _updateRotation(_rotationZ + dx * 0.01);
            }
          },
          onPointerUp: (event) {
            if (event.kind == PointerDeviceKind.mouse && event.buttons == 0) {
              _isMiddleMouseDown = false;
            }
          },
          child: widget.child,
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Reset Rotation',
              onPressed: _resetRotation,
            ),
          ),
        ),
      ],
    );
  }
}

class RotationSlider extends StatelessWidget {
  final double rotation;
  final double minRotation;
  final double maxRotation;
  final ValueChanged<double> onRotationChanged;

  const RotationSlider({
    super.key,
    required this.rotation,
    this.minRotation = -1.5,
    this.maxRotation = 1.5,
    required this.onRotationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.rotate_left),
          Expanded(
            child: Slider(
              min: minRotation,
              max: maxRotation,
              value: rotation,
              onChanged: onRotationChanged,
            ),
          ),
          const Icon(Icons.rotate_right),
        ],
      ),
    );
  }
} 