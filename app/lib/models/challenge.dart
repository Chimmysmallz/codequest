/// The interactive puzzle attached to a mission.
///
/// Two kinds:
///  - `fill_blank`: pick the correct option to fill a blank in a template.
///  - `code`: write real Python (needs the backend to execute).
///
/// [fromJson] tolerates the server hiding secret fields (`answer`,
/// `expectedOutput`) so the same model works online and offline.
class Challenge {
  final String type; // 'fill_blank' | 'code'
  final String prompt;
  final String? template;
  final String? starter;
  final String blankToken;
  final List<String>? options;
  final String? answer;
  final String? expectedOutput;
  final String hint;

  const Challenge({
    required this.type,
    required this.prompt,
    this.template,
    this.starter,
    this.blankToken = '___',
    this.options,
    this.answer,
    this.expectedOutput,
    required this.hint,
  });

  bool get isFillBlank => type == 'fill_blank';
  bool get isCode => type == 'code';

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return Challenge(
      type: json['type'] as String,
      prompt: (json['prompt'] as String?) ?? '',
      template: json['template'] as String?,
      starter: json['starter'] as String?,
      blankToken: (json['blankToken'] as String?) ?? '___',
      options: rawOptions is List
          ? rawOptions.map((e) => e.toString()).toList()
          : null,
      answer: json['answer'] as String?,
      expectedOutput: json['expectedOutput'] as String?,
      hint: (json['hint'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'prompt': prompt,
        if (template != null) 'template': template,
        if (starter != null) 'starter': starter,
        'blankToken': blankToken,
        if (options != null) 'options': options,
        if (answer != null) 'answer': answer,
        if (expectedOutput != null) 'expectedOutput': expectedOutput,
        'hint': hint,
      };
}
