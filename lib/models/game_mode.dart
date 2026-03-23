/// Game mode configuration for Vocabulary Battle
enum GameMode {
  quick('quick', 'Quick', 15, 4, 3),
  normal('normal', 'Normal', 23, 6, 5),
  challenge('challenge', 'Challenge', 35, 10, 5);

  final String value;
  final String displayName;
  final int totalQuestions;
  final int questionsPerLetter;
  final int randomQuestions;

  const GameMode(
    this.value,
    this.displayName,
    this.totalQuestions,
    this.questionsPerLetter,
    this.randomQuestions,
  );

  /// Get estimated time in minutes
  int get estimatedMinutes => (totalQuestions * 0.5).ceil();

  /// Get description for UI
  String get description =>
      '$totalQuestions questions (3×$questionsPerLetter + $randomQuestions random) • ~$estimatedMinutes min';

  /// Parse from string value
  static GameMode fromString(String? value) {
    if (value == null) return GameMode.challenge; // Backward compatibility
    return GameMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => GameMode.challenge,
    );
  }

  /// Get the default mode for new games
  static GameMode get defaultMode => GameMode.normal;
}
