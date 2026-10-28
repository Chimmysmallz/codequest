import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/robot_run_game.dart';
import '../models/challenge.dart';
import '../models/mission.dart';
import '../providers/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

/// The interactive challenge: fill-in-the-blank chips or a code editor.
class CodeChallengeScreen extends StatefulWidget {
  final Mission mission;
  const CodeChallengeScreen({super.key, required this.mission});

  @override
  State<CodeChallengeScreen> createState() => _CodeChallengeScreenState();
}

class _CodeChallengeScreenState extends State<CodeChallengeScreen> {
  // Fill-blank state.
  String? _selected;

  // Code state.
  late final TextEditingController _codeController;

  bool _hintShown = false;
  bool _busy = false;
  String? _feedback;
  bool _feedbackIsError = false;
  String? _output;

  // Robot-mission (Flame) state.
  bool _walking = false;
  SubmitResult? _pendingResult;

  Challenge get _challenge => widget.mission.challenge;

  /// A "Help the Robot!" style mission: a fill-blank whose template drives the
  /// robot (`robot.move()`). Only these missions get the Flame walk animation.
  bool get _isRobotMission {
    final template = _challenge.template;
    return _challenge.isFillBlank &&
        template != null &&
        template.contains('robot.move');
  }

  /// How many tiles the robot walks, parsed from `range(N)` (defaults to 5).
  int get _steps {
    final template = _challenge.template ?? '';
    final match = RegExp(r'range\((\d+)\)').firstMatch(template);
    final parsed = match == null ? null : int.tryParse(match.group(1)!);
    return parsed ?? 5;
  }

  /// The Flame scene for a robot mission. Created lazily and exactly once, so
  /// non-robot challenges never spin up a game instance.
  late final RobotRunGame _robotGame =
      RobotRunGame(steps: _steps, onArrived: _onRobotArrived);

  @override
  void initState() {
    super.initState();
    _codeController =
        TextEditingController(text: _challenge.starter ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _revealHint() => setState(() => _hintShown = true);

  Future<void> _checkFillBlank() async {
    final answer = _selected;
    if (answer == null) {
      setState(() {
        _feedback = 'Pick an option first!';
        _feedbackIsError = true;
      });
      return;
    }
    setState(() => _busy = true);
    final game = context.read<GameState>();
    final result = await game.submitFillBlank(widget.mission, answer);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.passed) {
      if (_isRobotMission) {
        // The award already happened inside submitFillBlank; defer the result
        // navigation until the robot finishes walking to the charging pad.
        setState(() {
          _pendingResult = result;
          _walking = true;
        });
        _robotGame.run();
      } else {
        _goToResult(result);
      }
    } else {
      setState(() {
        _feedback = result.message;
        _feedbackIsError = true;
        _hintShown = true;
      });
    }
  }

  /// Fired when the robot reaches the charging pad. Navigates to the result
  /// screen exactly as the immediate success path does for other challenges.
  void _onRobotArrived() {
    if (!mounted) return;
    final result = _pendingResult;
    if (result == null) return;
    _goToResult(result);
  }

  void _goToResult(SubmitResult result) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(mission: widget.mission, result: result),
      ),
    );
  }

  Future<void> _runCode() async {
    setState(() {
      _busy = true;
      _output = null;
      _feedback = null;
    });
    final game = context.read<GameState>();
    final out = await game.runCode(_codeController.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _output = out;
    });
  }

  Future<void> _submitCode() async {
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final game = context.read<GameState>();
    final result = await game.submitCode(widget.mission, _codeController.text);
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.passed) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ResultScreen(mission: widget.mission, result: result),
        ),
      );
    } else {
      setState(() {
        _feedback = result.message;
        _feedbackIsError = true;
        if (result.output != null && result.output!.isNotEmpty) {
          _output = result.output;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mission.title),
        actions: [
          TextButton.icon(
            onPressed: _revealHint,
            icon: const Icon(Icons.lightbulb, color: AppColors.gold, size: 18),
            label: const Text('Hint',
                style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _challenge.prompt,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              if (_challenge.isFillBlank)
                _buildFillBlank()
              else
                _buildCode(),
              if (_hintShown) ...[
                const SizedBox(height: 16),
                _HintCard(hint: _challenge.hint),
              ],
              if (_feedback != null) ...[
                const SizedBox(height: 16),
                _FeedbackCard(
                  message: _feedback!,
                  isError: _feedbackIsError,
                ),
              ],
              if (_output != null) ...[
                const SizedBox(height: 16),
                _OutputPanel(output: _output!),
              ],
              const SizedBox(height: 26),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Fill blank ----------------------------------------------------------

  Widget _buildFillBlank() {
    final template = _challenge.template ?? _challenge.blankToken;
    final options = _challenge.options ?? const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isRobotMission) ...[
          _RobotStage(game: _robotGame),
          const SizedBox(height: 16),
        ],
        _CodeCard(
          child: _TemplateWithBlank(
            template: template,
            blankToken: _challenge.blankToken,
            filled: _selected,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tap the piece that fits:',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in options)
              _OptionChip(
                label: option,
                selected: _selected == option,
                onTap: _busy
                    ? null
                    : () => setState(() {
                          _selected = option;
                          _feedback = null;
                        }),
              ),
          ],
        ),
      ],
    );
  }

  // ---- Code ----------------------------------------------------------------

  Widget _buildCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CodeCard(
          child: TextField(
            controller: _codeController,
            maxLines: null,
            minLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.green,
              fontSize: 15,
              height: 1.4,
            ),
            cursorColor: AppColors.gold,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Write your Python here...',
              hintStyle: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Icon(Icons.info_outline, size: 14, color: AppColors.muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Running real Python needs the backend connected.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- Actions -------------------------------------------------------------

  Widget _buildActions() {
    if (_busy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.gold),
          ),
        ),
      );
    }

    if (_challenge.isFillBlank) {
      return PrimaryButton(
        label: _walking ? 'Nice! Robot on the move...' : 'Check',
        icon: _walking ? Icons.directions_walk_rounded : Icons.check_rounded,
        onPressed: _walking ? null : _checkFillBlank,
      );
    }

    // Code challenge: Run (preview) + Submit (grade).
    return Column(
      children: [
        PrimaryButton(
          label: 'Run',
          ghost: true,
          icon: Icons.play_arrow_rounded,
          onPressed: _runCode,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Submit',
          icon: Icons.check_rounded,
          onPressed: _submitCode,
        ),
      ],
    );
  }
}

