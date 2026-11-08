import 'package:flutter/material.dart';

Widget pickedImage(
  String path, {
  required BoxFit fit,
  double? width,
  double? height,
  required ImageLoadingBuilder loadingBuilder,
  required ImageErrorWidgetBuilder errorBuilder,
}) =>
    const Icon(Icons.broken_image_outlined);
