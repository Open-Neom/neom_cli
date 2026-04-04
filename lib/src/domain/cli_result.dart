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

  factory CliResult.fromJson(Map<String, dynamic> json) => CliResult(
    exitCode: json['exitCode'] as int,
    stdout: json['stdout'] as String? ?? '',
    stderr: json['stderr'] as String? ?? '',
    command: json['command'] as String? ?? '',
    duration: json['durationMs'] != null
        ? Duration(milliseconds: json['durationMs'] as int)
        : null,
    workingDirectory: json['workingDirectory'] as String?,
    timestamp: json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now(),
  );

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
