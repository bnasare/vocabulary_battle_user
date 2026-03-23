import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final bool isAdmin;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime lastLogin;
  final UserStats stats;
  final bool isOnline;
  final DateTime? lastSeen;
  final List<String> achievements;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.isAdmin,
    this.fcmToken,
    required this.createdAt,
    required this.lastLogin,
    required this.stats,
    this.isOnline = false,
    this.lastSeen,
    this.achievements = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'],
      isAdmin: data['isAdmin'] ?? false,
      fcmToken: data['fcmToken'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      stats: UserStats.fromMap(data['stats'] ?? {}),
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      achievements: List<String>.from(data['achievements'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isAdmin': isAdmin,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': Timestamp.fromDate(lastLogin),
      'stats': stats.toMap(),
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'achievements': achievements,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? isAdmin,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? lastLogin,
    UserStats? stats,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? achievements,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isAdmin: isAdmin ?? this.isAdmin,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      stats: stats ?? this.stats,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      achievements: achievements ?? this.achievements,
    );
  }
}

class UserStats {
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int ties;
  final int totalQuestionsAnswered;
  final int correctAnswers;
  final int winStreak;
  final double averageAccuracy;
  final Map<String, double> letterAccuracy;

  UserStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.ties = 0,
    this.totalQuestionsAnswered = 0,
    this.correctAnswers = 0,
    this.winStreak = 0,
    this.averageAccuracy = 0.0,
    this.letterAccuracy = const {},
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      gamesPlayed: map['gamesPlayed'] ?? 0,
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      ties: map['ties'] ?? 0,
      totalQuestionsAnswered: map['totalQuestionsAnswered'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      winStreak: map['winStreak'] ?? 0,
      averageAccuracy: (map['averageAccuracy'] ?? 0.0).toDouble(),
      letterAccuracy: Map<String, double>.from(map['letterAccuracy'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gamesPlayed': gamesPlayed,
      'wins': wins,
      'losses': losses,
      'ties': ties,
      'totalQuestionsAnswered': totalQuestionsAnswered,
      'correctAnswers': correctAnswers,
      'winStreak': winStreak,
      'averageAccuracy': averageAccuracy,
      'letterAccuracy': letterAccuracy,
    };
  }

  UserStats copyWith({
    int? gamesPlayed,
    int? wins,
    int? losses,
    int? ties,
    int? totalQuestionsAnswered,
    int? correctAnswers,
    int? winStreak,
    double? averageAccuracy,
    Map<String, double>? letterAccuracy,
  }) {
    return UserStats(
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      ties: ties ?? this.ties,
      totalQuestionsAnswered:
          totalQuestionsAnswered ?? this.totalQuestionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      winStreak: winStreak ?? this.winStreak,
      averageAccuracy: averageAccuracy ?? this.averageAccuracy,
      letterAccuracy: letterAccuracy ?? this.letterAccuracy,
    );
  }
}
