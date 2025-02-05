import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:yt_dlp_dart/src/clients.dart';
import 'package:yt_dlp_dart/src/utils.dart';

const kYtBaseUrl = "https://www.youtube.com/";
const kDefaultClients = ["web", "ios", "tv"];
const kDefaultAuthClients = ["web", "tv"];
const kStreamingDataClientName = '__yt_dlp_client';
const kStreamingDataInitialPOToken = '__yt_dlp_po_token';

/// Operations required to get Stream manifest formats
class YtdlFormats {
  final Dio dio;
  final CookieJar cookieJar;

  final Map<String, dynamic> innerTubeClients;

  YtdlFormats()
      : dio = Dio(),
        cookieJar = CookieJar(),
        innerTubeClients = buildInnerTubeClients() {
    dio.interceptors.add(CookieManager(cookieJar));
  }

  int? extractSessionIndex(List<Map<String, dynamic>> sources) {
    int? sessionIndex;
    for (final source in sources) {
      sessionIndex = lookup<int>(
        source,
        (key) => key == "SESSION_INDEX",
      );
      if (sessionIndex != null) return sessionIndex;
    }

    return null;
  }

  String? extractVisitorData(List<Map<String, dynamic>> sources) {
    String? visitorData;
    for (final source in sources) {
      visitorData = lookup<String>(
        source,
        (key) => key == "VISITOR_DATA" || key == "visitorData",
      );
      if (visitorData != null) return visitorData;
    }

    return null;
  }

  String? extractDataSyncId(List<Map<String, dynamic>> sources) {
    String? dataSyncId;
    for (final source in sources) {
      dataSyncId = lookup<String>(
        source,
        (key) => key == "datasyncId",
      );
      if (dataSyncId != null) return dataSyncId;
    }

    return null;
  }

  Future<List<Cookie>> cookiesHeader(String url) async {
    await dio.get(url);

    return await cookieJar.loadForRequest(Uri.parse(url));
  }

  /// Gets, sets and updates the youtube preferences (PREF) cookie
  Future<void> initializePreferences() async {
    final cookies = await cookiesHeader(kYtBaseUrl);
    final prefCookie =
        cookies.firstWhereOrNull((cookie) => cookie.name == "PREF");

    var pref = <String, String>{};

    if (prefCookie != null) {
      // Parse query string
      pref = Uri.splitQueryString(prefCookie.value);
    }

    pref["hl"] = "en";
    pref["tz"] = "UTC";

    final urlEncodedPref = Uri(queryParameters: pref).query;
    // Update the cookie in the cookie jar
    await cookieJar.saveFromResponse(
      Uri.parse(kYtBaseUrl),
      [Cookie("PREF", urlEncodedPref)..domain = "youtube.com"],
    );
  }

  Future<void> initializeConsent() async {
    final cookies = await cookiesHeader(kYtBaseUrl);
    final consentCookie =
        cookies.firstWhereOrNull((cookie) => cookie.name == "__Secure-3PSID");

    if (consentCookie != null) return;

    final socsCookie =
        cookies.firstWhereOrNull((cookie) => cookie.name == "SOCS");
    if (socsCookie != null && socsCookie.value.startsWith("CAA")) {
      return;
    }

    await cookieJar.saveFromResponse(
      Uri.parse(kYtBaseUrl),
      [
        Cookie("SOCS", "CAI")
          ..secure = true
          ..domain = "youtube.com"
      ],
    );
  }

  Future<({Cookie? sapisid, Cookie? secure3papisid, Cookie? secure1papisid})>
      getSidCookies() async {
    final cookies = await cookiesHeader(kYtBaseUrl);

    final sapisid =
        cookies.firstWhereOrNull((cookie) => cookie.name == "SAPISID");
    final secure3papisid = cookies
        .firstWhereOrNull((cookie) => cookie.name == "__Secure-3PAPISID");
    final secure1papisid = cookies
        .firstWhereOrNull((cookie) => cookie.name == "__Secure-1PAPISID");

    return (
      sapisid: sapisid,
      secure3papisid: secure3papisid,
      secure1papisid: secure1papisid
    );
  }

