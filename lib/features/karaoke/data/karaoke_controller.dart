import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../pitch/domain/musical_note.dart';
import '../domain/melody.dart';
import '../domain/rhythm.dart';
import '../domain/scoring.dart';
import '../domain/tone_synth.dart';
import 'instrument_audio.dart';
import 'pitch_worker.dart';

/// Orquesta la práctica con puntaje: reproduce el instrumental, escucha el
/// micrófono (voz/instrumento) y, al terminar, puntúa contra la referencia.
///
/// Dos modos según la referencia cargada:
/// - melódico (Melody): compara afinación.
/// - rítmico (Rhythm): compara el tiempo de los golpes.
class KaraokeController extends ChangeNotifier {
  static const int sampleRate = 44100;
  static const int bufferSize = 2000;

  final AudioPlayer player = AudioPlayer();
  final FlutterAudioCapture _capture = FlutterAudioCapture();

  /// Detección de tono en un isolate aparte (para que el dibujo fluya).
  final PitchWorker _pitchWorker = PitchWorker();
  StreamSubscription<PitchResult>? _pitchSub;

  Melody? _melody;
  Rhythm? _rhythm;
  bool get isRhythm => _rhythm != null;

  final List<PerformanceSample> _samples = [];
  final List<double> _userOnsets = [];
  // Umbral algo más sensible para que enganche mejor un instrumento físico.
  final OnsetDetector _onset = OnsetDetector(threshold: 1.8, minInterval: 0.08);

  bool _capInited = false;
  bool _running = false;
  bool _micActive = false;
  bool _disposed = false;
  String? _error;

  MusicalNote? _sung;
  MelodyFrame? _target;
  int _hits = 0;

  // --- Estado del juego melódico en vivo (barras estilo karaoke) ---
  /// Notas de la melodía como barras (fraseo). Vacío en modo rítmico.
  List<MelodyNote> notes = const [];

  /// Cuánto se "iluminó" cada barra (0..1): fracción de su duración cantada
  /// afinada. Paralelo a [notes].
  List<double> noteLit = const [];

  /// Tramo acertado de cada barra, como fracción 0..1 (inicio y fin). Permite
  /// marcar EXACTAMENTE desde dónde empezamos a dar la nota (aunque tarde) hasta
  /// dónde llegamos, y que quede marcado. Paralelo a [notes].
  List<double> coverStart = const [];
  List<double> coverEnd = const [];

  /// Índice de la barra activa (la que suena ahora), o null.
  int? activeNote;

  /// Nota MIDI continua que está cantando el usuario ahora, o null.
  double? _livePitch;

  /// Puntaje en vivo, va sumando mientras cantás sobre la barra.
  double _liveScore = 0;

  /// Afinación respecto de la barra activa: -1 grave (abajo), +1 agudo
  /// (arriba), 0 afinado.
  int _direction = 0;

  double? _lastT;

  /// Semitonos de tolerancia para considerar que "pegaste" la barra.
  /// Amable a propósito (es un juego): con estar cerca, cuenta.
  static const double onPitchTolerance = 2.5;

  /// Efectos (vibración al acertar). Se puede silenciar desde Ajustes.
  static bool effectsEnabled = true;
  int _lastHapticNote = -1;

  /// Sonido de las melodías/patrones prediseñados ("Para empezar"). Se puede
  /// silenciar desde Ajustes o con el botón de la propia pantalla.
  static bool builtInSoundEnabled = true;

  KaraokeResult? melodicResult;
  RhythmResult? rhythmResult;

  /// Tiempo (seg) del último golpe del usuario (para el flash de la vista de
  /// batería). -1 si todavía no golpeó.
  double lastUserHitT = -1;

  /// Nivel del micrófono ahora (0..1), para mostrar que está escuchando.
  double micLevel = 0;

  /// true si el micrófono está capturando (para el indicador "escuchando").
  bool get listening => _micActive;

  /// Velocidad de reproducción (1.0 = normal). Bajarla ayuda a aprender; como
  /// todo se sincroniza con el reloj, las barras/notas siguen alineadas.
  double tempo = 1.0;

