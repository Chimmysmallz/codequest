import '../models/challenge.dart';
import '../models/mission.dart';
import '../models/world.dart';

/// Canonical, offline-playable content bundled with the app.
///
/// This is the single source of truth on the client and mirrors the Python
/// backend EXACTLY. It intentionally includes `answer` / `expectedOutput` so
/// offline mode can check submissions locally without a server.
class SeedContent {
  SeedContent._();

  static const List<World> worlds = [
    World(id: 'village', name: 'Village', order: 0, icon: 'village'),
    World(id: 'forest', name: 'Forest', order: 1, icon: 'forest'),
    World(id: 'factory', name: 'Factory', order: 2, icon: 'factory'),
    World(id: 'castle', name: 'Castle', order: 3, icon: 'castle'),
    World(id: 'space', name: 'Space Station', order: 4, icon: 'space'),
  ];

  static const List<Mission> missions = [
    // ---- Village ----
    Mission(
      id: 'v1',
      worldId: 'village',
      index: 1,
      title: 'Say Hello',
      description:
          'Every program starts somewhere. Pick the line that prints a greeting.',
      xp: 30,
      coins: 50,
      reward: 'Sticker: Hello',
      challenge: Challenge(
        type: 'fill_blank',
        prompt: 'Which line prints Hello?',
        template: '___',
        options: [
          'print("Hello")',
          'echo("Hello")',
          'display("Hello")',
        ],
        answer: 'print("Hello")',
        hint: 'Python uses the print() function.',
      ),
    ),
    Mission(
      id: 'v2',
      worldId: 'village',
      index: 2,
      title: 'Name Tag',
      description: 'Print a name to the screen.',
      xp: 40,
      coins: 60,
      reward: 'Sticker: Star',
      challenge: Challenge(
        type: 'code',
        prompt: 'Print the name: Ada',
        starter: 'print(___)',
        expectedOutput: 'Ada\n',
        hint: 'Text goes inside quotes, like "Ada".',
      ),
    ),

    // ---- Forest ----
    Mission(
      id: 'f1',
      worldId: 'forest',
      index: 3,
      title: 'Into the Woods',
      description: 'Loops repeat actions. Choose the keyword that repeats.',
      xp: 45,
      coins: 80,
      reward: 'Badge: Explorer',
      challenge: Challenge(
        type: 'fill_blank',
        prompt: 'Which keyword repeats an action?',
        template: '___ i in range(3):',
        options: ['for', 'if', 'def'],
        answer: 'for',
        hint: 'It starts a loop.',
      ),
    ),
    Mission(
      id: 'f2',
      worldId: 'forest',
      index: 4,
      title: 'Help the Robot!',
      description:
          'The robot needs to move five times to reach the charging pad. Use a loop to get it there.',
      xp: 50,
      coins: 100,
      reward: "Explorer's Cap",
      challenge: Challenge(
        type: 'fill_blank',
        prompt: 'Drag the right piece so the robot moves 5 times.',
        template: 'for ___ in range(5):\n    robot.move()',
        options: ['i', 'x', '5', 'robot'],
        answer: 'i',
        hint: "It's the counter variable for the loop.",
      ),
    ),
    Mission(
      id: 'f3',
      worldId: 'forest',
      index: 5,
      title: 'Count to Five',
      description: 'Now write real Python: print 1 through 5.',
      xp: 60,
      coins: 120,
      reward: 'Badge: Counter',
      challenge: Challenge(
        type: 'code',
        prompt: 'Print the numbers 1 to 5, one per line.',
        starter: 'for i in range(1, 6):\n    print(___)',
        expectedOutput: '1\n2\n3\n4\n5\n',
        hint: 'Print the loop variable i.',
      ),
    ),

    // ---- Factory ----
    Mission(
      id: 'fac1',
      worldId: 'factory',
      index: 6,
      title: 'Assembly Math',
      description: 'Machines add parts together.',
      xp: 60,
      coins: 120,
      reward: 'Badge: Builder',
      challenge: Challenge(
        type: 'code',
        prompt: 'Print the sum of 7 and 5.',
        starter: 'print(7 ___ 5)',
        expectedOutput: '12\n',
        hint: 'Use the + operator to add.',
      ),
    ),

    // ---- Castle ----
    Mission(
      id: 'c1',
      worldId: 'castle',
      index: 7,
      title: 'Guard the Gate',
      description:
          'Decisions use if. Choose what happens when the password is right.',
      xp: 70,
      coins: 140,
      reward: 'Badge: Keeper',
      challenge: Challenge(
        type: 'fill_blank',
        prompt: 'Fill the action when the password is correct.',
        template: 'if password == "open":\n    ___("Welcome")',
        options: ['print', 'range', 'input'],
        answer: 'print',
        hint: 'You want to show a message.',
      ),
    ),

    // ---- Space Station ----
    Mission(
      id: 's1',
      worldId: 'space',
      index: 8,
      title: 'Liftoff',
      description: 'Blast off with your first message to the stars.',
      xp: 80,
      coins: 160,
      reward: 'Badge: Astronaut',
      challenge: Challenge(
        type: 'code',
        prompt: 'Print: Liftoff',
        starter: 'print(___)',
        expectedOutput: 'Liftoff\n',
        hint: 'Put Liftoff inside quotes.',
      ),
    ),
  ];
}
