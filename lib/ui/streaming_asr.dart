// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

class StreamingAsrScreen extends StatefulWidget {
  const StreamingAsrScreen(this.asrModel, {super.key});

  @override
  State<StreamingAsrScreen> createState() => _StreamingAsrScreenState();
}

class _StreamingAsrScreenState extends State<StreamingAsrScreen> {
  late final TextEditingController _controller;
  final Recorder _audioRecorder = Recorder.instance;
  final String _title = 'Real-time speech recognition';
  final List<int> _audioCache = [];
  String _last = '';
  int _index = 0;
  bool _isInitialized = false;
  bool _isProcessing = false;

  final bool _isOnline = false;
  final bool _usePunctuation = false;

  sherpa_onnx.OnlineRecognizer? _onlineRecognizer;
  sherpa_onnx.OnlineStream? _onlineStream;
  sherpa_onnx.OnlinePunctuation? _onlinePunctuation;

  sherpa_onnx.OfflineRecognizer? _offlineRecognizer;
  sherpa_onnx.OfflineStream? _offlineStream;

  final int _sampleRate = 16000;

  StreamSubscription? _recordSub;
  bool _isRecording = false;

  @override
  void initState() {
    _controller = TextEditingController();
    _initAsync();
    _recordSub = _audioRecorder.uint8ListStream.listen((data) {
      if (_isOnline) {
        _processAudioData(data);
      } else {
        _cacheAudioData(data);
      }
    });

    super.initState();
  }

  Future<void> _initAsync() async {
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      Permission.microphone.request().isGranted.then((value) async {
        if (!value) {
          await [Permission.microphone].request();
        }
      });
    }
    await _audioRecorder.init(sampleRate: _sampleRate);
    _audioRecorder.start();

    if (!_isOnline) {
      // Configure silence detection
      _audioRecorder.setSilenceDetection(
        enable: true,
        onSilenceChanged: (isSilent, decibel) {
          if (isSilent && !_isProcessing && _audioCache.isNotEmpty) {
            _processCachedAudio();
          }
        },
      );

      // Set silence threshold and duration
      _audioRecorder.setSilenceThresholdDb(-30);
      _audioRecorder.setSilenceDuration(0.5);
    }
    print('Initializing bindings');
    sherpa_onnx.initBindings();

    if (_usePunctuation) {
      _onlinePunctuation = await createOnlinePunctuation();
    }
  }

  Future<void> _start() async {
    if (!_isInitialized) {
      if (_isOnline) {
        _onlineRecognizer = await createOnlineRecognizer();
        _onlineStream = _onlineRecognizer?.createStream();
      } else {
        print('Creating offline recognizer');
        _offlineRecognizer = createOfflineRecognizer(sampleRate: _sampleRate);
        print('Offline recognizer created');
        _offlineStream = _offlineRecognizer?.createStream();
      }
      print('Recognizer initialized');
      _isInitialized = true;
    }

    try {
      _audioRecorder.startStreamingData();
      setState(() => _isRecording = true);
    } catch (e) {
      print(e);
    }
  }

  void _processAudioData(AudioDataContainer data) {
    if (_onlineStream != null && _onlineRecognizer != null) {
      final samplesFloat32 = convertBytesToFloat32(data.rawData);

      _onlineStream!
          .acceptWaveform(samples: samplesFloat32, sampleRate: _sampleRate);
      while (_onlineRecognizer!.isReady(_onlineStream!)) {
        _onlineRecognizer!.decode(_onlineStream!);
      }
      final recognizedText = _onlineRecognizer!.getResult(_onlineStream!).text;
      print('recognizedText: $recognizedText');
      final normalizedText = recognizedText.toLowerCase().trim();
      final puncText = _onlinePunctuation?.addPunct(normalizedText);
      if (puncText == null) {
        print('puncText is null');
      } else {
        print('puncText: $puncText');
      }
      final text = puncText ?? recognizedText;
      String textToDisplay = _last;
      if (text != '') {
        if (_last == '') {
          textToDisplay = '$_index: $text';
        } else {
          textToDisplay = '$_index: $text\n$_last';
        }
      }

      if (_onlineRecognizer!.isEndpoint(_onlineStream!)) {
        _onlineRecognizer!.reset(_onlineStream!);
        if (text != '') {
          _last = textToDisplay;
          _index += 1;
        }
      }

      _controller.value = TextEditingValue(
        text: textToDisplay,
        selection: TextSelection.collapsed(offset: textToDisplay.length),
      );
    }
  }

  Float32List convertBytesToFloat32(Uint8List bytes, [endian = Endian.little]) {
    final values = Float32List(bytes.length ~/ 2);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < bytes.length; i += 2) {
      int short = data.getInt16(i, endian);
      values[i ~/ 2] = short / 32678.0;
    }
    return values;
  }

  void _cacheAudioData(AudioDataContainer data) {
    if (_isRecording) {
      _audioCache.addAll(data.rawData);
    }
  }

  Future<void> _processCachedAudio() async {
    if (_audioCache.isEmpty || _isProcessing || _offlineRecognizer == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Convert cached audio to Float32List
      final samples = convertBytesToFloat32(_audioCache as Uint8List);

      // Create OfflineStream and feed it the samples
      final offlineStream = _offlineRecognizer!.createStream();

      offlineStream.acceptWaveform(
        samples: samples,
        sampleRate: _sampleRate,
      );

      // Decode the audio
      _offlineRecognizer!.decode(offlineStream);
      final result = _offlineRecognizer!.getResult(offlineStream).text;

      if (result.isNotEmpty) {
        setState(() {
          final textToDisplay = '$_index: $result\n$_last';
          _last = textToDisplay;
          _index++;
          _controller.text = textToDisplay;
        });
      }

      // Free the offline stream
      offlineStream.free();

      // Clear the cache after processing
      _audioCache.clear();
    } catch (e) {
      print('Error processing audio: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _stop() async {
    if (_isOnline) {
      _onlineStream!.free();
      _onlineStream = _onlineRecognizer!.createStream();
    } else {
      _offlineStream!.free();
      _offlineStream = _offlineRecognizer!.createStream();
    }
    _audioRecorder.stopStreamingData();
    setState(() => _isRecording = false);
    if (_audioCache.isNotEmpty) {
      _processCachedAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(_title),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            TextField(
              maxLines: 5,
              controller: _controller,
              readOnly: true,
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildRecordStopControl(),
                const SizedBox(width: 20),
                _buildText(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordSub?.cancel();
    _audioRecorder.stop();
    _onlineStream?.free();
    _offlineStream?.free();
    _onlineRecognizer?.free();
    _offlineRecognizer?.free();
    super.dispose();
  }

  Widget _buildRecordStopControl() {
    late Icon icon;
    late Color color;

    if (_isRecording) {
      icon = const Icon(Icons.stop, color: Colors.red, size: 30);
      color = Colors.red.withValues(alpha: 26);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withValues(alpha: 26);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            _isRecording ? _stop() : _start();
          },
        ),
      ),
    );
  }

  Widget _buildText() {
    if (!_isRecording) {
      return const Text("Start");
    } else {
      return const Text("Stop");
    }
  }
}
