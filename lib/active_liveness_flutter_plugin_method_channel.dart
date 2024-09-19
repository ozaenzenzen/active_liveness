import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'active_liveness_flutter_plugin_platform_interface.dart';
import 'active_liveness_service.dart';

/// An implementation of [ActiveLivenessFlutterPluginPlatform] that uses method channels.
class MethodChannelActiveLivenessFlutterPlugin extends ActiveLivenessFlutterPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('active_liveness_flutter_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<ActionParam> run(List<CameraImage> cameraImages) async {
    return await ActiveLivenessService().run(cameraImages);
  }
}
