import 'dart:convert';
import 'dart:io';

const _marker = 'CANVAS_PERF ';

void main(List<String> args) async {
  final cli = _parseArgs(args);
  if (cli.showHelp) {
    _printHelp();
    exit(0);
  }

  if (cli.inputPath == null || cli.inputPath!.isEmpty) {
    stderr.writeln('Missing required --input argument.');
    _printHelp();
    exit(2);
  }

  final inputFile = File(cli.inputPath!);
  if (!await inputFile.exists()) {
    stderr.writeln('Input file not found: ${cli.inputPath}');
    exit(2);
  }

  final operationSamples = <String, _Samples>{};
  var totalLines = 0;
  var parsedEvents = 0;

  final stream = inputFile
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in stream) {
    totalLines += 1;

    final parsed = _parseLogLine(line);
    if (parsed == null) {
      continue;
    }

    final operation = parsed.operation;

    if (cli.operationFilter != null &&
        !operation.contains(cli.operationFilter!)) {
      continue;
    }

    final samples = operationSamples.putIfAbsent(operation, _Samples.new);
    samples.count += 1;

    final durationMs = _asDouble(parsed.metrics['durationMs']);
    if (durationMs != null) {
      samples.durationMs.add(durationMs);
    }

    final avgFrameMs = _asDouble(parsed.metrics['avgFrameMs']);
    if (avgFrameMs != null) {
      samples.avgFrameMs.add(avgFrameMs);
    }

    final avgBuildMs = _asDouble(parsed.metrics['avgBuildMs']);
    if (avgBuildMs != null) {
      samples.avgBuildMs.add(avgBuildMs);
    }

    final avgRasterMs = _asDouble(parsed.metrics['avgRasterMs']);
    if (avgRasterMs != null) {
      samples.avgRasterMs.add(avgRasterMs);
    }

    final worstFrameMs = _asDouble(parsed.metrics['worstFrameMs']);
    if (worstFrameMs != null) {
      samples.worstFrameMs.add(worstFrameMs);
    }

    final frameCount = _asInt(parsed.metrics['frameCount']);
    final jankCount = _asInt(parsed.metrics['jankCount']);
    if (frameCount != null && frameCount >= 0) {
      samples.frameCountTotal += frameCount;
    }
    if (jankCount != null && jankCount >= 0) {
      samples.jankCountTotal += jankCount;
    }

    parsedEvents += 1;
  }

  if (parsedEvents == 0) {
    stdout.writeln(
      'No supported perf entries found in ${cli.inputPath} '
      '(expected CANVAS_PERF lines or backend JSONL with operation/durationMs).',
    );
    exit(0);
  }

  final keys = operationSamples.keys.toList()..sort();
  final summary = <String, Map<String, dynamic>>{};

  for (final op in keys) {
    final samples = operationSamples[op]!;
    summary[op] = {
      'events': samples.count,
      'durationMs': _distribution(samples.durationMs),
      'avgFrameMs': _distribution(samples.avgFrameMs),
      'avgBuildMs': _distribution(samples.avgBuildMs),
      'avgRasterMs': _distribution(samples.avgRasterMs),
      'worstFrameMs': _distribution(samples.worstFrameMs),
      'jankRate': samples.frameCountTotal > 0
          ? _round((samples.jankCountTotal / samples.frameCountTotal) * 100)
          : null,
      'totalFrames': samples.frameCountTotal,
      'totalJankFrames': samples.jankCountTotal,
    };
  }

  if (cli.outputJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'input': cli.inputPath,
        'totalLines': totalLines,
        'parsedEvents': parsedEvents,
        'operations': summary,
      }),
    );
    exit(0);
  }

  stdout.writeln('Canvas performance summary');
  stdout.writeln('Input: ${cli.inputPath}');
  stdout.writeln('Lines scanned: $totalLines');
  stdout.writeln('Events parsed: $parsedEvents');
  stdout.writeln();
  stdout.writeln(
    'operation | events | dur p50/p95 | frame p50/p95 | build p50/p95 | raster p50/p95 | jank rate | worst p95',
  );

  for (final op in keys) {
    final item = summary[op]!;
    final duration = item['durationMs'] as Map<String, dynamic>?;
    final avgFrame = item['avgFrameMs'] as Map<String, dynamic>?;
    final avgBuild = item['avgBuildMs'] as Map<String, dynamic>?;
    final avgRaster = item['avgRasterMs'] as Map<String, dynamic>?;
    final worstFrame = item['worstFrameMs'] as Map<String, dynamic>?;

    final durCell = _pair(duration);
    final frameCell = _pair(avgFrame);
    final buildCell = _pair(avgBuild);
    final rasterCell = _pair(avgRaster);
    final jankCell = item['jankRate'] == null ? '-' : '${item['jankRate']}%';
    final worstP95 = _single(worstFrame?['p95']);

    stdout.writeln(
      '$op | ${item['events']} | $durCell | $frameCell | $buildCell | $rasterCell | $jankCell | $worstP95',
    );
  }
}

