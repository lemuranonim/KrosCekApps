import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Restarts the Android process so a downloaded Shorebird patch is loaded.
///
/// Older binaries do not contain the native method channel yet. In that case
/// the app is closed as a safe fallback and the patch is applied when the user
/// opens KC again.
class AppRestartService {
  const AppRestartService();

  static const MethodChannel _channel = MethodChannel(
    'com.example.kroscek/app_control',
  );

  Future<void> restart() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final scheduled =
            await _channel.invokeMethod<bool>('restartApp') ?? false;
        if (scheduled) return;
      } on MissingPluginException {
        // The current binary predates the native restart channel.
      } on PlatformException {
        // Fall back to closing the app. The patch is still safely downloaded.
      }
    }

    await SystemNavigator.pop(animated: true);
  }
}
