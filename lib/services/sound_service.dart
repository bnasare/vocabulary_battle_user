import 'package:flutter/services.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  /// Play sound/haptic for correct answer
  Future<void> playCorrect() async {
    await HapticFeedback.lightImpact();
  }

  /// Play sound/haptic for wrong answer
  Future<void> playWrong() async {
    await HapticFeedback.mediumImpact();
  }

  /// Play sound/haptic for winning
  Future<void> playWin() async {
    // Multiple light impacts for celebration
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Play sound/haptic for losing
  Future<void> playLose() async {
    await HapticFeedback.heavyImpact();
  }

  /// Play sound/haptic for tie game
  Future<void> playTie() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// Play sound/haptic for time running out
  Future<void> playTimerWarning() async {
    await HapticFeedback.vibrate();
  }

  /// Play sound/haptic for completing battle
  Future<void> playBattleComplete() async {
    await HapticFeedback.mediumImpact();
  }

  /// Play sound/haptic for achievement unlock
  Future<void> playAchievement() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
  }

  /// Play sound/haptic for button tap
  Future<void> playTap() async {
    await HapticFeedback.selectionClick();
  }
}