class _CliOptions {
  _CliOptions({
    this.inputPath,
    this.operationFilter,
    this.outputJson = false,
    this.showHelp = false,
  });

  final String? inputPath;
  final String? operationFilter;
  final bool outputJson;
  final bool showHelp;
}

_CliOptions _parseArgs(List<String> args) {
  String? inputPath;
  String? operationFilter;
  var outputJson = false;
  var showHelp = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }
    if (arg == '--json') {
      outputJson = true;
      continue;
    }
    if (arg.startsWith('--input=')) {
      inputPath = arg.substring('--input='.length);
      continue;
    }
    if (arg == '--input' && i + 1 < args.length) {
      inputPath = args[++i];
      continue;
    }
    if (arg.startsWith('--operation=')) {
      operationFilter = arg.substring('--operation='.length);
      continue;
    }
    if (arg == '--operation' && i + 1 < args.length) {
      operationFilter = args[++i];
      continue;
    }
  }

  return _CliOptions(
    inputPath: inputPath,
    operationFilter: operationFilter,
    outputJson: outputJson,
    showHelp: showHelp,
  );
}

void _printHelp() {
  stdout.writeln(
    'Usage: dart run tool/canvas_perf_summary.dart --input <log-file> [options]',
  );
  stdout.writeln();
  stdout.writeln('Options:');
  stdout
      .writeln('  --operation <text>   Filter operations containing this text');
  stdout.writeln('  --json               Emit machine-readable JSON summary');
  stdout.writeln('  --help, -h           Show help');
}

class _Samples {
  int count = 0;
  final List<double> durationMs = [];
  final List<double> avgFrameMs = [];
  final List<double> avgBuildMs = [];
  final List<double> avgRasterMs = [];
  final List<double> worstFrameMs = [];
  int frameCountTotal = 0;
  int jankCountTotal = 0;
}

class _ParsedLogLine {
  _ParsedLogLine({
    required this.operation,
    required this.metrics,
  });

  final String operation;
  final Map<String, dynamic> metrics;
}

_ParsedLogLine? _parseLogLine(String line) {
  Map<String, dynamic>? payload;

  final markerIndex = line.indexOf(_marker);
  if (markerIndex >= 0) {
    final jsonPart = line.substring(markerIndex + _marker.length).trim();
    payload = _decodeMap(jsonPart);
  } else {
    payload = _decodeMap(line.trim());
  }

  if (payload == null) return null;

  final operation = payload['operation'];
  if (operation is! String || operation.isEmpty) return null;

  final metrics = payload['metrics'];
  final metricsMap = metrics is Map<Object?, Object?>
      ? metrics.cast<String, dynamic>()
      : <String, dynamic>{};

  final rootDuration = _asDouble(payload['durationMs']);
  if (rootDuration != null && !metricsMap.containsKey('durationMs')) {
    metricsMap['durationMs'] = rootDuration;
  }

  return _ParsedLogLine(
    operation: operation,
    metrics: metricsMap,
  );
}

Map<String, dynamic>? _decodeMap(String value) {
  if (value.isEmpty) return null;

  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    return null;
  }

  return null;
}

Map<String, dynamic>? _distribution(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  return {
    'min': _round(sorted.first),
    'p50': _round(_percentile(sorted, 0.50)),
    'p95': _round(_percentile(sorted, 0.95)),
    'max': _round(sorted.last),
  };
}

double _percentile(List<double> sorted, double percentile) {
  if (sorted.length == 1) return sorted.first;
  final index = percentile * (sorted.length - 1);
  final lower = index.floor();
  final upper = index.ceil();
  if (lower == upper) return sorted[lower];
  final weight = index - lower;
  return sorted[lower] + (sorted[upper] - sorted[lower]) * weight;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _round(num value) => double.parse(value.toStringAsFixed(3));

String _pair(Map<String, dynamic>? dist) {
  if (dist == null) return '-';
  return '${_single(dist['p50'])}/${_single(dist['p95'])}';
}

String _single(Object? value) {
  if (value == null) return '-';
  if (value is num) return value.toStringAsFixed(3);
  return value.toString();
}