  /// Cambia el tempo (0.35..1.0). El tono se mantiene (no suena grave). Para
  /// los chicos se puede ir bien lento sin que la guía se acelere.
  Future<void> setTempo(double value) async {
    tempo = value.clamp(0.35, 1.0);
    try {
      await player.setSpeed(tempo);
    } catch (_) {}
    notifyListeners();
  }

  /// Tiempo actual en segundos (posición de la pista de audio).
  double get clock => player.position.inMilliseconds / 1000.0;

  // --- Modo "tocar y seguir" (Para empezar): sin micrófono, con sonido ---
  /// true = contenido prediseñado que suena solo (melodía/patrón) y se puede
  /// tocar en pantalla. No usa micrófono ni puntúa: es para jugar y aprender.
  bool playAlong = false;
  Future<void>? _loadFuture;
  static int _trackSeq = 0;

  /// Sonidos de instrumento al tocar el piano/batería en pantalla.
  InstrumentAudio? _instr;

  /// Practicar con instrumento FÍSICO: enciende el micrófono para detectar si
  /// tocás la nota/golpe correcto en el momento justo (además del virtual).
  bool micPractice = false;

  /// Modo estricto (batería): exige pegarle a la PIEZA correcta, no solo en el
  /// momento justo. Clasifica el golpe por su color de sonido (grave/medio/agudo).
  bool strictDrums = false;

  /// Cantar una canción prediseñada: play-along melódico con micrófono para
  /// puntuar la voz, pero manteniendo la melodía guía sonando (no la silencia).
  bool builtInSing = false;

  /// Teclas apretadas ahora en el piano virtual (multitáctil, para acordes).
  final Set<int> pressedMidis = {};

  /// Pieza de batería (band) tocada recién en pantalla, o -1 (destello corto).
  int tappedBand = -1;

  /// Notas ya "acertadas" (paralelo a [notes]): brillan al pasar por la línea.
  List<bool> noteHit = const [];

  /// Momento del último golpe correcto por pieza de batería (para el brillo).
  final List<double> lastBandHitT = [-1, -1, -1];

  /// Momento del último golpe por PIEZA (id del catálogo), para iluminar la
  /// pieza exacta (tom1, crash, …) y no todas las de la misma banda.
  final Map<String, double> lastPieceHitT = {};

  /// Pieza canónica de cada banda (cuando un golpe no apunta a una específica).
  static const List<String> _canonPiece = ['kick', 'snare', 'hihat'];

  /// Momento del último acierto (para el cartel rápido de "¡Bien!").
  double lastHitT = -1;

  /// Aciertos acumulados y onsets ya acertados (para el puntaje festivo).
  int _goodHits = 0;
  final Set<int> _hitOnsets = {};

  // Acumulación de "cobertura" de las notas mientras se mantiene la tecla
  // correcta (para que se marque el tramo acertado de una nota larga).
  Timer? _coverTimer;
  double? _coverLastT;

  /// Semitonos de tolerancia para considerar "acertada" una tecla/nota tocada.
  static const double _hitTolerance = 1.0;

  /// Ventana (seg) alrededor del objetivo para contar un golpe como acierto.
  static const double _hitWindow = 0.22;

  /// Carga una melodía prediseñada: la sintetiza a audio (para que suene y para
  /// mover la guía con precisión) y prepara los sonidos del teclado.
  void loadBuiltInMelodic(
    List<MelodyNote> builtNotes,
    double duration, {
    int difficulty = 0,
  }) {
    _melody = null;
    _rhythm = null;
    freeMode = false;
    playAlong = true;
    this.difficulty = difficulty.clamp(0, 2);
    notes = builtNotes;
    noteLit = List<double>.filled(notes.length, 0);
    noteHit = List<bool>.filled(notes.length, false);
    coverStart = List<double>.filled(notes.length, 1.0);
    coverEnd = List<double>.filled(notes.length, 0.0);
    // Precarga el rango del teclado (notas de la canción ± un poco).
    var lo = builtNotes.isEmpty ? 60 : builtNotes.first.midi;
    var hi = lo;
    for (final n in builtNotes) {
      if (n.midi < lo) lo = n.midi;
      if (n.midi > hi) hi = n.midi;
    }
    _instr = InstrumentAudio()
      ..preloadNotes([for (var m = lo - 2; m <= hi + 2; m++) m]);
    _loadFuture = _prepareTrack(ToneSynth.renderMelody(builtNotes, duration));
  }

