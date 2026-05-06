import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import 'package:healty_app/screens/home/home_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // نفس Gradient بتاع الموقع 👇
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3F0FF), Colors.white, Color(0xFFF3F0FF)],
          ),
        ),

        child: Center(
          child: Lottie.asset(
            'assets/animations/animation.json',
            controller: _controller,
            width: 220,

            onLoaded: (composition) {
              _controller
                ..duration = composition.duration
                ..forward().whenComplete(() {
                  // بعد ما الأنيميشن يخلص 👇
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                });
            },
          ),
        ),
      ),
    );
  }
}