  Future<void> initializeCookieAuth() async {
    final (:sapisid, :secure1papisid, :secure3papisid) = await getSidCookies();

    if (sapisid != null || secure1papisid != null || secure3papisid != null) {
      stdout.writeln("Found youtube account cookies");
    }
  }

  Map<String, dynamic>? extractYtCfg(self, video_id, [String? webpage]) {
    if (webpage == null) return null;
    final regex =
        RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;', multiLine: true);
    final match = regex.firstMatch(webpage)?.group(1);
    if (match == null) return null;

    return jsonDecode(match);
  }

  Set<String> getRequestedClients(
      String url, Map<String, dynamic> smuggledData) {
    var requestedClients = /* isAuthenticated ? kDefaultAuthClients : */
        kDefaultClients;

    // final allowedClients = innerTubeClients.keys
    //     .where((client) => !client.startsWith('_'))
    //     .sorted((a, b) {
    //   return (innerTubeClients[b]!['priority'] as int)
    //       .compareTo(innerTubeClients[a]['priority'] as int);
    // });

    return requestedClients.toSet();
  }

  String? extractPlayerUrl(List<Map<String, dynamic>> ytcfgs,
      [String? webpage]) {
    String? playerUrl;

    for (final ytcfg in ytcfgs) {
      final url = lookup<String>(
          ytcfg, (key) => key == "PLAYER_JS_URL" || key == "jsUrl");
      if (url != null) {
        playerUrl = url;
        break;
      }
    }

    if (playerUrl == null) return null;

    return Uri.parse(kYtBaseUrl).replace(path: playerUrl).toString();
  }

  Future<String?> downloadPlayerUrl(String videoId) async {
    final webreq = await dio.get(
      "https://www.youtube.com/iframe_api",
      options: Options(
        responseType: ResponseType.plain,
      ),
    );

    final webpageContent = webreq.data as String;

    final regex = RegExp(r"player\\?/([0-9a-fA-F]{8})\\?/", multiLine: true);

    final playerVersion = regex.firstMatch(webpageContent)?.group(1);

    if (playerVersion == null) return null;

    return 'https://www.youtube.com/s/player/$playerVersion/player_ias.vflset/en_US/base.js';
  }

  (String?, String?) parseDataSyncId(String dataSyncId) {
    final parts = dataSyncId.split("||");
    if (parts.length > 1) {
      return (parts.first, parts.last);
    } else {
      return (null, parts.first);
    }
  }

  String? extractDelegatedSessionId(List<Map<String, dynamic>> sources) {
    String? delegatedSid;
    for (final source in sources) {
      delegatedSid = lookup<String>(
        source,
        (key) => key == "DELEGATED_SESSION_ID",
      );
      if (delegatedSid != null) return delegatedSid;
    }

    if (delegatedSid != null) return delegatedSid;

    final dataSyncId = extractDataSyncId(sources);
    return parseDataSyncId(dataSyncId!).$1;
  }

  final playerInfoRegexps = [
    RegExp(r'/s/player/(?<id>[a-zA-Z0-9_-]{8,})/player'),
    RegExp(
      r'/(?<id>[a-zA-Z0-9_-]{8,})/player(?:_ias\.vflset(?:/[a-zA-Z]{2,3}_[a-zA-Z]{2,3})?|-plasma-ias-(?:phone|tablet)-[a-z]{2}_[A-Z]{2}\.vflset)/base\.js$',
    ),
    RegExp(r'\b(?<id>vfl[a-zA-Z0-9_-]+)\b.*?\.js$'),
  ];

  final playerCodeCache = <String, String>{};

  String? extractPlayerInfo(playerInfo) {
    for (final regex in playerInfoRegexps) {
      final match = regex.firstMatch(playerInfo);
      if (match != null) {
        return match.namedGroup("id")!;
      }
    }
  }

