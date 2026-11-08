import 'package:flutter/widgets.dart';

Widget pickedImage(
  String path, {
  required BoxFit fit,
  double? width,
  double? height,
  required ImageLoadingBuilder loadingBuilder,
  required ImageErrorWidgetBuilder errorBuilder,
}) =>
    Image.network(
      path,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
