import 'package:flutter/material.dart';

class TvFocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;

  const TvFocusCard({
    super.key,
    required this.child,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<TvFocusCard> createState() => _TvFocusCardState();
}

class _TvFocusCardState extends State<TvFocusCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      onKeyEvent: (node, event) {
        if (event.logicalKey.keyLabel == 'Select' ||
            event.logicalKey.keyLabel == 'Enter') {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: _isFocused
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused ? Colors.blueAccent : Colors.transparent,
              width: 3,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}