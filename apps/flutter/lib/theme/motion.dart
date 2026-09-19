import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

extension PgMotion on Widget {
  Widget springIn() => animate().fadeIn(duration: 300.ms).slideY(
        begin: -0.2, end: 0, curve: Curves.elasticOut, duration: 500.ms);
  Widget staggerChild(int index) => animate(delay: (index * 80).ms)
        .fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  Widget breathe() => animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(begin: 0.6, duration: 1200.ms);
}
