import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fretboard_theory/fretboard_theory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  const Settings({
    this.kind = InstrumentKind.guitar,
    this.guitarStrings = 6,
    this.bassStrings = 4,
    this.tuningId,
    this.accidentals = Accidentals.sharps,
    this.leftHanded = false,
    this.themeMode = 'system',
    this.unlockAll = false,
    this.drillModes = const {DrillMode.fretToNote, DrillMode.noteToFret},
    this.drillMaxFret = 12,
    this.drillNaturalsOnly = false,
    this.drillStrings = const {},
    this.drillCategories = const {
      ChordCategory.open,
      ChordCategory.power,
      ChordCategory.barre,
    },
    this.drillCount = 10,
  });

  final InstrumentKind kind;
  final int guitarStrings;
  final int bassStrings;

  /// Chosen tuning preset id; null or a preset for another instrument means
  /// standard tuning.
  final String? tuningId;
  final Accidentals accidentals;
  final bool leftHanded;
  final String themeMode; // system | light | dark

  /// Let the learner open any lesson without finishing the previous one.
  final bool unlockAll;

  // Remembered free-drill options.
  final Set<DrillMode> drillModes;
  final int drillMaxFret;
  final bool drillNaturalsOnly;

  /// Empty means every string.
  final Set<int> drillStrings;
  final Set<ChordCategory> drillCategories;

  /// 0 means endless.
  final int drillCount;

  int get stringCount =>
      kind == InstrumentKind.guitar ? guitarStrings : bassStrings;

  Tuning get tuning {
    final presets = Tuning.presets(kind, stringCount);
    for (final t in presets) {
      if (t.id == tuningId) return t;
    }
    return presets.first;
  }

  Instrument get instrument => Instrument(kind: kind, tuning: tuning);

  Settings copyWith({
    InstrumentKind? kind,
    int? guitarStrings,
    int? bassStrings,
    String? tuningId,
    bool clearTuning = false,
    Accidentals? accidentals,
    bool? leftHanded,
    String? themeMode,
    bool? unlockAll,
    Set<DrillMode>? drillModes,
    int? drillMaxFret,
    bool? drillNaturalsOnly,
    Set<int>? drillStrings,
    Set<ChordCategory>? drillCategories,
    int? drillCount,
  }) => Settings(
    kind: kind ?? this.kind,
    guitarStrings: guitarStrings ?? this.guitarStrings,
    bassStrings: bassStrings ?? this.bassStrings,
    tuningId: clearTuning ? null : (tuningId ?? this.tuningId),
    accidentals: accidentals ?? this.accidentals,
    leftHanded: leftHanded ?? this.leftHanded,
    themeMode: themeMode ?? this.themeMode,
    unlockAll: unlockAll ?? this.unlockAll,
    drillModes: drillModes ?? this.drillModes,
    drillMaxFret: drillMaxFret ?? this.drillMaxFret,
    drillNaturalsOnly: drillNaturalsOnly ?? this.drillNaturalsOnly,
    drillStrings: drillStrings ?? this.drillStrings,
    drillCategories: drillCategories ?? this.drillCategories,
    drillCount: drillCount ?? this.drillCount,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  SharedPreferences? _prefs;

  @override
  Settings build() {
    _load();
    return const Settings();
  }

  Future<void> _load() async {
    final p = _prefs = await SharedPreferences.getInstance();
    state = Settings(
      kind: InstrumentKind.values.byName(p.getString('kind') ?? 'guitar'),
      guitarStrings: p.getInt('guitarStrings') ?? 6,
      bassStrings: p.getInt('bassStrings') ?? 4,
      tuningId: p.getString('tuningId'),
      accidentals: Accidentals.values.byName(
        p.getString('accidentals') ?? 'sharps',
      ),
      leftHanded: p.getBool('leftHanded') ?? false,
      themeMode: p.getString('themeMode') ?? 'system',
      unlockAll: p.getBool('unlockAll') ?? false,
      drillModes: {
        for (final m
            in p.getStringList('drillModes') ??
                const ['fretToNote', 'noteToFret'])
          DrillMode.values.byName(m),
      },
      drillMaxFret: p.getInt('drillMaxFret') ?? 12,
      drillNaturalsOnly: p.getBool('drillNaturalsOnly') ?? false,
      drillStrings: {
        for (final s in p.getStringList('drillStrings') ?? const <String>[])
          int.parse(s),
      },
      drillCategories: {
        for (final c
            in p.getStringList('drillCategories') ??
                const ['open', 'power', 'barre'])
          ChordCategory.values.byName(c),
      },
      drillCount: p.getInt('drillCount') ?? 10,
    );
  }

  Future<void> update(Settings s) async {
    state = s;
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString('kind', s.kind.name);
    await p.setInt('guitarStrings', s.guitarStrings);
    await p.setInt('bassStrings', s.bassStrings);
    if (s.tuningId == null) {
      await p.remove('tuningId');
    } else {
      await p.setString('tuningId', s.tuningId!);
    }
    await p.setString('accidentals', s.accidentals.name);
    await p.setBool('leftHanded', s.leftHanded);
    await p.setString('themeMode', s.themeMode);
    await p.setBool('unlockAll', s.unlockAll);
    await p.setStringList('drillModes', [for (final m in s.drillModes) m.name]);
    await p.setInt('drillMaxFret', s.drillMaxFret);
    await p.setBool('drillNaturalsOnly', s.drillNaturalsOnly);
    await p.setStringList('drillStrings', [
      for (final x in s.drillStrings) '$x',
    ]);
    await p.setStringList('drillCategories', [
      for (final c in s.drillCategories) c.name,
    ]);
    await p.setInt('drillCount', s.drillCount);
  }

  Future<void> edit(Settings Function(Settings) f) => update(f(state));
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

final instrumentProvider = Provider<Instrument>(
  (ref) => ref.watch(settingsProvider).instrument,
);

final accidentalsProvider = Provider<Accidentals>(
  (ref) => ref.watch(settingsProvider).accidentals,
);

final curriculumProvider = Provider<Curriculum>((ref) {
  final s = ref.watch(settingsProvider);
  return Curriculum(s.kind, s.stringCount);
});
