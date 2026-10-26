import 'package:flutter/material.dart';

import '../../../app/main_navigation_shell.dart';

class _C {
  static const green = Color(0xFF016034);
  static const greenDark = Color(0xFF01542A);
  static const yellow = Color(0xFFF8C800);
  static const ink = Color(0xFF1B1F23);
  static const muted = Color(0xFF6B7680);
}

/// First screen of the customer app: brand artwork + Login button.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<Offset> _entryOffset;
  bool _entryStarted = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entryOffset = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entryStarted) return;
    _entryStarted = true;
    _entryController.duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 400);
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _soon(BuildContext context, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: _C.greenDark,
      body: Column(
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: Image.asset(
                'assets/category_tiles/login_hero.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: _C.greenDark,
                  child: Center(
                    child: Text(
                      'MyShopzy',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -1),
            child: FadeTransition(
              opacity: _entryController,
              child: SlideTransition(
                position: _entryOffset,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 12 + bottom),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      const MainNavigationShell(),
                                ),
                              ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.green,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Browse catalog'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const _Muted('By continuing, you agree to our '),
                          _Link(
                            'Privacy Policy',
                            () => _soon(context, 'Privacy Policy'),
                          ),
                          const _Muted(' & '),
                          _Link(
                            'Terms of Use',
                            () => _soon(context, 'Terms of Use'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 14, height: 3, color: _C.yellow),
                          const SizedBox(width: 10),
                          const Text(
                            'Smart Shopping  •  Fast Delivery',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _C.green,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(width: 14, height: 3, color: _C.yellow),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 12.5, color: _C.muted));
}

class _Link extends StatelessWidget {
  const _Link(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        color: _C.ink,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
      ),
    ),
  );
}
