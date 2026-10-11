 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../../privacy_policy/presentation/privacy_policy_page.dart';
import '../../terms_conditions/presentation/terms_conditions_page.dart';

class AuthPalette {
  static const green = Color(0xFF006633);
  static const yellow = Color(0xFFFFC900);
  static const darkGreen = Color(0xFF004D26);
  static const canvas = Color(0xFFF5F8F4);
}

class AuthEntrance extends StatefulWidget {
  const AuthEntrance({
    required this.child,
    super.key,
    this.slideUp = false,
    this.scale = false,
  });

  final Widget child;
  final bool slideUp;
  final bool scale;

  @override
  State<AuthEntrance> createState() => _AuthEntranceState();
}

class _AuthEntranceState extends State<AuthEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value = 1;
    } else {
      _controller
        ..stop()
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: widget.slideUp
                ? Offset(0, (1 - progress) * 24)
                : Offset.zero,
            child: Transform.scale(
              scale: widget.scale ? 0.92 + progress * 0.08 : 1,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AuthFormHeader extends StatelessWidget {
  const AuthFormHeader({
    required this.title,
    required this.backKey,
    super.key,
  });

  final String title;
  final Key backKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AuthPalette.green,
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: backKey,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              const SizedBox(
                width: 38,
                height: 38,
                child: Image(
                  image: AssetImage('assets/category_tiles/logo.png'),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'My',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'Shopzy',
                      style: TextStyle(color: AuthPalette.yellow),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              width: 42,
              height: 3,
              decoration: BoxDecoration(
                color: AuthPalette.yellow,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthCornerDecoration extends StatelessWidget {
  const AuthCornerDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _AuthCornerPainter(), size: Size.infinite),
    );
  }
}

class MyShopzyBrand extends StatelessWidget {
  const MyShopzyBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: compact ? 66 : 82,
          height: compact ? 66 : 82,
          child: Image.asset(
            key: const ValueKey('myshopzy-logo'),
            'assets/category_tiles/logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'MyShopzy logo',
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: compact ? 24 : 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1,
            ),
            children: const [
              TextSpan(
                text: 'My',
                style: TextStyle(color: AuthPalette.darkGreen),
              ),
              TextSpan(
                text: 'Shopzy',
                style: TextStyle(color: AuthPalette.yellow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'P R I V A T E   L I M I T E D',
          style: TextStyle(
            color: AuthPalette.darkGreen,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AuthCornerPainter extends CustomPainter {
  const _AuthCornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paleGreen = Paint()..color = const Color(0xFFE6F5E8);
    final paleYellow = Paint()..color = const Color(0xFFFFF7D6);
    final accent = Paint()
      ..color = AuthPalette.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final topLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.28, 0)
      ..cubicTo(
        size.width * 0.21,
        size.height * 0.07,
        size.width * 0.13,
        size.height * 0.06,
        0,
        size.height * 0.13,
      )
      ..close();
    canvas.drawPath(topLeft, paleGreen);

    final topAccent = Path()
      ..moveTo(0, size.height * 0.15)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.07,
        size.width * 0.22,
        size.height * 0.08,
        size.width * 0.30,
        0,
      );
    canvas.drawPath(topAccent, accent);

    final bottomRight = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.72, size.height)
      ..cubicTo(
        size.width * 0.80,
        size.height * 0.92,
        size.width * 0.88,
        size.height * 0.94,
        size.width,
        size.height * 0.86,
      )
      ..close();
    canvas.drawPath(bottomRight, paleYellow);

    final bottomAccent = Path()
      ..moveTo(size.width, size.height * 0.84)
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.91,
        size.width * 0.78,
        size.height * 0.92,
        size.width * 0.70,
        size.height,
      );
    canvas.drawPath(bottomAccent, accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AuthServiceCategories extends StatefulWidget {
  const AuthServiceCategories({super.key});

  @override
  State<AuthServiceCategories> createState() => _AuthServiceCategoriesState();
}

class _AuthServiceCategoriesState extends State<AuthServiceCategories>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  bool? _reduceMotion;

  static const _services = [
    ('Parcels', 'assets/category_tiles/auth_parcels.png'),
    ('Restaurants', 'assets/category_tiles/auth_restaurants.png'),
    ('Groceries', 'assets/category_tiles/auth_groceries.png'),
    ('Meat', 'assets/category_tiles/auth_meat.png'),
  ];

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _motionController
        ..stop()
        ..value = 1;
    } else {
      _motionController
        ..stop()
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _services.length; index++) ...[
          if (index > 0)
            Container(
              width: 1,
              height: 58,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              color: const Color(0xFFB7D9C2),
            ),
          Expanded(
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _motionController,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      _services[index].$2,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      semanticLabel: _services[index].$1,
                    ),
                  ),
                  builder: (context, child) {
                    final progress = CurvedAnimation(
                      parent: _motionController,
                      curve: Interval(
                        index * 0.1,
                        1,
                        curve: Curves.easeOutCubic,
                      ),
                    ).value;
                    final floatOffset = (1 - progress) * 7;
                    final scale = 0.94 + progress * 0.06;
                    return Transform.translate(
                      offset: Offset(
                        0,
                        _reduceMotion == true ? 0 : floatOffset,
                      ),
                      child: Transform.scale(
                        scale: _reduceMotion == true ? 1 : scale,
                        child: child,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  _services[index].$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AuthPalette.darkGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    this.fieldKey,
    this.validator,
    this.errorText,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final Key? fieldKey;
  final FormFieldValidator<String>? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  static String? validateIndianMobile(String? value) {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value ?? '')) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      validator: validator ?? validateIndianMobile,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Mobile number',
        hintText: '10-digit number',
        errorText: errorText,
        prefixIcon: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇮🇳', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                '+91',
                style: TextStyle(
                  color: AuthPalette.darkGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 9),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AuthPalette.darkGreen,
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 120),
        filled: true,
        fillColor: AppTheme.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD6DEDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD6DEDD), width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AuthPalette.green,
            width: 1.6,
          ),
        ),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
    );
  }
}

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.fieldKey,
    required this.toggleKey,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String label;
  final Key fieldKey;
  final Key toggleKey;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.password],
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: AppTheme.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD6DEDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Color(0xFFD6DEDD), width: 1.3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AuthPalette.green,
            width: 1.6,
          ),
        ),
        suffixIcon: IconButton(
          key: widget.toggleKey,
          tooltip: _obscureText ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscureText = !_obscureText),
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class AuthLegalLinks extends StatelessWidget {
  const AuthLegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        const Text(
          'By continuing, you agree to our',
          style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
        ),
        _LegalLink(
          label: 'Terms of Service',
          page: const TermsConditionsPage(),
        ),
        const Text(
          'and',
          style: TextStyle(color: AppTheme.secondaryText, fontSize: 12),
        ),
        _LegalLink(label: 'Privacy Policy', page: const PrivacyPolicyPage()),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.page});

  final String label;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (context) => page)),
      child: Text(
        label,
        style: const TextStyle(
          color: AuthPalette.green,
          fontSize: 12,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
