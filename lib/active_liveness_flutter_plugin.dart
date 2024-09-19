import 'package:camera/camera.dart';
import 'active_liveness_flutter_plugin_platform_interface.dart';
import 'active_liveness_service.dart';

class ActiveLivenessFlutterPlugin {
  Future<String?> getPlatformVersion() {
    return ActiveLivenessFlutterPluginPlatform.instance.getPlatformVersion();
  }
  Future<ActionParam> run(List<CameraImage> cameraImages) {
    return ActiveLivenessFlutterPluginPlatform.instance.run(cameraImages);
  }
}
