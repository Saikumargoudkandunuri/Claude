// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String getWebUserAgent() => html.window.navigator.userAgent.toLowerCase();

bool isWebAndroid() => getWebUserAgent().contains('android');

bool isWebIOS() {
  final ua = getWebUserAgent();
  return ua.contains('iphone') || ua.contains('ipad');
}

void triggerApkDownload() {
  html.AnchorElement(href: 'https://client.metalandmore.in/app-release.apk')
    ..setAttribute('download', 'MetalMore.apk')
    ..click();
}
