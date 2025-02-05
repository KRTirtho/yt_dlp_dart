int Function(String index) qualities(List<String> quality_ids) {
  /// Get a numeric quality value out of a list of possible values
  int q(String qid) {
    return quality_ids.indexOf(qid);
  }

  return q;
}

(String, String, String?) splitInnerTubeClient(String clientName) {
  // Split by the last dot (.) to separate variant and base
  List<String> parts = clientName.split('.');
  String variant = parts.length > 1
      ? parts.sublist(0, parts.length - 1).join('.')
      : clientName;
  String base = parts.last;

  // If there is a base part, return variant, base, and variant again
  if (base.isNotEmpty) {
    return (variant, base, variant);
  }

  // Otherwise, split by the first underscore (_)
  parts = clientName.split('_');
  base = parts.first;
  String? newVariant = parts.length > 1 ? parts.sublist(1).join('_') : null;

  return (clientName, base, newVariant);
}

Map<String, dynamic> buildInnerTubeClients() {
  const innerTubeClients = <String, dynamic>{
    'web': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20241126.01.00',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 1,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'SUPPORTS_COOKIES': true,
    },
    // Safari UA returns pre-merged video+audio 144p/240p/360p/720p/1080p HLS formats
    'web_safari': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20241126.01.00',
          'userAgent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 1,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'SUPPORTS_COOKIES': true,
    },
    'web_embedded': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'WEB_EMBEDDED_PLAYER',
          'clientVersion': '1.20241201.00.00',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 56,
      'SUPPORTS_COOKIES': true,
    },
    'web_music': {
      'INNERTUBE_HOST': 'music.youtube.com',
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'WEB_REMIX',
          'clientVersion': '1.20241127.01.00',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 67,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'SUPPORTS_COOKIES': true,
    },
    // This client now requires sign-in for every video
    'web_creator': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'WEB_CREATOR',
          'clientVersion': '1.20241203.01.00',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 62,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'REQUIRE_AUTH': true,
      'SUPPORTS_COOKIES': true,
    },
    'android': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '19.44.38',
          'androidSdkVersion': 30,
          'userAgent':
              'com.google.android.youtube/19.44.38 (Linux; U; Android 11) gzip',
          'osName': 'Android',
          'osVersion': '11',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 3,
      'REQUIRE_JS_PLAYER': false,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
    },
    // This client now requires sign-in for every video
    'android_music': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'ANDROID_MUSIC',
          'clientVersion': '7.27.52',
          'androidSdkVersion': 30,
          'userAgent':
              'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 11) gzip',
          'osName': 'Android',
          'osVersion': '11',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 21,
      'REQUIRE_JS_PLAYER': false,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'REQUIRE_AUTH': true,
    },
    // This client now requires sign-in for every video
    'android_creator': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'ANDROID_CREATOR',
          'clientVersion': '24.45.100',
          'androidSdkVersion': 30,
          'userAgent':
              'com.google.android.apps.youtube.creator/24.45.100 (Linux; U; Android 11) gzip',
          'osName': 'Android',
          'osVersion': '11',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 14,
      'REQUIRE_JS_PLAYER': false,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'REQUIRE_AUTH': true,
    },
    // YouTube Kids videos aren't returned on this client for some reason
    'android_vr': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'ANDROID_VR',
          'clientVersion': '1.60.19',
          'deviceMake': 'Oculus',
          'deviceModel': 'Quest 3',
          'androidSdkVersion': 32,
          'userAgent':
              'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
          'osName': 'Android',
          'osVersion': '12L',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 28,
      'REQUIRE_JS_PLAYER': false,
    },
    // iOS clients have HLS live streams. Setting device model to get 60fps formats.
    // See: https://github.com/TeamNewPipe/NewPipeExtractor/issues/680//issuecomment-1002724558
    'ios': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'IOS',
          'clientVersion': '20.03.02',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'userAgent':
              'com.google.ios.youtube/20.03.02 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X;)',
          'osName': 'iPhone',
          'osVersion': '18.2.1.22C161',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 5,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'REQUIRE_JS_PLAYER': false,
    },
    // This client now requires sign-in for every video
    'ios_music': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'IOS_MUSIC',
          'clientVersion': '7.27.0',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'userAgent':
              'com.google.ios.youtubemusic/7.27.0 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
          'osName': 'iPhone',
          'osVersion': '18.1.0.22B83',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 26,
      'REQUIRE_JS_PLAYER': false,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'REQUIRE_AUTH': true,
    },
    // This client now requires sign-in for every video
    'ios_creator': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'IOS_CREATOR',
          'clientVersion': '24.45.100',
          'deviceMake': 'Apple',
          'deviceModel': 'iPhone16,2',
          'userAgent':
              'com.google.ios.ytcreator/24.45.100 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)',
          'osName': 'iPhone',
          'osVersion': '18.1.0.22B83',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 15,
      'REQUIRE_JS_PLAYER': false,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'REQUIRE_AUTH': true,
    },
    // mweb has 'ultralow' formats
    // See: https://github.com/yt-dlp/yt-dlp/pull/557
    'mweb': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'MWEB',
          'clientVersion': '2.20241202.07.00',
          // mweb previously did not require PO Token with this UA
          'userAgent':
              'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1,gzip(gfe)',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 2,
      'PO_TOKEN_REQUIRED_CONTEXTS': ['gvs'],
      'SUPPORTS_COOKIES': true,
    },
    'tv': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'TVHTML5',
          'clientVersion': '7.20250120.19.00',
          'userAgent': 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 7,
      'SUPPORTS_COOKIES': true,
    },
    // This client now requires sign-in for every video
    // It was previously an age-gate workaround for videos that were `playable_in_embed`
    // It may still be useful if signed into an EU account that is not age-verified
    'tv_embedded': {
      'INNERTUBE_CONTEXT': {
        'client': {
          'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          'clientVersion': '2.0',
        },
      },
      'INNERTUBE_CONTEXT_CLIENT_NAME': 85,
      'REQUIRE_AUTH': true,
      'SUPPORTS_COOKIES': true,
    },
  };

  final thirdParty = {
    'embedUrl': 'https://www.youtube.com/', // Can be any valid URL
  };
  final baseClients = ['ios', 'web', 'tv', 'mweb', 'android'];
  final priority = qualities(baseClients.reversed.toList());

  for (final MapEntry(key: client, value: ytCfg) in innerTubeClients.entries) {
    ytCfg.putIfAbsent('INNERTUBE_HOST', () => 'www.youtube.com');
    ytCfg.putIfAbsent('REQUIRE_JS_PLAYER', () => true);
    ytCfg.putIfAbsent('PO_TOKEN_REQUIRED_CONTEXTS', () => []);
    ytCfg.putIfAbsent('REQUIRE_AUTH', () => false);
    ytCfg.putIfAbsent('SUPPORTS_COOKIES', () => false);
    ytCfg.putIfAbsent('PLAYER_PARAMS', () => null);
    ytCfg['INNERTUBE_CONTEXT']?['client'].putIfAbsent('hl', 'en');

    var (_, base_client, variant) = splitInnerTubeClient(client);
    ytCfg['priority'] = 10 * priority(base_client);

    if (variant == 'embedded') {
      ytCfg['INNERTUBE_CONTEXT']['thirdParty'] = thirdParty;
      ytCfg['priority'] -= 2;
    } else if (variant != null) {
      ytCfg['priority'] -= 3;
    }
  }

  return innerTubeClients;
}
