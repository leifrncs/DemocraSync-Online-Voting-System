import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class RealTimeClock extends StatefulWidget {
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;
  final Color? borderColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final bool showDate;
  final bool showSeconds;

  const RealTimeClock({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
    this.borderColor,
    this.fontSize = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.showDate = true,
    this.showSeconds = true,
  });

  @override
  State<RealTimeClock> createState() => _RealTimeClockState();
}

class _RealTimeClockState extends State<RealTimeClock> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String formatString;
    if (widget.showDate && widget.showSeconds) {
      formatString = 'EEE, MMM d, yyyy • hh:mm:ss a';
    } else if (widget.showDate && !widget.showSeconds) {
      formatString = 'EEE, MMM d, yyyy • hh:mm a';
    } else if (!widget.showDate && widget.showSeconds) {
      formatString = 'hh:mm:ss a';
    } else {
      formatString = 'hh:mm a';
    }

    final formattedDate = DateFormat(formatString).format(_currentTime);
    final themeBg = widget.backgroundColor ?? Colors.white;
    final themeText = widget.textColor ?? nemsuBlue;
    final themeIcon = widget.iconColor ?? nemsuGold;
    final themeBorder = widget.borderColor ?? nemsuGold.withValues(alpha: 0.3);

    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: themeBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: themeBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: themeIcon.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: widget.fontSize + 3,
              color: themeIcon is MaterialColor ? themeIcon.shade800 : themeIcon,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formattedDate,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.w600,
                color: themeText,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
