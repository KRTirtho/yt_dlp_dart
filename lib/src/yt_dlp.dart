import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:yt_dlp_dart/src/links.dart';
import 'package:yt_dlp_dart/src/utils.dart';

typedef ExecutorFn = Future<String> Function(List<String> args);

class YtDlp {
  static final instance = YtDlp._();

  YtDlp._();

  final _dio = Dio();

  File? _binaryLocation;
  ExecutorFn? _customExecutor;

  void setCustomExecutor(ExecutorFn executor) {
    _customExecutor = executor;
  }

  File get binaryLocation {
    assert(_binaryLocation != null, 'YtDlp binary location is not set');

    return _binaryLocation!;
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

  /// Downloads yt-dlp for the current platform
  /// outputs the bytes of the downloaded file
  Future<Uint8List> download(String version) async {
    final links = getYtDlpDownloadUrls(version);
    final os = Platform.operatingSystem;
    final arch = abiToCpuArch();
    final downloadUrl = links[os]?[arch];

    assert(downloadUrl != null, 'Unsupported platform: $os $arch');

    final response = await _dio.get(
      downloadUrl!,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );

    return response.data as Uint8List;
  }

  /// Saves the yt-dlp binary to the specified path
  /// and sets the binary location
  Future<void> save(Uint8List binary, String path) async {
    final file = File(path);

    await file.writeAsBytes(binary);

    await setBinaryLocation(path);
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

  Future<Map<String, dynamic>> extractInfo(
    String url, {
    String formatSpecifiers = "'%()j'", // dumps all the info
  }) async {
    return jsonDecode(
      await _executeString(["--print", formatSpecifiers, url]),
    );
  }
}
