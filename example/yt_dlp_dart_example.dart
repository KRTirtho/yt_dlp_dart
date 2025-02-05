import 'package:yt_dlp_dart/yt_dlp_dart.dart';

void main() async {
  await YtDlp.instance.setBinaryLocation("yt-dlp");

  print(await YtDlp.instance.version());
  print(await YtDlp.instance.listExtractors());
  print(
    await YtDlp.instance.extractInfo(
      "https://www.youtube.com/watch?v=A9hcJgtnm6Q",
    ),
  );
}
