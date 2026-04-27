// lib/models/match_model.dart

class MatchModel {
  final String matchId;
  final String userId;
  final String name;
  final String image;
  final bool isOnline;

  MatchModel({
    required this.matchId,
    required this.userId,
    required this.name,
    required this.image,
    required this.isOnline,
  });
}
