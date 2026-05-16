import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

class WatermarkUtil {
  static Future<File> addWatermark({
    required String imagePath,
    required String bridgeName,
    required String bridgeId,
    required String element,
    required String location,
    required String attribute,
    required String defectType,
    required String severity,
    required double latitude,
    required double longitude,
  }) async {
    final imageFile = File(imagePath);
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) return imageFile;

    // Standardize photo size for consistent watermark (e.g., 1280px width)
    if (image.width > 1280) {
      image = img.copyResize(image, width: 1280);
    }

    final date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final infoLines = [
      'Bridge Name: $bridgeName',
      'Br. ID: $bridgeId',
      'Bridge Element: $element',
      'Location: $location',
      'Bridge Attribute: $attribute',
      'Type of Damage: $defectType',
      'Severity of Defects: $severity',
      'Date: $date',
      'Geotag: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
    ];

    // Calculate box dimensions based on content
    // Font arial24 is approx 24px high + 10px spacing
    final lineHeight = 34;
    final boxHeight = (infoLines.length * lineHeight) + 20;
    final boxWidth = 600;

    // Draw a semi-transparent background box at bottom-left
    img.fillRect(
      image,
      x1: 20,
      y1: image.height - boxHeight - 20,
      x2: 20 + boxWidth,
      y2: image.height - 20,
      color: img.ColorRgba8(0, 0, 0, 180), // Slightly darker for better contrast
    );

    // Draw text lines
    int yOffset = image.height - boxHeight;
    for (var line in infoLines) {
      img.drawString(
        image,
        line,
        font: img.arial24,
        x: 35,
        y: yOffset,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      yOffset += lineHeight;
    }

    final watermarkedFile = File(imagePath.replaceAll('.jpg', '_wm.jpg'));
    await watermarkedFile.writeAsBytes(img.encodeJpg(image, quality: 85));
    return watermarkedFile;
  }
}
