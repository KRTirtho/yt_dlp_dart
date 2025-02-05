import 'dart:convert';

String smuggleUrl(String url, Map<String, dynamic> smuggledData) {
  final query = Uri(queryParameters: {
    "__youtubedl_smuggle": jsonEncode(smuggledData),
  }).query;
  return "$url#$query";
}

(String, Map<String, dynamic>?) unsmuggleUrl(
  String smugUrl, [
  Map<String, dynamic>? defaultValue,
]) {
  if (!smugUrl.contains("#__youtubedl_smuggle")) return (smugUrl, defaultValue);

  final [url, query] = smugUrl.split("#");

  final smuggledData = Uri.splitQueryString(query)["__youtubedl_smuggle"];
  if (smuggledData == null) return (url, defaultValue);

  return (url, jsonDecode(smuggledData) as Map<String, dynamic>);
}

T? lookup<T>(Map<String, dynamic> source, bool Function(String key) matcher) {
  for (final entry in source.entries) {
    if (matcher(entry.key)) {
      if (entry.value is T) {
        return entry.value as T;
      }
    }
    if (entry.value is Map) {
      final result = lookup<T>(entry.value, matcher);
      if (result != null) {
        return result;
      }
    }

    if (entry.value is List) {
      for (final item in entry.value as List) {
        if (item is Map) {
          final result = lookup<T>(source, matcher);
          if (result != null) {
            return result;
          }
        }
      }
    }
  }

  return null;
}

T? lookupAll<T>(
    List<Map<String, dynamic>> sources, bool Function(String key) matcher) {
  for (final source in sources) {
    final result = lookup<T>(source, matcher);
    if (result != null) {
      return result;
    }
  }

  return null;
}
