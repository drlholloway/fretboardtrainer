import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Night sky behind every splash; the native launch screens use it too, so
/// the handoff from the platform splash is seamless.
const splashSky = Color(0xFF161018);
const _ink = Color(0xFFF2E8D5);

/// One launch scene, drawn by `packaging/splash/make_splash.py`.
class Sighting {
  const Sighting(this.asset, this.cryptid, this.instrument, this.place);

  final String asset;
  final String cryptid;
  final String instrument;
  final String place;
}

const sightings = [
  Sighting(
    'mothman',
    'Mothman',
    'lead guitar',
    'Point Pleasant, West Virginia',
  ),
  Sighting('bigfoot', 'Bigfoot', 'bass', 'Bluff Creek, California'),
  Sighting('nessie', 'Nessie', 'her own neck', 'Loch Ness, Scotland'),
  Sighting(
    'jersey_devil',
    'The Jersey Devil',
    'banjo',
    'Pine Barrens, New Jersey',
  ),
  Sighting('jackalope', 'The Jackalope', 'ukulele', 'Douglas, Wyoming'),
  Sighting(
    'chupacabra',
    'El Chupacabra',
    'acoustic guitar',
    'Canóvanas, Puerto Rico',
  ),
];

const _lastKey = 'splash.last';

/// Picks the launch sighting at random, never the one shown last time, and
/// remembers it for the next launch.
Future<Sighting> nextSighting([Random? random]) async {
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getString(_lastKey);
  final pool = [
    for (final s in sightings)
      if (s.asset != last) s,
  ];
  final pick = pool[(random ?? Random()).nextInt(pool.length)];
  await prefs.setString(_lastKey, pick.asset);
  return pick;
}

/// Full-screen scene with the wordmark above and the sighting report below.
class SplashView extends StatelessWidget {
  const SplashView({super.key, required this.sighting});

  final Sighting sighting;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: splashSky,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/splash/${sighting.asset}.png',
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 250),
                    child: child,
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Column(
                children: [
                  Text(
                    'FRETMAN',
                    style: text.displaySmall?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                    ),
                  ),
                  Text(
                    'Fretboard Trainer',
                    style: text.titleMedium?.copyWith(
                      color: _ink.withValues(alpha: 0.7),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${sighting.cryptid} on ${sighting.instrument}',
                    textAlign: TextAlign.center,
                    style: text.titleLarge?.copyWith(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sighted near ${sighting.place}',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: _ink.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [sighting] over the app at launch, then fades it out. A tap skips it.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.sighting, required this.child});

  final Sighting sighting;
  final Widget child;

  static const hold = Duration(milliseconds: 2200);
  static const fade = Duration(milliseconds: 400);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  Timer? _timer;
  bool _fading = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashGate.hold, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _timer?.cancel();
    if (!_fading) setState(() => _fading = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_gone)
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismiss,
              child: AnimatedOpacity(
                opacity: _fading ? 0 : 1,
                duration: SplashGate.fade,
                onEnd: () => setState(() => _gone = true),
                child: SplashView(sighting: widget.sighting),
              ),
            ),
          ),
      ],
    );
  }
}
