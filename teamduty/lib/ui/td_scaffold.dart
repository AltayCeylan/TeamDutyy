import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TDScaffold extends StatelessWidget {
  const TDScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Eğer true yapılırsa body AppBar arkasına girer.
  /// Bu durumda otomatik üst padding veriyoruz.
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final appBarH = appBar?.preferredSize.height ?? kToolbarHeight;

    // extendBodyBehindAppBar true ise body AppBar + statusbar altına kaymasın
    final Widget safeBody = extendBodyBehindAppBar
        ? Padding(
            padding: EdgeInsets.only(top: media.padding.top + appBarH),
            child: body,
          )
        : body;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          // ✅ FULL background (status bar + bottom area dahil)
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF1A1A2E),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // dekoratif “premium” blur halkalar
                  Positioned(
                    left: -120,
                    top: -140,
                    child: _Glow(size: 320, opacity: 0.20),
                  ),
                  Positioned(
                    right: -160,
                    top: 80,
                    child: _Glow(size: 380, opacity: 0.18),
                  ),
                  Positioned(
                    left: 40,
                    bottom: -160,
                    child: _Glow(size: 420, opacity: 0.16),
                  ),
                ],
              ),
            ),
          ),

          // ✅ Actual page
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            appBar: appBar,
            body: safeBody,
            bottomNavigationBar: bottomNavigationBar,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.deepPurpleAccent.withOpacity(0.45),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
