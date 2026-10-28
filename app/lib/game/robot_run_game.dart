import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// A small Flame scene: the robot walks `steps` tiles to the charging pad.
///
/// Used by "Help the Robot!" style loop missions. The scene draws a lane, a
/// glowing charging pad and the robot sprite, then (when [run] is called)
/// animates the robot stepping across to the pad. When the walk finishes
/// [onArrived] fires so the host screen can award + navigate.
///
/// Robustness: if the sprite fails to load or there is nothing to walk
/// (`steps <= 0`), [run] still calls [onArrived] immediately so the success
/// flow is never blocked, and the scene never throws.
class RobotRunGame extends FlameGame {
  RobotRunGame({required this.steps, required this.onArrived});

  final int steps;
  final VoidCallback onArrived;

  SpriteComponent? _robot;
  bool _ran = false;
  double _startX = 0, _padX = 0, _laneY = 0, _stepDx = 0;

  @override
  Color backgroundColor() => const Color(0xFF171334);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/art/';
    final w = size.x, h = size.y;
    _laneY = h * 0.66;
    _startX = w * 0.14;
    _padX = w * 0.82;
    _stepDx = steps > 0 ? (_padX - _startX) / steps : 0;

    // ground lane
    add(RectangleComponent(
      position: Vector2(0, _laneY + h * 0.02),
      size: Vector2(w, h * 0.34),
      paint: Paint()..color = const Color(0xFF241D54),
    ));
    // charging pad
    add(CircleComponent(
      radius: h * 0.07,
      position: Vector2(_padX, _laneY),
      anchor: Anchor.center,
      paint: Paint()..color = const Color(0xFFFFC93C),
    ));
    // robot
    try {
      final robotSize = h * 0.34;
      final robot = SpriteComponent(
        sprite: await loadSprite('art-robot.png'),
        size: Vector2.all(robotSize),
        position: Vector2(_startX, _laneY),
        anchor: Anchor.bottomCenter,
      );
      _robot = robot;
      add(robot);
    } catch (_) {
      // Art missing / unloadable: the lane + pad still render, and run() will
      // award immediately since _robot stays null.
    }
  }

  /// Trigger the walk animation (safe to call once).
  ///
  /// If the robot never loaded or there is nothing to walk, [onArrived] is
  /// called synchronously so the caller's success path still completes.
  void run() {
    if (_ran) return;
    _ran = true;

    final robot = _robot;
    if (robot == null || steps <= 0 || _stepDx == 0) {
      onArrived();
      return;
    }

    final effects = <Effect>[
      for (var i = 0; i < steps; i++)
        MoveByEffect(
          Vector2(_stepDx, 0),
          EffectController(duration: 0.35, curve: Curves.easeInOut),
        ),
    ];
    robot.add(SequenceEffect(effects, onComplete: onArrived));
  }

  bool get hasRun => _ran;
}
