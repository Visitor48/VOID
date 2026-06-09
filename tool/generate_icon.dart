import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final bg = img.ColorRgb8(7, 7, 10);
  final accent = img.ColorRgb8(139, 92, 246);

  final image = img.Image(width: size, height: size);
  img.fill(image, color: bg);

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - size / 2;
      final dy = y - size / 2;
      final distance = math.sqrt(dx * dx + dy * dy);
      if (distance >= 210 && distance <= 250) {
        image.setPixel(x, y, accent);
      } else if (distance <= 36) {
        image.setPixel(x, y, accent);
      }
    }
  }

  final assetsDir = Directory('assets');
  if (!assetsDir.existsSync()) {
    assetsDir.createSync(recursive: true);
  }
  File('assets/app_icon.png').writeAsBytesSync(img.encodePng(image));
}