  /// Carga un patrón rítmico prediseñado (lo sintetiza a audio y prepara los
  /// sonidos de batería para tocar en pantalla).
  void loadBuiltInRhythm(Rhythm rhythm, double duration) {
    _rhythm = rhythm;
    _melody = null;
    playAlong = true;
    _instr = InstrumentAudio()..preloadDrums();
    _loadFuture = _prepareTrack(ToneSynth.renderRhythm(rhythm, duration));
  }

  /// Escribe el WAV sintetizado a un archivo temporal y lo carga en el player.
  Future<void> _prepareTrack(List<int> wav) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/builtin_${_trackSeq++}.wav');
      await f.writeAsBytes(wav, flush: true);
      await player.setAudioSource(AudioSource.uri(Uri.file(f.path)));
      player.playerStateStream.listen(_onPlayerState);
    } catch (e) {
      _error = 'No se pudo preparar el audio: $e';
      notifyListeners();
    }
  }

  /// Aprieta una tecla del piano virtual (multitáctil): suena SOSTENIDO hasta
  /// soltar. Si cae justo sobre la nota guía, cuenta como acierto (brilla).
  void noteOn(int pointer, int midi) {
    _instr?.noteOn(pointer, midi);
    if (effectsEnabled) HapticFeedback.selectionClick();
    pressedMidis.add(midi);
    _checkMelodicHit(midi);
    notifyListeners();
  }

  /// Suelta la tecla (corta el sostenido de esa nota).
  void noteOff(int pointer, int midi) {
    _instr?.noteOff(pointer);
    pressedMidis.remove(midi);
    notifyListeners();
  }

  /// Toca una PIEZA de la batería en pantalla: suena su propio sonido y, si cae
  /// justo sobre el golpe guía, cuenta como acierto e ilumina esa pieza.
  void tapPiece(String pieceId, int band) {
    _instr?.playPiece(pieceId);
    if (effectsEnabled) HapticFeedback.lightImpact();
    tappedBand = band;
    _registerRhythmHit(clock, strictDrums ? band : null, pieceId);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (_disposed) return;
      if (tappedBand == band) {
        tappedBand = -1;
        notifyListeners();
      }
    });
  }

  /// ¿La tecla [midi] acierta la nota guía activa (en el momento justo)?
  void _checkMelodicHit(int midi) {
    final idx = _noteIndexAt(clock);
    if (idx == null || idx >= noteHit.length) return;
    if (octaveFoldedDiff(midi.toDouble(), notes[idx].midi).abs() <=
        _hitTolerance) {
      _markMelodicHit(idx);
      lastHitT = clock;
    }
  }

  void _markMelodicHit(int idx) {
    if (idx < 0 || idx >= noteHit.length || noteHit[idx]) return;
    noteHit[idx] = true;
    _goodHits++;
  }

  /// Registra que en el instante [t] estamos dando la nota [idx]: acumula la
  /// fracción cubierta y marca el tramo (desde dónde empezamos hasta ahora),
  /// para iluminar exactamente lo que logramos aunque hayamos entrado tarde.
  void _cover(int idx, double t, double dt) {
    if (idx < 0 || idx >= noteLit.length) return;
    final dur = notes[idx].duration;
    if (dur > 0) {
      noteLit[idx] = (noteLit[idx] + dt / dur).clamp(0.0, 1.0);
      final frac = ((t - notes[idx].startT) / dur).clamp(0.0, 1.0);
      if (idx < coverStart.length) {
        if (frac < coverStart[idx]) coverStart[idx] = frac;
        if (frac > coverEnd[idx]) coverEnd[idx] = frac;
      }
    }
    lastHitT = t;
    _markMelodicHit(idx);
  }

  /// Timer que acumula el tramo acertado de la nota activa mientras se mantiene
  /// apretada la tecla correcta (piano virtual). El tramo ya cubierto queda
  /// marcado aunque después soltemos; el destello solo dura mientras cubrimos.
  void _startCoverTimer() {
    if (isRhythm) return;
    _coverLastT = null;
    _coverTimer?.cancel();
    _coverTimer = Timer.periodic(const Duration(milliseconds: 50), _coverTick);
  }

  void _coverTick(Timer t) {
    if (_disposed || !_running) {
      t.cancel();
      return;
    }
    final now = clock;
    final dt = _coverLastT == null ? 0.0 : (now - _coverLastT!).clamp(0.0, 0.12);
    _coverLastT = now;
    final idx = _noteIndexAt(now);
    activeNote = idx;
    if (idx == null || idx >= noteLit.length) return;
    final target = notes[idx].midi;
    var covering = false;
    for (final m in pressedMidis) {
      if (octaveFoldedDiff(m.toDouble(), target).abs() <= _hitTolerance) {
        covering = true;
        break;
      }
    }
    if (covering) _cover(idx, now, dt);
  }

  /// Un golpe (virtual o físico) cerca de un objetivo cuenta como acierto e
  /// ilumina la pieza correspondiente. [tappedPiece] es la pieza que se tocó en
  /// pantalla (si la hay); si no, se ilumina la pieza del golpe guía.
  void _registerRhythmHit(double t, [int? band, String? tappedPiece]) {
    final r = _rhythm;
    if (r == null) return;
    var best = -1;
    var bestDt = _hitWindow;
    for (var i = 0; i < r.hits.length; i++) {
      // Virtual (band != null): tiene que ser la pieza correcta. Físico (band
      // null, por micrófono): cuenta cualquier golpe en el momento justo.
      if (band != null && r.hits[i].band.clamp(0, 2) != band) continue;
      final dt = (r.hits[i].t - t).abs();
      if (dt <= bestDt) {
        bestDt = dt;
        best = i;
      }
    }
    if (best < 0) return;
    final h = r.hits[best];
    final b = h.band.clamp(0, 2);
    final piece = tappedPiece ?? h.piece ?? _canonPiece[b];
    lastPieceHitT[piece] = clock;
    lastBandHitT[b] = clock;
    lastHitT = clock;
    if (_hitOnsets.add(best)) _goodHits++;
  }

  /// Clasifica un golpe por su "color de sonido" usando la tasa de cruces por
  /// cero (proxy barato del brillo/centroide, sin FFT):
  ///  - grave y con pocas cruces  -> bombo (0)
  ///  - agudo/ruidoso, muchas cruces -> hi-hat (2)
  ///  - en el medio -> redoblante (1)
  int _bandOf(List<double> block) {
    if (block.length < 2) return 1;
    var crossings = 0;
    var prev = block[0];
    for (var i = 1; i < block.length; i++) {
      final v = block[i];
      if ((v >= 0) != (prev >= 0)) crossings++;
      prev = v;
    }
    final zcr = crossings / block.length;
    if (zcr < 0.06) return 0; // bombo
    if (zcr > 0.20) return 2; // hi-hat
    return 1; // redoblante
  }

  /// Enciende/apaga la práctica con instrumento físico (micrófono). Se aplica
  /// al empezar (no mientras suena).
  void setMicPractice(bool value) {
    if (_running) return;
    micPractice = value;
    notifyListeners();
  }

  /// Aplica el ajuste de sonido (mute/unmute) en vivo si está sonando.
  Future<void> applySound() async {
    if (playAlong) {
      try {
        await player.setVolume(builtInSoundEnabled ? 1.0 : 0.0);
      } catch (_) {}
    }
    notifyListeners();
  }

  bool get running => _running;
  String? get error => _error;
  MusicalNote? get sung => _sung;
  MelodyFrame? get target => _target;
  Rhythm? get rhythmRef => _rhythm;
  int get hits => _hits;
  double? get livePitch => _livePitch;
  int get liveScore => _liveScore.floor();
  int get direction => _direction;
  bool get finished => melodicResult != null || rhythmResult != null;

  /// Modo libre ("Solo letra"): reproduce la pista con las barras y la letra
  /// como guía, pero SIN micrófono ni puntaje.
  bool freeMode = false;

  /// Dificultad: 0 = Fácil (barras muy resumidas), 1 = Normal, 2 = Exigente
  /// (sigue la melodía más de cerca). Cambia cuánto se simplifica la línea.
  int difficulty = 1;
  // Fácil (0) más "amable": barras largas y bien pegadas (línea melódica
  // continua, fácil de cantar). Normal (1) y Exigente (2) siguen más de cerca.
  static const List<double> _diffMinDur = [0.38, 0.16, 0.09];
  static const List<double> _diffThresh = [1.4, 0.9, 0.6];
  static const List<int> _diffSmooth = [13, 9, 5];
  static const List<double> _diffMaxGap = [0.75, 0.45, 0.30];

  void _rebuildNotes() {
    final m = _melody;
    if (m == null) {
      notes = const [];
      noteLit = const [];
      return;
    }
    notes = m.notes(
      minDuration: _diffMinDur[difficulty],
      changeThreshold: _diffThresh[difficulty],
      smoothWindow: _diffSmooth[difficulty],
      maxGap: _diffMaxGap[difficulty],
    );
    noteLit = List<double>.filled(notes.length, 0);
    noteHit = List<bool>.filled(notes.length, false);
    coverStart = List<double>.filled(notes.length, 1.0);
    coverEnd = List<double>.filled(notes.length, 0.0);
  }

  /// Cambia la dificultad (rehace las barras). Solo cuando no está corriendo y
  /// hay una melodía cargada (no aplica a contenido prediseñado).
  void setDifficulty(int level) {
    if (_running || _melody == null) return;
    difficulty = level.clamp(0, 2);
    _rebuildNotes();
    notifyListeners();
  }

  Future<void> loadMelodic(
    String instrumentalPath,
    Melody melody, {
    bool freeMode = false,
    int difficulty = 1,
  }) async {
    _melody = melody;
    _rhythm = null;
    this.freeMode = freeMode;
    this.difficulty = difficulty.clamp(0, 2);
    _rebuildNotes();
    // Piano virtual disponible también acá: precarga el rango de la canción.
    if (notes.isNotEmpty) {
      var lo = notes.first.midi;
      var hi = lo;
      for (final n in notes) {
        if (n.midi < lo) lo = n.midi;
        if (n.midi > hi) hi = n.midi;
      }
      _instr = InstrumentAudio()
        ..preloadNotes([for (var m = lo - 2; m <= hi + 2; m++) m]);
    }
    await player.setAudioSource(AudioSource.uri(Uri.file(instrumentalPath)));
    player.playerStateStream.listen(_onPlayerState);
  }

  Future<void> loadRhythmic(String instrumentalPath, Rhythm rhythm) async {
    _rhythm = rhythm;
    _melody = null;
    _instr = InstrumentAudio()..preloadDrums();
    await player.setAudioSource(AudioSource.uri(Uri.file(instrumentalPath)));
    player.playerStateStream.listen(_onPlayerState);
  }

  void _onPlayerState(PlayerState state) {
    if (_disposed) return;
    if (state.processingState == ProcessingState.completed && _running) {
      finish();
    }
  }

  Future<void> start() async {
    if (_running) return;
    _error = null;
    melodicResult = null;
    rhythmResult = null;
    _samples.clear();
    _userOnsets.clear();
    _onset.reset();
    _hits = 0;
    lastUserHitT = -1;
    _lastHapticNote = -1;
    _liveScore = 0;
    _direction = 0;
    _lastT = null;
    activeNote = null;
    _livePitch = null;
    if (noteLit.isNotEmpty) noteLit = List<double>.filled(notes.length, 0);
    if (noteHit.isNotEmpty) noteHit = List<bool>.filled(notes.length, false);
    if (notes.isNotEmpty) {
      coverStart = List<double>.filled(notes.length, 1.0);
      coverEnd = List<double>.filled(notes.length, 0.0);
    }
    pressedMidis.clear();
    tappedBand = -1;
    lastBandHitT[0] = lastBandHitT[1] = lastBandHitT[2] = -1;
    lastPieceHitT.clear();
    lastHitT = -1;
    micLevel = 0;
    _goodHits = 0;
    _hitOnsets.clear();
    notifyListeners();

    // "Para empezar": suena solo y se puede tocar en pantalla. Opcionalmente,
    // con "instrumento real" (micrófono), también detecta un piano/batería
    // físico cerca del celular.
    if (playAlong) {
      try {
        if (_loadFuture != null) await _loadFuture;
        // Con instrumento real, silenciamos la pista guía para que el micrófono
        // escuche solo el instrumento físico (y no la propia app).
        if (micPractice) {
          final ok = await _startMicCapture();
          if (!ok) {
            _error =
                'No pude usar el micrófono. Activá el permiso para tocar el '
                'instrumento real.';
          }
        }
        _running = true;
        await player.seek(Duration.zero);
        await player.setSpeed(tempo);
        // Al cantar prediseñado, la melodía guía sigue sonando (no se silencia).
        final soundOn = builtInSoundEnabled && (!micPractice || builtInSing);
        await player.setVolume(soundOn ? 1.0 : 0.0);
        player.play();
        _startCoverTimer();
        notifyListeners();
      } catch (e) {
        _error = 'No se pudo iniciar: $e';
        _running = false;
        notifyListeners();
      }
      return;
    }

    // Modo libre: solo reproducir (sin micrófono ni puntaje).
    if (freeMode) {
      try {
        _running = true;
        await player.seek(Duration.zero);
        await player.setSpeed(tempo);
        player.play();
        notifyListeners();
      } catch (e) {
        _error = 'No se pudo iniciar: $e';
        notifyListeners();
      }
      return;
    }

    final ok = await _startMicCapture();
    if (!ok) {
      _error = 'Necesito permiso de micrófono para puntuar.';
      notifyListeners();
      return;
    }

    try {
      _running = true;
      await player.seek(Duration.zero);
      await player.setSpeed(tempo);
      player.play();
      _startCoverTimer();
      notifyListeners();
    } catch (e) {
      _error = 'No se pudo iniciar: $e';
      notifyListeners();
    }
  }

  /// Arranca el micrófono (permiso + captura + worker de tono). Devuelve false
  /// si no hay permiso. En modo melódico, la detección corre en un isolate.
  Future<bool> _startMicCapture() async {
    if (_micActive) return true;
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
    try {
      if (!_capInited) {
        await _capture.init();
        _capInited = true;
      }
      if (!isRhythm) {
        await _pitchWorker.start(sampleRate, bufferSize);
        _pitchSub ??= _pitchWorker.results.listen(_onPitch);
      }
      await _capture.start(
        _onAudio,
        _onError,
        sampleRate: sampleRate,
        bufferSize: bufferSize,
      );
      _micActive = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onAudio(dynamic obj) async {
    if (!_running) return;
    final block = (obj as List).cast<double>();
    final t = clock;

    // Nivel del micrófono (para el indicador "escuchando" y el destello).
    var energy = 0.0;
    for (final v in block) {
      energy += v * v;
    }
    energy = math.sqrt(energy / block.length);
    micLevel = micLevel * 0.6 + (energy * 6).clamp(0.0, 1.0) * 0.4;

    if (isRhythm) {
      if (_onset.process(block, t)) {
        _userOnsets.add(t);
        _hits++;
        lastUserHitT = t;
        if (effectsEnabled) HapticFeedback.lightImpact();
        // Modo estricto: clasificamos la pieza por su color de sonido y exigimos
        // que coincida. Modo normal: cuenta cualquier golpe en el momento justo.
        _registerRhythmHit(t, strictDrums ? _bandOf(block) : null);
      }
      notifyListeners();
    } else {
      // Trabajo pesado fuera del hilo de UI: el resultado llega por _onPitch.
      _pitchWorker.process(t, block);
      // En "instrumento real" actualizamos el medidor en vivo (en karaoke normal
      // ya lo hace _onPitch, para no recargar el hilo de UI).
      if (playAlong) notifyListeners();
    }
  }

  /// Llega el tono detectado por el isolate (melódico).
  void _onPitch(PitchResult r) {
    if (_disposed || !_running || isRhythm) return;
    final t = r.t;
    double? midi;
    if (r.pitched && r.pitch > 0) {
      midi = 69 + 12 * (math.log(r.pitch / 440.0) / math.ln2);
      _sung = MusicalNote.fromFrequency(r.pitch);
    } else {
      _sung = null;
    }
    _livePitch = midi;
    _samples.add(PerformanceSample(t, midi));
    _target = _melody?.frameAt(t);
    _updateLiveGame(t, midi);
    notifyListeners();
  }

  /// Actualiza barras activas, iluminación y puntaje en vivo.
  void _updateLiveGame(double t, double? midi) {
    final dt = _lastT == null ? 0.0 : (t - _lastT!).clamp(0.0, 0.25);
    _lastT = t;

    final idx = _noteIndexAt(t);
    activeNote = idx;

    if (idx == null || midi == null) {
      _direction = 0;
      return;
    }

    // Al cantar prediseñado (para chicos) somos MÁS amables: con acercarse a la
    // nota (aunque no sea exacta) ya cuenta e ilumina la barra.
    final tol = builtInSing ? 4.0 : onPitchTolerance;
    final diff = octaveFoldedDiff(midi, notes[idx].midi);
    if (diff.abs() <= tol) {
      _direction = 0;
      // Vibración corta al "enganchar" una barra nueva afinado.
      if (effectsEnabled && idx != _lastHapticNote) {
        _lastHapticNote = idx;
        HapticFeedback.selectionClick();
      }
      // Marca el tramo cantado afinado desde donde empezamos (aunque tarde).
      _cover(idx, t, dt);
      // Sumar puntos: más cerca de la nota y más sostenido = más puntaje.
      final closeness = (1.0 - diff.abs() / tol).clamp(0.0, 1.0);
      _liveScore += dt * (60 + 40 * closeness);
    } else {
      _direction = diff > 0 ? 1 : -1; // agudo (arriba) / grave (abajo).
    }
  }

  /// Índice de la barra que suena en el instante [t], o null.
  int? _noteIndexAt(double t) {
    for (var i = 0; i < notes.length; i++) {
      if (t >= notes[i].startT && t < notes[i].endT) return i;
    }
    return null;
  }

  void _onError(Object e) {
    _error = 'Error de audio: $e';
    notifyListeners();
  }

  Future<void> finish() async {
    if (_disposed || !_running) return;
    _running = false;
    _coverTimer?.cancel();
    if (_micActive) {
      _micActive = false;
      try {
        await _capture.stop();
      } catch (_) {}
    }
    try {
      await player.stop();
    } catch (_) {}
    pressedMidis.clear();
    _instr?.allOff();

    // Play-along ("Para empezar"): festejo amable. El puntaje refleja cuánto
    // acompañaste (tocando o cantando), con un piso alto para que siempre sea
    // alentador.
    if (playAlong) {
      if (isRhythm) {
        final total = _rhythm?.hits.length ?? 0;
        final ratio = total == 0 ? 1.0 : (_goodHits / total).clamp(0.0, 1.0);
        final score = (55 + 45 * ratio).clamp(0.0, 100.0).toDouble();
        rhythmResult = RhythmResult(
          score: score,
          timing: ratio,
          recall: ratio,
          precision: 1,
          matched: _goodHits,
          total: total,
        );
      } else {
        final total = notes.length;
        final hit = noteHit.where((h) => h).length;
        final ratio = total == 0 ? 1.0 : (hit / total).clamp(0.0, 1.0);
        final score = (55 + 45 * ratio).clamp(0.0, 100.0).toDouble();
        melodicResult = KaraokeResult(
          score: score,
          pitchAccuracy: ratio,
          coverage: ratio,
        );
      }
      notifyListeners();
      return;
    }

    // Modo libre: no hay puntaje, solo termina.
    if (freeMode) {
      notifyListeners();
      return;
    }

    if (isRhythm) {
      rhythmResult = scoreRhythm(_rhythm!.onsets, _userOnsets);
    } else {
      // Puntúa contra las barras que se ven (coherente con la guía en pantalla).
      melodicResult = scoreAgainstNotes(notes, _samples);
    }
    notifyListeners();
  }

  Future<void> stop() => finish();

  @override
  void dispose() {
    _disposed = true;
    _coverTimer?.cancel();
    if (_micActive) {
      _capture.stop();
    }
    _pitchSub?.cancel();
    _pitchWorker.dispose();
    _instr?.dispose();
    player.dispose();
    super.dispose();
  }
}
