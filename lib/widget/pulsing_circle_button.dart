import 'package:flutter/material.dart';

class PulsingCircleButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPulsing;
  final Color centerColor;
  final Color outerColor;
  final Color pulseColor;

  const PulsingCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPulsing = false,
    this.centerColor = const Color.fromRGBO(93, 108, 134, 1),
    this.outerColor = const Color.fromRGBO(22, 16, 26, 1),
    this.pulseColor = const Color.fromRGBO(93, 108, 134, 1),
  });

  @override
  State<PulsingCircleButton> createState() => _PulsingCircleButtonState();
}

class _PulsingCircleButtonState extends State<PulsingCircleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _scale2Anim;
  late Animation<double> _opacity2Anim;
  late Animation<double> _scale3Anim;
  late Animation<double> _opacity3Anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnim = Tween<double>(
      begin: 0.9,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scale2Anim = Tween<double>(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity2Anim = Tween<double>(
      begin: 0.7,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scale3Anim = Tween<double>(
      begin: 1.0,
      end: 3.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacity3Anim = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.isPulsing) _controller.repeat();
  }

  @override
  void didUpdateWidget(PulsingCircleButton old) {
    super.didUpdateWidget(old);
    if (old.isPulsing == widget.isPulsing) return;
    if (widget.isPulsing) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Derive glossy highlight color from centerColor
  Color get _highlightColor => Color.fromRGBO(
    (widget.centerColor.red + 60).clamp(0, 255),
    (widget.centerColor.green + 40).clamp(0, 255),
    (widget.centerColor.blue + 40).clamp(0, 255),
    1,
  );

  // Derive dark edge color from outerColor
  Color get _darkEdgeColor => Color.fromRGBO(
    (widget.outerColor.red).clamp(0, 255),
    (widget.outerColor.green).clamp(0, 255),
    (widget.outerColor.blue).clamp(0, 255),
    1,
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Furthest ring
            if (widget.isPulsing)
              Transform.scale(
                scale: _scale3Anim.value,
                child: Opacity(
                  opacity: _opacity3Anim.value,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.pulseColor.withOpacity(0.2),
                    ),
                  ),
                ),
              ),
            // Outer ring
            if (widget.isPulsing)
              Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.pulseColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            // Inner ring
            if (widget.isPulsing)
              Transform.scale(
                scale: _scale2Anim.value,
                child: Opacity(
                  opacity: _opacity2Anim.value,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.pulseColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            // Main button — on top
            child!,
          ],
        );
      },
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // 👇 Glossy radial gradient
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.5),
                radius: 0.85,
                colors: [
                  _highlightColor, // bright highlight top-left
                  widget.centerColor, // mid color
                  _darkEdgeColor, // dark edge
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // 👇 Outer glow using pulseColor
                boxShadow: [
                  BoxShadow(
                    color: widget.pulseColor.withOpacity(0.6),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: widget.pulseColor.withOpacity(0.2),
                    blurRadius: 80,
                    spreadRadius: 15,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: Colors.white, size: 40),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
