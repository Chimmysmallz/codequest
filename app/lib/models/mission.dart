import 'challenge.dart';

/// A single mission (a lesson) that belongs to a [World].
class Mission {
  final String id;
  final String worldId;
  final int index;
  final String title;
  final String description;
  final int xp;
  final int coins;
  final String reward;
  final Challenge challenge;

  const Mission({
    required this.id,
    required this.worldId,
    required this.index,
    required this.title,
    required this.description,
    required this.xp,
    required this.coins,
    required this.reward,
    required this.challenge,
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      worldId: json['worldId'] as String,
      index: (json['index'] as num).toInt(),
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      xp: (json['xp'] as num).toInt(),
      coins: (json['coins'] as num).toInt(),
      reward: (json['reward'] as String?) ?? '',
      challenge:
          Challenge.fromJson(json['challenge'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'worldId': worldId,
        'index': index,
        'title': title,
        'description': description,
        'xp': xp,
        'coins': coins,
        'reward': reward,
        'challenge': challenge.toJson(),
      };
}
