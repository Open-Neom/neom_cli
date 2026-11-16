class CliResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final String command;
  final Duration? duration;
  final String? workingDirectory;
  final DateTime timestamp;

  bool get isSuccess => exitCode == 0;
  bool get isTimeout => exitCode == -2;
  bool get hasOutput => stdout.isNotEmpty;
  bool get hasError => stderr.isNotEmpty;

  CliResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.command = '',
    this.duration,
    this.workingDirectory,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  static int? _parseFiniteInt(Object? raw) {
    if (raw is num) {
      if (!raw.isFinite) return null;
      return raw.toInt();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null && asDouble.isFinite) return asDouble.toInt();
    }
    return null;
  }

  factory CliResult.fromJson(Map<String, dynamic> json) {
    final durationMs = _parseFiniteInt(json['durationMs']);
    final rawTs = json['timestamp'];
    return CliResult(
      exitCode: _parseFiniteInt(json['exitCode']) ?? -1,
      stdout: json['stdout']?.toString() ?? '',
      stderr: json['stderr']?.toString() ?? '',
      command: json['command']?.toString() ?? '',
      duration: durationMs != null
          ? Duration(milliseconds: durationMs < 0 ? 0 : durationMs)
          : null,
      workingDirectory: json['workingDirectory'] is String
          ? json['workingDirectory'] as String
          : null,
      timestamp: rawTs is String
          ? (DateTime.tryParse(rawTs) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'exitCode': exitCode,
    'stdout': stdout,
    'stderr': stderr,
    'command': command,
    'isSuccess': isSuccess,
    'durationMs': duration?.inMilliseconds,
    'workingDirectory': workingDirectory,
    'timestamp': timestamp.toIso8601String(),
  };

  CliResult copyWith({
    int? exitCode,
    String? stdout,
    String? stderr,
    String? command,
    Duration? duration,
    String? workingDirectory,
    DateTime? timestamp,
  }) => CliResult(
    exitCode: exitCode ?? this.exitCode,
    stdout: stdout ?? this.stdout,
    stderr: stderr ?? this.stderr,
    command: command ?? this.command,
    duration: duration ?? this.duration,
    workingDirectory: workingDirectory ?? this.workingDirectory,
    timestamp: timestamp ?? this.timestamp,
  );

  @override
  String toString() {
    final buf = StringBuffer('CliResult(exitCode: $exitCode, isSuccess: $isSuccess');
    if (duration != null) buf.write(', ${duration!.inMilliseconds}ms');
    buf.writeln(')');
    if (stdout.isNotEmpty) buf.writeln('STDOUT:\n$stdout');
    if (stderr.isNotEmpty) buf.writeln('STDERR:\n$stderr');
    return buf.toString();
  }
}
