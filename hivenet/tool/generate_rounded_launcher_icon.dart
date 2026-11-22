import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Creates a transparent rounded-corner version of newLogo2 for launcher use.
/// Keeping this deterministic avoids altering the supplied HiveNet artwork.
void main() {
  final input = File('assets/newLogo2.jpeg');
  final output = File('assets/newLogo2_rounded.png');
  final source = img.decodeImage(input.readAsBytesSync());
  if (source == null) {
    throw StateError('Could not decode ${input.path}.');
  }

  final result = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 4,
  );
  final radius = source.width * .13;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final pixel = source.getPixel(x, y);
      final closestX = x < radius
          ? radius
          : x > source.width - radius - 1
          ? source.width - radius - 1
          : x.toDouble();
      final closestY = y < radius
          ? radius
          : y > source.height - radius - 1
          ? source.height - radius - 1
          : y.toDouble();
      final distance = math.sqrt(
        math.pow(x - closestX, 2) + math.pow(y - closestY, 2),
      );
      final coverage = (radius + .5 - distance).clamp(0.0, 1.0);
      result.setPixelRgba(
        x,
        y,
        pixel.r,
        pixel.g,
        pixel.b,
        (pixel.a * coverage).round(),
      );
    }
  }

  output.writeAsBytesSync(img.encodePng(result));
  stdout.writeln('Generated ${output.path}.');
}
