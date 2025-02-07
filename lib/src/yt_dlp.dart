import 'dart:convert';
import 'dart:io';

typedef ExecutorFn = Future<String> Function(List<String> args);

class YtDlp {
  static final instance = YtDlp._();

  YtDlp._();

  File? _binaryLocation;
  ExecutorFn? _customExecutor;

  void setCustomExecutor(ExecutorFn executor) {
    _customExecutor = executor;
  }

  File get binaryLocation {
    assert(_binaryLocation != null, 'YtDlp binary location is not set');

    return _binaryLocation!;
  }

  Future<bool> checkAvailableInPath() async {
    return await _expandFromEnvPath(
          "yt-dlp${Platform.isWindows ? '.exe' : ''}",
        ) !=
        null;
  }

  Future<String?> _expandFromEnvPath(String binary) async {
    if (binary.contains("/") || binary.contains("\\")) {
      return null;
    }
    final envPath = Platform.environment["PATH"] ?? "";
    final paths = Platform.isWindows ? envPath.split(";") : envPath.split(":");

    for (final path in paths) {
      final file = File("$path/$binary");

      if (await file.exists()) {
        return file.path;
      }
    }

    return null;
  }

  Future<void> setBinaryLocation(String location) async {
    File file = File(location);

    if (!await file.exists()) {
      final inPath = await _expandFromEnvPath(location);
      if (inPath != null) {
        file = File(inPath);
      } else {
        throw FileSystemException(
          "yt-dlp binary not found at $location or in PATH",
        );
      }
    }

    _binaryLocation = file;
  }

  Future<String> _executeString(List<String> args) async {
    if (_customExecutor != null) {
      return _customExecutor!(args);
    }

    final result = await Process.run(
      binaryLocation.path,
      args,
    );

    return result.stdout.toString();
  }

  /// Returns the version of the yt-dlp binary
  Future<String> version() async {
    return _executeString(["--version"]);
  }

  Future<List<String>> listExtractors() async {
    final output = await _executeString(["--list-extractors"]);

    return output.split("\n").map((e) => e.trim()).toList();
  }

  Future extractInfo(
    String url, {
    String formatSpecifiers = "'%()j'", // dumps all the info
    List<String> extraArgs = const [],
  }) async {
    final output = await extractInfoString(
      url,
      formatSpecifiers: formatSpecifiers,
      extraArgs: extraArgs,
    );

    try {
      return jsonDecode(output);
    } catch (e) {
      throw Exception("Failed to parse yt-dlp output: $output");
    }
  }

  Future<String> extractInfoString(
    String url, {
    String formatSpecifiers = "'%()j'", // dumps all the info
    List<String> extraArgs = const [],
  }) async {
    return await _executeString(
      ["--print", formatSpecifiers, ...extraArgs, url],
    );
  }
}
