/// Stub implementation for non-web platforms.
/// These functions are never called on mobile because the widget
/// that uses them only renders when kIsWeb == true.

String getWebUserAgent() => '';

bool isWebAndroid() => false;

bool isWebIOS() => false;

void triggerApkDownload() {}
