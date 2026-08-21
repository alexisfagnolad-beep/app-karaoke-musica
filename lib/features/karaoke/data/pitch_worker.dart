import 'dart:async';
import 'dart:isolate';

import 'package:pitch_detector_dart/pitch_detector.dart';

/// Resultado liviano de la detección de tono (para pasar entre isolates).
class PitchResult {
  final double t; // instante del bloque (seg)
  final bool pitched;
  final double pitch; // Hz
  const PitchResult(this.t, this.pitched, this.pitch);
}

/// Detecta el tono del micrófono en un **isolate aparte** (segundo hilo), para
/// que el trabajo pesado (autocorrelación sobre miles de muestras) no trabe el
/// dibujo a 60fps. Antes esto corría en el hilo de la interfaz y hacía que el
/// karaoke avanzara "a los tirones".
///
/// Se manda un bloque por vez (con guard "ocupado") para no acumular atraso: si
/// llega un bloque mientras el isolate procesa, se descarta. El puntaje queda
/// apenas menos denso, pero el movimiento fluye.
class PitchWorker {
  Isolate? _iso;
  SendPort? _tx;
  ReceivePort? _rx;
  final Completer<void> _ready = Completer<void>();
  final StreamController<PitchResult> _out =
      StreamController<PitchResult>.broadcast();

  bool _busy = false;
  double _pendingT = 0;

  Stream<PitchResult> get results => _out.stream;

  Future<void> start(int sampleRate, int bufferSize) async {
    if (_iso != null) return;
    _rx = ReceivePort();
    _iso = await Isolate.spawn(
      _entry,
      [_rx!.sendPort, sampleRate, bufferSize],
    );
    _rx!.listen((msg) {
      if (msg is SendPort) {
        _tx = msg;
        if (!_ready.isCompleted) _ready.complete();
      } else if (msg is List) {
        _busy = false;
        _out.add(
          PitchResult(_pendingT, msg[0] as bool, (msg[1] as num).toDouble()),
        );
      }
    });
    await _ready.future;
  }

  /// Encola un bloque para analizar en el instante [t]. Si el isolate está
  /// ocupado, se descarta (evita atraso acumulado).
  void process(double t, List<double> block) {
    final tx = _tx;
    if (tx == null || _busy) return;
    _busy = true;
    _pendingT = t;
    tx.send(block);
  }

  void dispose() {
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
    _rx?.close();
    _out.close();
  }

  static void _entry(List<dynamic> args) {
    final SendPort tx = args[0] as SendPort;
    final int sr = args[1] as int;
    final int bs = args[2] as int;
    final rx = ReceivePort();
    tx.send(rx.sendPort);
    final detector = PitchDetector(
      audioSampleRate: sr.toDouble(),
      bufferSize: bs,
    );
    rx.listen((data) async {
      if (data is List) {
        try {
          final block = data.cast<double>();
          final r = await detector.getPitchFromFloatBuffer(block);
          tx.send([r.pitched, r.pitch]);
        } catch (_) {
          tx.send([false, 0.0]);
        }
      }
    });
  }
}