  Future<String?> loadPlayer(String videoId, String playerUrl) async {
    final playerId = extractPlayerInfo(playerUrl);

    if (playerId == null) return null;

    if (!playerCodeCache.containsKey(playerId)) {
      final codeRes = await dio.get(
        playerUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final code = codeRes.data as String?;
      if (code != null) {
        playerCodeCache[playerId] = code;
      }
    }

    return playerCodeCache[playerId];
  }

  Future<int?> extractSignatureTimestamp(
    String videoId,
    String playerUrl,
    Map<String, dynamic> ytCfg,
  ) async {
    var sts = ytCfg["STS"] as int?;
    if (sts != null) return sts;

    final code = await loadPlayer(videoId, playerUrl);

    if (code != null) {
      final regex =
          RegExp(r"(?:signatureTimestamp|sts)\s*:\s*(?<sts>[0-9]{5})");
      final match = (regex.firstMatch(code)?.namedGroup("sts"));

      if (match != null) {
        sts = int.tryParse(match);
      }
    }

    return sts;
  }

  T? ytCfgGetSafe<T>(
    Map<String, dynamic>? ytCfg,
    List<String> paths,
    String defaultClient,
  ) {
    ytCfg ??= innerTubeClients[defaultClient]!;

    return lookup<T>(ytCfg!, (key) => paths.contains(key));
  }

  String? extractClientVersion(
      Map<String, dynamic>? ytCfg, String defaultClient) {
    return ytCfgGetSafe<String>(
      ytCfg,
      ["INNERTUBE_CLIENT_VERSION", "clientVersion"],
      defaultClient,
    );
  }

  String makeSidAuthorization(
    String scheme,
    String? sid,
    String origin,
    Map<String, String>? additionalParts,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final hashParts = [];
    if (additionalParts != null && additionalParts.isNotEmpty) {
      hashParts.add(
        additionalParts.values.join(":"),
      );
    }

    hashParts.addAll([
      timestamp,
      sid,
      origin,
    ]);
    final sidHash = sha1.convert(utf8.encode(hashParts.join(" "))).toString();
    final parts = [timestamp, sidHash];

    if (additionalParts != null && additionalParts.isNotEmpty) {
      parts.add(additionalParts.values.join(""));
    }

    return "$scheme ${parts.join("_")}";
  }

  Future<String?> getSidAuthorizationHeader(
    String origin, {
    String? userSessionId,
  }) async {
    final authorizations = <String>[];
    final additionalParts = <String, String>{};

    if (userSessionId != null) {
      additionalParts["u"] = userSessionId;
    }

    final (:sapisid, :secure1papisid, :secure3papisid) = await getSidCookies();

    final map = {
      'SAPISIDHASH': sapisid,
      'SAPISID1PHASH': secure1papisid,
      'SAPISID3PHASH': secure3papisid,
    };

    for (final MapEntry(key: scheme, value: sid) in map.entries) {
      if (sid != null) {
        authorizations.add(
          makeSidAuthorization(
            scheme,
            sid.value,
            origin,
            additionalParts,
          ),
        );
      }
    }

    if (authorizations.isEmpty) return null;

    return authorizations.join(" ");
  }

  String? extractUserSessionId(List<Map<String, dynamic>> sources) {
    String? userSid;

    for (final source in sources) {
      userSid = lookup<String>(
        source,
        (key) => key == "USER_SESSION_ID",
      );
      if (userSid != null) return userSid;
    }

    final dataSyncId = extractDataSyncId(sources);
    return parseDataSyncId(dataSyncId!).$2;
  }

  Future<Map<String, dynamic>> generateCookieAuthHeaders({
    required String origin,
    Map<String, dynamic>? ytCfg,
    String? deletedSessionId,
    String? userSessionId,
    int? sessionIndex,
  }) async {
    final headers = <String, dynamic>{};
    if (ytCfg != null) {
      deletedSessionId ??= extractDelegatedSessionId([ytCfg]);

      if (deletedSessionId != null) {
        headers["X-Goog-PageId"] = deletedSessionId;
      }

      sessionIndex ??= extractSessionIndex([ytCfg]);

      if (deletedSessionId != null || sessionIndex != null) {
        headers["X-Goog-AuthUser"] = sessionIndex ?? 0;
      }

      final auth = await getSidAuthorizationHeader(
        origin,
        userSessionId: userSessionId ?? extractUserSessionId([ytCfg]),
      );

      if (auth != null) {
        headers["Authorization"] = auth;
        headers["X-Origin"] = origin;
      }

      if (lookup<bool>(ytCfg, (key) => key == "LOGGED_IN") == true) {
        headers['X-Youtube-Bootstrap-Logged-In'] = 'true';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> generateApiHeaders({
    required String defaultClient,
    Map<String, dynamic>? ytCfg,
    String? visitorData,
    int? sessionIndex,
    String? deletedSessionId,
    String? userSessionId,
  }) async {
    final origin =
        "https://${innerTubeClients[defaultClient]["INNERTUBE_HOST"]}";

    final headers = <String, String?>{
      'X-YouTube-Client-Name': ytCfgGetSafe<int>(
              ytCfg, ["INNERTUBE_CONTEXT_CLIENT_NAME"], defaultClient)
          ?.toString(),
      'X-YouTube-Client-Version': extractClientVersion(ytCfg, defaultClient),
      'Origin': origin,
      'X-Google-Visitor-Id':
          visitorData ?? extractVisitorData([if (ytCfg != null) ytCfg]),
      'User-Agent': ytCfgGetSafe<String>(ytCfg, ["userAgent"], defaultClient),
      ...(await generateCookieAuthHeaders(
        ytCfg: ytCfg,
        deletedSessionId: deletedSessionId,
        userSessionId: userSessionId,
        sessionIndex: sessionIndex,
        origin: origin,
      )),
    };

    return headers..removeWhere((key, value) => value == null);
  }

  final checkOkParams = {'contentCheckOk': true, 'racyCheckOk': true};

  Map<String, dynamic> generatePlayerContext(int? sts) {
    final context = <String, dynamic>{
      'html5Preference': 'HTML5_PREF_WANTS',
    };

    if (sts != null) {
      context['signatureTimestamp'] = sts;
    }

    return {
      'playbackContext': {
        'contentPlaybackContext': context,
      },
      ...checkOkParams,
    };
  }

  Future<Map<String, dynamic>> callApi({
    required String ep,
    required String videoId,
    required String defaultClient,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? query,
    String? hostname,
    Map<String, dynamic>? context,
  }) async {
    final data = context != null
        ? {"context": context}
        : extractContext(null, defaultClient);
    if (query != null) {
      data.addAll(query);
    }

    final realHeaders = await generateApiHeaders(defaultClient: defaultClient);
    realHeaders["content-type"] = "application/json";
    if (headers != null) {
      realHeaders.addAll(headers);
    }

    final uri =
        "https://${hostname ?? innerTubeClients[defaultClient]['INNERTUBE_HOST']}/youtubei/v1/$ep";

    final response = await dio.post(
      uri,
      data: data,
      options: Options(
        headers: realHeaders,
        responseType: ResponseType.json,
      ),
    );

    return response.data as Map<String, dynamic>;
  }

  Map<String, dynamic> extractContext(
    Map<String, dynamic>? ytCfg,
    String defaultClient,
  ) {
    final context = ytCfgGetSafe<Map>(
      ytCfg,
      ["INNERTUBE_CONTEXT"],
      defaultClient,
    );

    final clientContext = ytCfgGetSafe<Map>(
          context as Map<String, dynamic>?,
          ["client"],
          defaultClient,
        ) ??
        {};

    clientContext.addAll({
      "hl": "en",
      "timeZone": "UTC",
      "utcOffsetMinutes": 0,
    });

    return clientContext as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> extractResponse({
    required String itemId,
    required String ep,
    required Map<String, dynamic> query,
    required Map<String, dynamic> headers,
    required String defaultClient,
    String? hostname,
    Map<String, dynamic>? ytCfg,
    int maxRetires = 3,
  }) async {
    int retires = 0;
    while (retires < maxRetires) {
      try {
        final response = await callApi(
          ep: ep,
          defaultClient: defaultClient,
          headers: headers,
          query: query,
          videoId: itemId,
          hostname: hostname,
          context: extractContext(ytCfg, defaultClient),
        );

        return response;
      } catch (e) {
        if (e is! DioException ||
            e is! HttpException ||
            e is! SocketException) {
          return null;
        }

        if (e.response?.statusCode != 403 || e.response?.statusCode != 429) {
          retires++;
          continue;
        }
      }
    }
  }

  Future<Map<String, dynamic>?> extractPlayerResponse(
    String client,
    String videoId, {
    required Map<String, dynamic> masterYtCfg,
    Map<String, dynamic>? playerYtConfig,
    String? playerUrl,
    Map<String, dynamic>? initialPr,
    String? visitorData,
    String? dataSyncId,
    String? poToken,
  }) async {
    final (firstDataSyncId, secondDataSyncId) = parseDataSyncId(dataSyncId!);
    final delegatedSessionId = extractDelegatedSessionId(
      [masterYtCfg, initialPr, playerYtConfig].nonNulls.toList(),
    );
    final headers = await generateApiHeaders(
      ytCfg: playerYtConfig,
      defaultClient: client,
      visitorData: visitorData,
      sessionIndex: extractSessionIndex(
        [masterYtCfg, playerYtConfig].nonNulls.toList(),
      ),
      deletedSessionId: firstDataSyncId ?? delegatedSessionId,
      userSessionId: secondDataSyncId ?? delegatedSessionId,
    );

    final ytQuery = <String, dynamic>{
      "videoId": videoId,
    };

    // Skipping pp and PO assigning
    // TODO: Implement it if facing issues

    final sts = playerUrl != null
        ? await extractSignatureTimestamp(
            videoId,
            playerUrl,
            masterYtCfg,
          )
        : null;

    ytQuery.addAll(generatePlayerContext(sts));

    return await extractResponse(
      itemId: videoId,
      ep: "player",
      query: ytQuery,
      headers: headers,
      defaultClient: client,
    );
  }

  String? invalidPlayerResponse(Map<String, dynamic> pr, String videoId) {
    final prVideoId = lookup<String>(pr, (key) => key == "videoId");

    if (prVideoId != videoId) {
      return prVideoId;
    }

    return null;
  }

  Future<(List<Map<String, dynamic>>, String)> extractPlayerResponses(
    List<String> clients,
    String videoId,
    String? webpage,
    Map<String, dynamic> masterYtCfg,
  ) async {
    Map<String, dynamic>? initialPr;
    if (webpage != null) {
      final initialPrRegex = RegExp(
        r"(?:ytInitialPlayerResponse\s*=)\s*(?<json>\{(?:.+)\})\s*(?:)",
        multiLine: true,
      );

      final jsonString = initialPrRegex.firstMatch(webpage)?.namedGroup("json");
      if (jsonString != null) {
        initialPr = jsonDecode(jsonString);
      }
    }
    // PR = Player Response
    var prs = <Map<String, dynamic>>[];
    var deprioritizedPrs = <Map<String, dynamic>>[];

    clients = clients.toList().reversed.toList();

    var triedIframeFallback = false;
    String? playerUrl;
    var visitorData;
    var dataSyncId;
    final skippedClients = <String, String?>{};
    while (clients.isNotEmpty) {
      var deprioritizedPr = false;

      final (client, baseClient, variant) =
          splitInnerTubeClient(clients.removeLast());

      final playerYtConfig = client == 'web' ? masterYtCfg : null;
      playerUrl ??= extractPlayerUrl(
        [masterYtCfg, playerYtConfig].nonNulls.toList(),
        webpage,
      );
      final requireJsPlayer =
          innerTubeClients[client]["REQUIRE_JS_PLAYER"] ?? false;

      if (playerUrl == null && !triedIframeFallback && requireJsPlayer) {
        playerUrl = await downloadPlayerUrl(videoId);
        triedIframeFallback = true;
      }

      visitorData ??= extractVisitorData(
        [masterYtCfg, initialPr, playerYtConfig].nonNulls.toList(),
      );
      dataSyncId ??= extractDataSyncId(
        [masterYtCfg, initialPr, playerYtConfig].nonNulls.toList(),
      );

      // TODO: Implement experimental PO Token later
      final fetchPOTokenArgs = {
        'client': client,
        'visitor_data': visitorData,
        'video_id': videoId,
        'data_sync_id': /* isAuthenticated ? dataSyncId : */ null,
        'player_url': requireJsPlayer ? playerUrl : null,
        // 'session_index': self._extract_session_index(master_ytcfg, player_ytcfg),
        'ytcfg': playerYtConfig,
      };

      var pr = client == 'web' ? initialPr : null;
      try {
        pr ??= await extractPlayerResponse(
          client,
          videoId,
          masterYtCfg: playerYtConfig ?? masterYtCfg,
          playerYtConfig: playerYtConfig,
          playerUrl: playerUrl,
          initialPr: initialPr,
          visitorData: visitorData,
          dataSyncId: dataSyncId,
          poToken: null, // TODO: Implement PO Token later
        );
      } catch (e) {
        continue;
      }

      final prId = pr == null ? null : invalidPlayerResponse(pr, videoId);
      if (prId != null) {
        skippedClients[client] = prId;
      } else if (pr != null) {
        final sd = (lookup<Map>(
              pr,
              (key) => key == "streamingData",
            ) ??
            {}) as Map<String, dynamic>;

        sd[kStreamingDataClientName] = client;
        // TODO: When implementing PO Token
        // sd[kStreamingDataInitialPOToken] = gvs_po_token;
        final formats = lookup<List<Map>>(
          sd,
          (key) => key == "formats",
        );
        final adaptiveFormats = lookup<List<Map>>(
          sd,
          (key) => key == "adaptiveFormats",
        );

        for (final f in [...formats ?? [], ...adaptiveFormats ?? []]) {
          f[kStreamingDataClientName] = client;
          // TODO: When implementing PO Token
          // f[kStreamingDataInitialPOToken] = gvs_po_token;
        }

        if (deprioritizedPr) {
          // TODO: This will be ignored for no PO implementation
          deprioritizedPrs.add(pr);
        } else {
          prs.add(pr);
        }
      }
    }

    prs.addAll(deprioritizedPrs);

    if (skippedClients.isNotEmpty && prs.isEmpty) {
      throw Exception(
        "No valid player response found. "
        "Your IP is likely being blocked by YouTube",
      );
    } else if (prs.isEmpty) {
      throw Exception("Failed to extract any player response");
    }

    return (prs, playerUrl!);
  }

  Future<
      ({
        Map<String, dynamic> masterYtCfg,
        List<Map<String, dynamic>> playerResponses,
        String playerUrl,
        String? webpage,
      })> downloadPlayerResponses(
    String url,
    Map<String, dynamic> smuggledData,
    String videoId,
    String webpageUrl, {
    bool downloadWebpage = true,
  }) async {
    String? webpage;
    if (downloadWebpage) {
      final query = {'bpctr': '9999999999', 'has_verified': '1'};
      final webpageRes = await dio.get(
        webpageUrl,
        queryParameters: query,
        options: Options(
          responseType: ResponseType.plain,
        ),
      );

      webpage = webpageRes.data as String;
    }

    final masterYtCfg = extractYtCfg(videoId, webpage) ??
        innerTubeClients["web"] as Map<String, dynamic>;

    final (playerResponses, playerUrl) = await extractPlayerResponses(
      getRequestedClients(url, smuggledData).toList(),
      videoId,
      webpage,
      masterYtCfg,
    );

    return (
      webpage: webpage,
      masterYtCfg: masterYtCfg,
      playerResponses: playerResponses,
      playerUrl: playerUrl,
    );
  }

  Future<List<Map<String, dynamic>>> extractFormats(
    Map<String, dynamic>? streamingData,
    String videoId,
    String playerUrl,
    String? liveStatus,
    int? durationSeconds,
  ) async {
    const kChunkSize = 10 << 20;
    const kPreferredLangValue = 20;
    String? originalLanguage;
    final itags = <String, Set<int>>{};
    final streamIds = <(String, String?, bool?)>[];
    Map<String, String?> itagQualities = {};
    Map<int, String?> resQualities = {0: null};

    final q = qualities([
      /// Normally tiny is the smallest video-only formats. But
      /// audio-only formats with unknown quality may get tagged as tiny
      'tiny',
      'audio_quality_ultralow', 'audio_quality_low', 'audio_quality_medium',
      'audio_quality_high', // Audio only formats
      'small', 'medium', 'large', 'hd720', 'hd1080', 'hd1440', 'hd2160',
      'hd2880', 'highres',
    ]);

    final streamingFormats = [
      ...?lookup<List<Map>>(
        streamingData ?? {},
        (key) => key == "formats",
      ),
      ...?lookup<List<Map>>(
        streamingData ?? {},
        (key) => key == "adaptiveFormats",
      ),
    ].nonNulls.toList();

    List<Map<String, dynamic>> buildFragments(Map<String, dynamic> f) {
      final filesize = f['filesize'] as int;
      final uri = Uri.parse(f['url'] as String);
      final fragments = <Map<String, dynamic>>[];

      for (int start = 0; start < filesize; start += kChunkSize) {
        final end = math.min(start + kChunkSize - 1, filesize);
        fragments.add({
          'url': uri.replace(queryParameters: {'range': '$start-$end'})
        });
      }

      return fragments;
    }

    for (final fmt in streamingFormats) {
      if (fmt["targetDurationSec"] != null) {
        continue;
      }

      final itag = fmt["itag"]?.toString();
      final audioTrack = (fmt["audioTrack"] ?? {}) as Map<String, dynamic>;
      final streamId = (
        itag,
        audioTrack["id"] as String?,
        fmt["isDrc"] as bool?,
      );

      // if(!allFormats && streamIds.contains(streamId)) {
      //   continue;
      // }

      String? quality = fmt["quality"] as String?;
      final height = fmt["height"] as int?;
      if (quality case "tiny" || null) {
        quality = (fmt["audioQuality"] as String?)?.toLowerCase() ?? quality;
      }
      if (itag == "17") {
        quality = "tiny";
      }
      if (quality != null) {
        if (itag != null) {
          itagQualities[itag] = quality;
        }
        if (height != null) {
          resQualities[height] = quality;
        }
      }

      final displayName = audioTrack["displayName"] as String? ?? "";
      final isOriginal = displayName.toLowerCase().contains("original");
      final isDescriptive = displayName.toLowerCase().contains("descriptive");
      final isDefault = audioTrack["audioIsDefault"] as bool?;
      final languageCode =
          (audioTrack["id"] as String?)?.split(".").firstOrNull;

      if (languageCode != null &&
          (isOriginal || (isDefault == true && originalLanguage != null))) {
        originalLanguage = languageCode;
      }

      // FORMAT_STREAM_TYPE_OTF(otf=1) requires downloading the init fragment
      // (adding `&sq=0` to the URL) and parsing emsg box to determine the
      // number of fragment that would subsequently requested with (`&sq=N`)
      if (fmt['type'] == 'FORMAT_STREAM_TYPE_OTF') {
        continue;
      }

      var fmtUrl = fmt['url'] as String?;
      if (fmtUrl == null) {
        final sc = fmt["signatureCipher"] == null
            ? null
            : Uri.splitQueryString(fmt["signatureCipher"]);
        fmtUrl = Uri.tryParse(sc?["url"]?[0] ?? "").toString();
        final encryptedSig = sc?["s"]?[0];

        if ([sc, fmtUrl, playerUrl, encryptedSig].any((e) => e == null)) {
          continue;
        }
      }
    }

    return [];
  }

  Future<
      (
        Map<String, dynamic>? liveBroadcastDetails,
        String? liveStatus,
        Map<String, dynamic>? streamingData,
        List<Map<String, dynamic>> formats,
      )> listFormats(
    String videoId,
    Map<String, dynamic>? microformats,
    Map<String, dynamic>? videoDetails,
    List<Map<String, dynamic>> playerResponses,
    String playerUrl,
    int? durationSeconds,
  ) async {
    final liveBroadcastDetails = lookup<Map>(
      microformats ?? {},
      (key) => key == "liveBroadcastDetails",
    ) as Map<String, dynamic>?;

    bool? isLive = lookup<bool>(
      videoDetails ?? {},
      (key) => key == "isLive",
    );

    if (liveBroadcastDetails != null) {
      isLive ??= lookup<bool>(
        liveBroadcastDetails,
        (key) => key == "isLiveNow",
      );
    }

    final liveContent = lookup<bool>(
      videoDetails ?? {},
      (key) => key == "isLiveContent",
    );
    final isUpcoming = lookup<bool>(
      videoDetails ?? {},
      (key) => key == "isUpcoming",
    );
    final postLive = lookup<bool>(
      videoDetails ?? {},
      (key) => key == "isPostLiveDvr",
    );

    final liveStatus = switch ((isLive, isUpcoming, liveContent, postLive)) {
      (true, _, _, _) => "is_live",
      (_, true, _, _) => "is_upcoming",
      (_, _, true, _) => "was_live",
      (_, _, _, true) => "post_live",
      (false, _, _, _) || (_, _, false, _) => "not_live",
      _ => null
    };

    final streamingData = lookupAll<Map>(
      playerResponses,
      (key) => key == "streamingData",
    ) as Map<String, dynamic>?;

    final formats = await extractFormats(
      streamingData,
      videoId,
      playerUrl,
      liveStatus,
      durationSeconds,
    );

    if (formats.every((f) => f['has_drm'] == true)) {
      for (final f in formats) {
        f['has_drm'] = true;
      }
    }

    return (liveBroadcastDetails, liveStatus, streamingData, formats);
  }

  Future<void> extract(String sUrl) async {
    final (url, smuggledData) = unsmuggleUrl(sUrl);
    final videoId = Uri.parse(url).queryParameters["v"];

    if (videoId == null) {
      throw Exception("Invalid video URL");
    }

    final webpageUrl = "${kYtBaseUrl}watch?v=$videoId";

    final (:webpage, :masterYtCfg, :playerResponses, :playerUrl) =
        await downloadPlayerResponses(
      url,
      smuggledData ?? <String, dynamic>{},
      videoId,
      webpageUrl,
    );

    final microformats = lookupAll<Map>(
      playerResponses,
      (key) => key == "playerMicroformatRenderer",
    ) as Map<String, dynamic>?;

    final videoDetails = lookupAll<Map>(
      playerResponses,
      (key) => key == "videoDetails",
    ) as Map<String, dynamic>?;

    final durationSeconds = lookupAll<int>(
      [videoDetails, microformats].nonNulls.toList(),
      (key) => key == "lengthSeconds",
    );

    final x = listFormats(
      videoId,
      microformats,
      videoDetails,
      playerResponses,
      playerUrl,
      durationSeconds,
    );
  }
}
