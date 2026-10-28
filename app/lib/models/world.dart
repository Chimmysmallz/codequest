/// A world (level group) in CodeQuest, e.g. Village, Forest, Space Station.
class World {
  final String id;
  final String name;
  final int order;
  final String icon;

  const World({
    required this.id,
    required this.name,
    required this.order,
    required this.icon,
  });

  factory World.fromJson(Map<String, dynamic> json) {
    return World(
      id: json['id'] as String,
      name: json['name'] as String,
      order: (json['order'] as num).toInt(),
      icon: json['icon'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'icon': icon,
      };

  /// Maps the [icon] string to a bundled art asset path.
  String get assetPath {
    switch (icon) {
      case 'village':
        return 'assets/art/art-village.png';
      case 'forest':
        return 'assets/art/art-forest.png';
      case 'factory':
        return 'assets/art/art-factory.png';
      case 'castle':
        return 'assets/art/art-castle.png';
      case 'space':
        return 'assets/art/art-space.png';
      default:
        return 'assets/art/art-village.png';
    }
  }
}
