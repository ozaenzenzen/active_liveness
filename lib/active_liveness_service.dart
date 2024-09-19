import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

typedef InputType = List<List<List<List<List<double>>>>>;

typedef OutputType = List<List<double>>;

class ActiveLivenessService {

  Future<ActionParam> run(List<CameraImage> cameraImages) async {
    Interpreter? tflite = await _getInterpreter();
    if (tflite != null) {
      OutputType output = List.generate(1, (_) => List.filled(5, 0.0));
      InputType input = await _getAnalyzedAction(cameraImages);
      tflite.run(input, output);
      int detectedAction = _getActionDetection(output[0]);
      String nameAction = _getActionName(detectedAction);
      String outputAction = _getActionOutputString(output);
      return ActionParam(detectedAction, nameAction, outputAction);
    } else {
      int detectedAction = 4;
      String nameAction = _getActionName(detectedAction);
      String outputAction = "[]";
      return ActionParam(detectedAction, nameAction, outputAction);
    }
  }


  Future<Interpreter?> _getInterpreter() async {
    try {
      Interpreter interpreter = await Interpreter.fromAsset('active_liveness_flutter_plugin/assets/tflite_active_liveness_no_lstm_v3.tflite');
      return interpreter;
    } catch (e) {
      return null;
    }
  }

  Future<InputType> _getAnalyzedAction(List<CameraImage> cameraImages) async {
    InputType input = List.generate(
        1, (_) => List.generate(
      10, (_) => List.generate(
      112, (_) => List.generate(
      112, (_) => List.filled(3, 0.0),
    ),
    ),
    )
    );
    List<CameraImage> frames = _getMedianAction(cameraImages, 10);
    for (int i = 0; i < frames.length; ++i) {
      img.Image? manipulateBitmap = await _convertToImage(frames[i]);
      for (int y = 0; y < 112; ++y) {
        for (int x = 0; x < 112; ++x) {
          int pixel = manipulateBitmap!.getPixel(x, y);
          input[0][i][y][x][0] = img.getRed(pixel) / 255.0;
          input[0][i][y][x][1] = img.getGreen(pixel) / 255.0;
          input[0][i][y][x][2] = img.getBlue(pixel) / 255.0;
        }
      }
    }
    return input;
  }

  List<CameraImage> _getMedianAction(List<CameraImage> frames, int xFrame) {
    List<CameraImage> lists = <CameraImage>[];
    int totalFrames = frames.length;
    double step = totalFrames / xFrame;
    for (int i = 0; i < xFrame; i++) {
      int stepRound = (step * i).round();
      int tFrames = totalFrames - 1;
      int indexMin = min(stepRound, tFrames);
      CameraImage image = frames[indexMin];
      lists.add(image);
    }
    return lists;
  }


  int _getActionDetection(List<double> array) {
    int maxIdx = 0;
    double maxVal = array[0];
    for (int i = 0; i < array.length; ++i) {
      if (array[i] > maxVal) {
        maxVal = array[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  String _getActionName(int detectedAction) {
    List<String> actionListName = <String>[
      "Open Your Mouth",        // 0
      "Close Your Eyes",        // 1
      "Bow Your Head",          // 2
      "Turn Your Head",         // 3
      "No Action Detected",     // 4
    ];
    return actionListName[detectedAction];
  }

  String _getActionOutputString(dynamic list) {
    if (list is List) {
      return '[${list.map((e) => _getActionOutputString(e)).join(', ')}]';
    }
    return list.toString();
  }


  static Future<img.Image?> _convertToImage(CameraImage item) async {
    switch(item.format.group) {
      case ImageFormatGroup.yuv420:
        img.Image image = await compute(_convertYUV420ToImage, item);
        img.Image rotatedImage = img.copyRotate(image, -90);
        img.Image flippedImage = img.flip(rotatedImage, img.Flip.horizontal);
        img.Image croppedCenterImage = _cropSquareCenter(flippedImage);
        img.Image resizedImage = img.copyResize(croppedCenterImage, width: 112, height: 112);
        return resizedImage;
      case ImageFormatGroup.nv21:
        img.Image image = await compute(_convertNV21ToImage, item);
        img.Image croppedCenterImage = _cropSquareCenter(image);
        img.Image resizedImage = img.copyResize(croppedCenterImage, width: 112, height: 112);
        return resizedImage;
      case ImageFormatGroup.bgra8888:
        img.Image image = await compute(_convertBGRA8888ToImage, item);
        img.Image croppedCenterImage = _cropSquareCenter(image);
        img.Image resizedImage = img.copyResize(croppedCenterImage, width: 112, height: 112);
        return resizedImage;
      default:
        return null;
    }
  }

  static img.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int? uvPixelStride = cameraImage.planes[1].bytesPerPixel;
    var image = img.Image(width, height);
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex = uvPixelStride! * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int bytesPerRowY = cameraImage.planes[0].bytesPerRow;
        final int index = y * bytesPerRowY + x;
        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return image;
  }

  static img.Image _convertNV21ToImage(CameraImage cameraImage) {
    final width = cameraImage.width.toInt();
    final height = cameraImage.height.toInt();
    Uint8List yuv420sp = cameraImage.planes[0].bytes;

    final outImg = img.Image(height, width);
    final int frameSize = width * height;

    for (int j = 0, yp = 0; j < height; j++) {
      int uvp = frameSize + (j >> 1) * width, u = 0, v = 0;
      for (int i = 0; i < width; i++, yp++) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;
        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }
        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        if (r < 0) {
          r = 0;
        }
        else if (r > 262143) {
          r = 262143;
        }
        if (g < 0) {
          g = 0;
        }
        else if (g > 262143) {
          g = 262143;
        }
        if (b < 0) {
          b = 0;
        }
        else if (b > 262143) {
          b = 262143;
        }
        outImg.setPixelRgba(j, width - i - 1, ((r << 6) & 0xff0000) >> 16,((g >> 2) & 0xff00) >> 8, (b >> 10) & 0xff);
      }
    }
    return outImg;
  }

  static img.Image _convertBGRA8888ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final img.Image image = img.Image(width, height);

    final Uint8List bytes = cameraImage.planes[0].bytes;

    int index = 0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int b = bytes[index++] & 0xFF;
        final int g = bytes[index++] & 0xFF;
        final int r = bytes[index++] & 0xFF;
        final int a = bytes[index++] & 0xFF;
        image.setPixel(x, y, img.getColor(r, g, b, a));
      }
    }

    return image;
  }

  static img.Image _cropSquareCenter(img.Image image) {
    int size = image.width < image.height ? image.width : image.height;
    int xOffset = (image.width - size) ~/ 2;
    int yOffset = (image.height - size) ~/ 2;
    return img.copyCrop(image, xOffset, yOffset, size, size);
  }

}

class ActionValue {
  String name;
  String detection;

  ActionValue({required this.name, required this.detection});
}

class ActionParam {
  final int detected;
  final String name;
  final String output;

  ActionParam(this.detected, this.name, this.output);
}