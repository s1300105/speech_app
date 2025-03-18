
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;

/*

This is a very simple example for Flutter Sound beginners,
hat shows how to record, and then playback a file.

This example is really basic.

 */

typedef _Fn = void Function();

/* This does not work. on Android we must have the Manifest.permission.CAPTURE_AUDIO_OUTPUT permission.
 * But this permission is _is reserved for use by system components and is not available to third-party applications._
 * Pleaser look to [this](https://developer.android.com/reference/android/media/MediaRecorder.AudioSource#VOICE_UPLINK)
 *
 * I think that the problem is because it is illegal to record a communication in many countries.
 * Probably this stands also on iOS.
 * Actually I am unable to record DOWNLINK on my Xiaomi Chinese phone.
 *
 */
//const theSource = AudioSource.voiceUpLink;
//const theSource = AudioSource.voiceDownlink;

const theSource = AudioSource.microphone;

// Example app.
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  @override
  void initState() {
    _mPlayer!.openPlayer().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });

    openTheRecorder().then((value) {
      setState(() {
        _mRecorderIsInited = true;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _mPlayer!.closePlayer();
    _mPlayer = null;

    _mRecorder!.closeRecorder();
    _mRecorder = null;
    super.dispose();
  }

  // ------------------------------ This is the recorder stuff -----------------------------

  Codec _codec = Codec.aacMP4;
  String _mPath = 'tau_file.mp4';
  bool _mRecorderIsInited = false;

  /// Our player
  FlutterSoundPlayer? _mPlayer = FlutterSoundPlayer();

  /// Our recorder
  FlutterSoundRecorder? _mRecorder = FlutterSoundRecorder();

  /// Request permission to record something and open the recorder
  Future<void> openTheRecorder() async {
    if (!kIsWeb) {
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException('Microphone permission not granted');
      }
    }
    await _mRecorder!.openRecorder();
    if (!await _mRecorder!.isEncoderSupported(_codec) && kIsWeb) {
      _codec = Codec.opusWebM;
      _mPath = 'tau_file.webm';
      if (!await _mRecorder!.isEncoderSupported(_codec) && kIsWeb) {
        _mRecorderIsInited = true;
        return;
      }
    }
    _mRecorderIsInited = true;
  }

  /// Begin to record.
  /// This is our main function.
  /// We ask Flutter Sound to record to a File.
  void record() {
    _mRecorder!
        .startRecorder(
      toFile: _mPath,
      codec: _codec,
      audioSource: theSource,
    )
        .then((value) {
      setState(() {});
    });
  }

  /// Stop the recorder
  void stopRecorder() async {
    String? recordedFilePath = await _mRecorder!.stopRecorder();

    setState(() {
      _mplaybackReady = true;
    });

    print("This is recordedFilePath: $recordedFilePath");

    if (recordedFilePath != null && recordedFilePath.isNotEmpty) {
      if (kIsWeb) {
        // Web の場合、Blob URL を Uint8List に変換して送信
        await uploadAudioWeb(recordedFilePath);
      } else {
        // モバイルの場合、通常のファイルとして送信
        uploadAudio(File(recordedFilePath));
      }
    } else {
      print("recordedFilePath is null or empty");
    }
  }


  Future<void> uploadAudio(File file) async {
    var uri = Uri.parse('http://127.0.0.1:8000/api/upload/'); // Djangoのエンドポイント
    var request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('audio', file.path));

    var response = await request.send();

    if (response.statusCode == 200) {
      print("Upload successful!");
    } else {
      print("Upload failed with status: ${response.statusCode}");
    }
  }

  Future<void> uploadAudioWeb(String blobUrl) async {
    try {
      print("Fetching Blob data from: $blobUrl");

      // `blob:` URL からデータを取得
      final response = await html.HttpRequest.request(
        blobUrl,
        responseType: "arraybuffer",
      );

      if (response.status == 200) {
        Uint8List uint8list = Uint8List.view(response.response as ByteBuffer);

        var uri = Uri.parse('http://127.0.0.1:8000/api/upload/');
        var request = http.MultipartRequest('POST', uri);

        request.files.add(http.MultipartFile.fromBytes(
          'audio',
          uint8list,
          filename: 'recorded_audio.webm', // Web の場合は .webm 形式が多い
        ));

        var streamedResponse = await request.send();
        if (streamedResponse.statusCode == 200) {
          print("Upload successful!");
        } else {
          print("Upload failed with status: ${streamedResponse.statusCode}");
        }
      } else {
        print("Failed to fetch Blob data from URL.");
      }
    } catch (e) {
      print("Error uploading audio: $e");
    }
  }

// ----------------------------- This is the player stuff ---------------------------------

  bool _mplaybackReady = false;
  bool _mPlayerIsInited = false;

  /// Begin to play the recorded sound
  void play() {
    assert(_mPlayerIsInited &&
        _mplaybackReady &&
        _mRecorder!.isStopped &&
        _mPlayer!.isStopped);
    _mPlayer!
        .startPlayer(
        fromURI: _mPath,
        whenFinished: () {
          setState(() {});
        })
        .then((value) {
      setState(() {});
    });
  }

  /// Stop the player
  void stopPlayer() {
    _mPlayer!.stopPlayer().then((value) {
      setState(() {});
    });
  }

// ----------------------------- UI --------------------------------------------

  _Fn? getRecorderFn() {
    if (!_mRecorderIsInited || !_mPlayer!.isStopped) {
      return null;
    }
    return _mRecorder!.isStopped ? record : stopRecorder;
  }

  _Fn? getPlaybackFn() {
    if (!_mPlayerIsInited || !_mplaybackReady || !_mRecorder!.isStopped) {
      return null;
    }
    return _mPlayer!.isStopped ? play : stopPlayer;
  }

  @override
  Widget build(BuildContext context) {
    Widget makeBody() {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(3),
            height: 80,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF0E6),
              border: Border.all(
                color: Colors.indigo,
                width: 3,
              ),
            ),
            child: Row(children: [
              ElevatedButton(
                onPressed: getRecorderFn(),
                //color: Colors.white,
                //disabledColor: Colors.grey,
                child: Text(_mRecorder!.isRecording ? 'Stop' : 'Record'),
              ),
              const SizedBox(
                width: 20,
              ),
              Text(_mRecorder!.isRecording
                  ? 'Recording in progress'
                  : 'Recorder is stopped'),
            ]),
          ),
          Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(3),
            height: 80,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF0E6),
              border: Border.all(
                color: Colors.indigo,
                width: 3,
              ),
            ),
            child: Row(children: [
              ElevatedButton(
                onPressed: getPlaybackFn(),
                //color: Colors.white,
                //disabledColor: Colors.grey,
                child: Text(_mPlayer!.isPlaying ? 'Stop' : 'Play'),
              ),
              const SizedBox(
                width: 20,
              ),
              Text(_mPlayer!.isPlaying
                  ? 'Playback in progress'
                  : 'Player is stopped'),
            ]),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: const Text('Simple Recorder'),
      ),
      body: makeBody(),
    );
  }
}

