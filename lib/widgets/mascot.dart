// "Rafiq" — the friendly owl mascot, drawn with simple shapes.
import 'package:flutter/material.dart';

import '../theme.dart';

enum MascotMood { happy, neutral, sad, celebrate }

class Mascot extends StatelessWidget {
  final double size;
  final MascotMood mood;

  const Mascot({super.key, this.size = 120, this.mood = MascotMood.happy});

  @override
  Widget build(BuildContext context) {
    final eyeOffset = mood == MascotMood.sad ? 2.0 : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // body
          Container(
            width: size,
            height: size * 0.92,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(size * 0.42),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.greenDark,
                    offset: Offset(0, 4),
                    blurRadius: 0),
              ],
            ),
          ),
          // belly
          Positioned(
            bottom: size * 0.06,
            child: Container(
              width: size * 0.55,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(size * 0.3)),
              ),
            ),
          ),
          // wings
          Positioned(
            left: -size * 0.02,
            top: size * 0.34,
            child: _wing(size),
          ),
          Positioned(
            right: -size * 0.02,
            top: size * 0.34,
            child: _wing(size),
          ),
          // eyes
          Positioned(
            top: size * 0.18,
            child: Row(
              children: [
                _eye(size, eyeOffset),
                SizedBox(width: size * 0.10),
                _eye(size, eyeOffset),
              ],
            ),
          ),
          // beak
          Positioned(
            top: size * 0.44,
            child: Container(
              width: size * 0.16,
              height: size * 0.13,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(size * 0.1),
                  bottomRight: Radius.circular(size * 0.1),
                  topLeft: Radius.circular(size * 0.05),
                  topRight: Radius.circular(size * 0.05),
                ),
              ),
            ),
          ),
          // tufts
          Positioned(
            top: 0,
            left: size * 0.22,
            child: _tuft(size),
          ),
          Positioned(
            top: 0,
            right: size * 0.22,
            child: _tuft(size),
          ),
          if (mood == MascotMood.celebrate)
            Positioned(
              top: -size * 0.02,
              right: size * 0.02,
              child: Text('⭐',
                  style: TextStyle(fontSize: size * 0.22)),
            ),
        ],
      ),
    );
  }

  Widget _wing(double size) => Container(
        width: size * 0.16,
        height: size * 0.34,
        decoration: BoxDecoration(
          color: AppColors.greenDark,
          borderRadius: BorderRadius.circular(size * 0.1),
        ),
      );

  Widget _tuft(double size) => Container(
        width: size * 0.10,
        height: size * 0.14,
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(size * 0.06),
          ),
        ),
      );

  Widget _eye(double size, double sadOffset) {
    return Container(
      width: size * 0.22,
      height: size * 0.22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: sadOffset * (size / 120)),
        child: Container(
          width: size * 0.10,
          height: size * 0.10,
          decoration: BoxDecoration(
            color: AppColors.ink,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