/// Renders a code template with the blank token replaced by a highlighted slot.
class _TemplateWithBlank extends StatelessWidget {
  final String template;
  final String blankToken;
  final String? filled;

  const _TemplateWithBlank({
    required this.template,
    required this.blankToken,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    const codeStyle = TextStyle(
      fontFamily: 'monospace',
      color: AppColors.ink,
      fontSize: 16,
      height: 1.5,
    );

    final idx = template.indexOf(blankToken);
    if (idx < 0) {
      return Text(template, style: codeStyle);
    }

    final before = template.substring(0, idx);
    final after = template.substring(idx + blankToken.length);

    return RichText(
      text: TextSpan(
        style: codeStyle,
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _BlankSlot(text: filled),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}

class _BlankSlot extends StatelessWidget {
  final String? text;
  const _BlankSlot({this.text});

  @override
  Widget build(BuildContext context) {
    final filled = text != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled
            ? AppColors.brand.withOpacity(0.35)
            : AppColors.panel2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: filled ? AppColors.brand : AppColors.gold,
          width: 1.4,
        ),
      ),
      child: Text(
        filled ? text! : '?',
        style: TextStyle(
          fontFamily: 'monospace',
          color: filled ? AppColors.ink : AppColors.gold,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : AppColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.panel2,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A dark rounded panel used to frame code / templates.
class _CodeCard extends StatelessWidget {
  final Widget child;
  const _CodeCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0920),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panel2),
      ),
      child: child,
    );
  }
}

/// Hosts the Flame robot scene in a rounded, clipped 180px stage.
class _RobotStage extends StatelessWidget {
  final RobotRunGame game;
  const _RobotStage({required this.game});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: GameWidget(game: game),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String hint;
  const _HintCard({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackCard({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.pink : AppColors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle,
              color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputPanel extends StatelessWidget {
  final String output;
  const _OutputPanel({required this.output});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.terminal, color: AppColors.brand2, size: 18),
            SizedBox(width: 6),
            Text(
              'Output',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF07061A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.panel2),
          ),
          child: SelectableText(
            output,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: AppColors.green,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
