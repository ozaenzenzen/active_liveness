import 'package:camera/camera.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'active_liveness_flutter_plugin_method_channel.dart';
import 'active_liveness_service.dart';

abstract class ActiveLivenessFlutterPluginPlatform extends PlatformInterface {
  /// Constructs a ActiveLivenessFlutterPluginPlatform.
  ActiveLivenessFlutterPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static ActiveLivenessFlutterPluginPlatform _instance = MethodChannelActiveLivenessFlutterPlugin();

  /// The default instance of [ActiveLivenessFlutterPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelActiveLivenessFlutterPlugin].
  static ActiveLivenessFlutterPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ActiveLivenessFlutterPluginPlatform] when
  /// they register themselves.
  static set instance(ActiveLivenessFlutterPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<ActionParam> run(List<CameraImage> cameraImages) {
    throw UnimplementedError('run() has not been implemented.');
  }
}
