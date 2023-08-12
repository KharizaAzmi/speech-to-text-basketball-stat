import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';

class SpeechText extends StatefulWidget {
  const SpeechText({super.key});

  @override
  _SpeechTextState createState() => _SpeechTextState();
}

class _SpeechTextState  extends State<SpeechText>{
  final List<TextMessage> _messages = <TextMessage>[];
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;

  RecorderStream _recorder = RecorderStream();
  late StreamSubscription _recorderStatus;
  late StreamSubscription<List<int>> _audioStreamSubscription;
  late BehaviorSubject<List<int>> _audioStream;

  // TODO DialogflowGrpc class instance
  @override
  void initState() {
    super.initState();
    initPlugin();
  }

  @override
  void dispose() {
    _recorderStatus?.cancel();
    _audioStreamSubscription?.cancel();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlugin() async {
    _recorderStatus = _recorder.status.listen((status) {
      if (mounted)
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
    });

    await Future.wait([
      _recorder.initialize()
    ]);



    // TODO Get a Service account

  }

  void stopStream() async {
    await _recorder.stop();
    await _audioStreamSubscription?.cancel();
    await _audioStream?.close();
  }

  void handleSubmitted(text) async {
    print(text);
    _textController.clear();

    //TODO Dialogflow Code

  }

  void handleStream() async {
    _recorder.start();

    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((data) {
      print(data);
      _audioStream.add(data);
    });


    // TODO Create SpeechContexts
    // Create an audio InputConfig

    // TODO Make the streamingDetectIntent call, with the InputConfig and the audioStream
    // TODO Get the transcript and detectedIntent and show on screen

  }

  @override
  Widget build(BuildContext context) {
    var text;
    return SafeArea(
      child: Scaffold(
        bottomNavigationBar: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if(!_isRecording) ...[
              FloatingActionButton(
                backgroundColor: const Color(0xff764abc),
                child: const Icon(
                  Icons.mic,
                  size: 35,
                ),
                onPressed: () {
                  handleStream();
                },
              ),
            ] else ...[
              FloatingActionButton(
                backgroundColor: const Color(0xff764abc),
                  child: const Icon(
                    Icons.stop,
                    size: 35,
                  ),
                  onPressed: (){
                    stopStream();
                  }
              )
            ],
            if (_isRecording) ...[
              Text(
                text,
                style: TextStyle(color: Colors.black, fontSize: 22.5)),
            ],
          ]
        ),
        appBar: AppBar(),
        body: Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Hold to speak',
                      style: TextStyle(
                            fontSize: 30.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextField(
                  controller: _textController,
                  readOnly: true,
                  onChanged: (String text) {
                    setState(() {
                      handleSubmitted;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TextMessage extends StatelessWidget {
  TextMessage({required this.text, required this.name, required this.type});

  final String text;
  final String name;
  final bool type;

  List<Widget> otherMessage(context) {
    return <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(this.name,
                style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: Text(text),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> myMessage(context) {
    return <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(this.name, style: Theme.of(context).textTheme.subtitle1),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: Text(text),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: this.type ? myMessage(context) : otherMessage(context),
      ),
    );
  }

}
