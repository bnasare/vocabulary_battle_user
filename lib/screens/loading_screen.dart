import 'package:flutter/material.dart';

import '../core/constants.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // App splash image
            Image.asset(
              'assets/images/splash.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const Spacer(),
            // App name
            const Padding(
              padding: EdgeInsets.only(bottom: 40.0),
              child: Text(
                'BvN Battle',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 32,
                  fontFamily: 'MarcellusSC',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
