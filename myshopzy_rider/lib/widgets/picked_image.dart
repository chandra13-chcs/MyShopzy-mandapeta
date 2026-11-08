import 'package:flutter/material.dart';
import '../constants/translations.dart';
import 'picked_image_stub.dart'
    if (dart.library.io) 'picked_image_io.dart'
    if (dart.library.html) 'picked_image_web.dart' as platform;

class PickedImage extends StatelessWidget {
  const PickedImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.radius = 8,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: platform.pickedImage(
          path,
          fit: fit,
          width: width,
          height: height,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: width,
              height: height,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: width,
            height: height,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined),
                  Text(
                    T.t('photo_not_available'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
