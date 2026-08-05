import 'package:flutter/material.dart';
import '../core/theme.dart';

class BrandMark extends StatelessWidget {
  final bool compact;
  final bool onDark;

  const BrandMark({super.key, this.compact = false, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? AppTheme.ivory : AppTheme.moss;
    final tileColor = onDark ? AppTheme.coral : AppTheme.moss;
    final iconColor = onDark ? AppTheme.moss : AppTheme.ivory;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 40 : 48,
          height: compact ? 40 : 48,
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(compact ? 13 : 16),
          ),
          child: Icon(
            Icons.translate_rounded,
            color: iconColor,
            size: compact ? 22 : 27,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          Text(
            'lingua',
            style: TextStyle(
              color: textColor,
              fontFamily: 'serif',
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
        ],
      ],
    );
  }
}
