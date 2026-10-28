"""Canonical CodeQuest content — single source of truth for the backend.

The Flutter app mirrors this exact data. If you change anything here, update the
app too. Secret fields ("answer" for fill_blank, "expectedOutput" for code) live
on the challenge dicts but MUST NEVER be sent to clients. Use public_challenge()
whenever you serialize a challenge over the wire.
"""

from typing import Dict, List, Optional

# XP economy -----------------------------------------------------------------
XP_PER_LEVEL = 250

# The token clients render as the fill-in blank.
BLANK_TOKEN = "___"

# Worlds (in canonical order) ------------------------------------------------
WORLDS: List[Dict] = [
    {"id": "village", "name": "Village", "order": 0, "icon": "village"},
    {"id": "forest", "name": "Forest", "order": 1, "icon": "forest"},
    {"id": "factory", "name": "Factory", "order": 2, "icon": "factory"},
    {"id": "castle", "name": "Castle", "order": 3, "icon": "castle"},
    {"id": "space", "name": "Space Station", "order": 4, "icon": "space"},
]

# Missions -------------------------------------------------------------------
# Each mission has a nested "challenge". Challenges are one of:
#   - type "fill_blank": has options[], answer (secret), template, hint.
#   - type "code":       has starter, expectedOutput (secret), hint.
MISSIONS: List[Dict] = [
    {
        "id": "v1",
        "worldId": "village",
        "index": 1,
        "title": "Say Hello",
        "description": "Every program starts somewhere. Pick the line that prints a greeting.",
        "xp": 30,
        "coins": 50,
        "reward": "Sticker: Hello",
        "challenge": {
            "type": "fill_blank",
            "prompt": "Which line prints Hello?",
            "template": "___",
            "options": ['print("Hello")', 'echo("Hello")', 'display("Hello")'],
            "answer": 'print("Hello")',
            "hint": "Python uses the print() function.",
        },
    },
    {
        "id": "v2",
        "worldId": "village",
        "index": 2,
        "title": "Name Tag",
        "description": "Print a name to the screen.",
        "xp": 40,
        "coins": 60,
        "reward": "Sticker: Star",
        "challenge": {
            "type": "code",
            "prompt": "Print the name: Ada",
            "starter": "print(___)",
            "expectedOutput": "Ada\n",
            "hint": 'Text goes inside quotes, like "Ada".',
        },
    },
    {
        "id": "f1",
        "worldId": "forest",
        "index": 3,
        "title": "Into the Woods",
        "description": "Loops repeat actions. Choose the keyword that repeats.",
        "xp": 45,
        "coins": 80,
        "reward": "Badge: Explorer",
        "challenge": {
            "type": "fill_blank",
            "prompt": "Which keyword repeats an action?",
            "template": "___ i in range(3):",
            "options": ["for", "if", "def"],
            "answer": "for",
            "hint": "It starts a loop.",
        },
    },
    {
        "id": "f2",
        "worldId": "forest",
        "index": 4,
        "title": "Help the Robot!",
        "description": "The robot needs to move five times to reach the charging pad. Use a loop to get it there.",
        "xp": 50,
        "coins": 100,
        "reward": "Explorer's Cap",
        "challenge": {
            "type": "fill_blank",
            "prompt": "Drag the right piece so the robot moves 5 times.",
            "template": "for ___ in range(5):\n    robot.move()",
            "options": ["i", "x", "5", "robot"],
            "answer": "i",
            "hint": "It's the counter variable for the loop.",
        },
    },
    {
        "id": "f3",
        "worldId": "forest",
        "index": 5,
        "title": "Count to Five",
        "description": "Now write real Python: print 1 through 5.",
        "xp": 60,
        "coins": 120,
        "reward": "Badge: Counter",
        "challenge": {
            "type": "code",
            "prompt": "Print the numbers 1 to 5, one per line.",
            "starter": "for i in range(1, 6):\n    print(___)",
            "expectedOutput": "1\n2\n3\n4\n5\n",
            "hint": "Print the loop variable i.",
        },
    },
    {
        "id": "fac1",
        "worldId": "factory",
        "index": 6,
        "title": "Assembly Math",
        "description": "Machines add parts together.",
        "xp": 60,
        "coins": 120,
        "reward": "Badge: Builder",
        "challenge": {
            "type": "code",
            "prompt": "Print the sum of 7 and 5.",
            "starter": "print(7 ___ 5)",
            "expectedOutput": "12\n",
            "hint": "Use the + operator to add.",
        },
    },
    {
        "id": "c1",
        "worldId": "castle",
        "index": 7,
        "title": "Guard the Gate",
        "description": "Decisions use if. Choose what happens when the password is right.",
        "xp": 70,
        "coins": 140,
        "reward": "Badge: Keeper",
        "challenge": {
            "type": "fill_blank",
            "prompt": "Fill the action when the password is correct.",
            "template": 'if password == "open":\n    ___("Welcome")',
            "options": ["print", "range", "input"],
            "answer": "print",
            "hint": "You want to show a message.",
        },
    },
    {
        "id": "s1",
        "worldId": "space",
        "index": 8,
        "title": "Liftoff",
        "description": "Blast off with your first message to the stars.",
        "xp": 80,
        "coins": 160,
        "reward": "Badge: Astronaut",
        "challenge": {
            "type": "code",
            "prompt": "Print: Liftoff",
            "starter": "print(___)",
            "expectedOutput": "Liftoff\n",
            "hint": "Put Liftoff inside quotes.",
        },
    },
]

# Lookups --------------------------------------------------------------------
_MISSIONS_BY_ID: Dict[str, Dict] = {m["id"]: m for m in MISSIONS}
_WORLDS_BY_ID: Dict[str, Dict] = {w["id"]: w for w in WORLDS}


def public_challenge(challenge: Dict) -> Dict:
    """Return a client-safe copy of a challenge with secret fields removed.

    Strips "answer" (fill_blank) and "expectedOutput" (code). Includes the hint
    on purpose — the app only reveals it after a wrong attempt, which is fine.
    """
    safe: Dict = {
        "type": challenge["type"],
        "prompt": challenge["prompt"],
        "hint": challenge.get("hint"),
    }
    if challenge["type"] == "fill_blank":
        safe["template"] = challenge.get("template")
        safe["options"] = list(challenge.get("options", []))
        safe["blankToken"] = BLANK_TOKEN
    elif challenge["type"] == "code":
        safe["starter"] = challenge.get("starter")
        # A code challenge still needs a blank token so the UI knows what to swap.
        safe["blankToken"] = BLANK_TOKEN
    return safe


def get_mission(mission_id: str) -> Optional[Dict]:
    """Return the mission dict for an id, or None if it does not exist."""
    return _MISSIONS_BY_ID.get(mission_id)


def get_world_missions(world_id: str) -> List[Dict]:
    """Return all missions belonging to a world, in canonical index order."""
    missions = [m for m in MISSIONS if m["worldId"] == world_id]
    missions.sort(key=lambda m: m["index"])
    return missions


def previous_world_id(world_id: str) -> Optional[str]:
    """Return the id of the world immediately before this one (by order).

    Returns None for the first world (order 0) or an unknown world id.
    """
    world = _WORLDS_BY_ID.get(world_id)
    if world is None:
        return None
    prev_order = world["order"] - 1
    if prev_order < 0:
        return None
    for w in WORLDS:
        if w["order"] == prev_order:
            return w["id"]
    return None
