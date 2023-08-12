// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:dialogflow_grpc/dialogflow_grpc.dart';
import 'package:dialogflow_grpc/generated/google/cloud/dialogflow/v2beta1/session.pb.dart';
import 'package:googleapis/speech/v1.dart' as speech;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'dart:typed_data';


// TODO import Dialogflow


class Chat extends StatefulWidget {
  Chat({Key? key}) : super(key: key);

  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;

  late speech.SpeechApi _speechApi;

  RecorderStream _recorder = RecorderStream();
  late StreamSubscription _recorderStatus;
  //late StreamSubscription<List<int>> _audioStreamSubscription;
  late StreamSubscription<Uint8List> _audioStreamSubscription;
  // late BehaviorSubject<List<int>> _audioStream;
  late BehaviorSubject<Uint8List> _audioStream;

  // TODO DialogflowGrpcV2Beta1 class instance

  late DialogflowGrpcV2Beta1 dialogflow;

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
      if (mounted) {
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
      }
    });

    await Future.wait([
      _recorder.initialize()
    ]);

    // TODO Get a Service account
    final serviceAccount = ServiceAccount.fromString(
        '${(await rootBundle.loadString('assets/credentials.json'))}'
    );

    dialogflow = DialogflowGrpcV2Beta1.viaServiceAccount(serviceAccount);


  }

  Future<String> transcribeAudio(List<int> audioData) async {
    // TODO: Ganti dengan kredensial Anda (service account key file)
    String jsonString = await rootBundle.loadString('assets/serviceAccount.json');

    // Mengonversi JSON menjadi objek Map
    Map<String, dynamic> json = jsonDecode(jsonString);

    // Membuat objek ServiceAccountCredentials dari JSON
    var credentials = auth.ServiceAccountCredentials.fromJson(json);

    // final credentials = await auth.clientViaServiceAccount(
    //   ServiceAccountCredentials.fromJson(yourServiceAccountJson),
    //   speech.SpeechApi.speechScope, // Pastikan speechScope telah didefinisikan
    // );

    //var client = await auth.clientViaServiceAccount(credentials, speech.SpeechApi);

    var client = await auth.clientViaServiceAccount(credentials, speech.SpeechApi as List<String>);

    var speechClient = speech.SpeechApi(client);
    var recognitionConfig = speech.RecognitionConfig(
      encoding: 'LINEAR16',
      sampleRateHertz: 16000,
      languageCode: 'id-ID',
    );

    var audio = speech.RecognitionAudio()..content = audioData as String?;

    var response = await speechClient.speech.recognize(recognitionConfig as speech.RecognizeRequest);
    var transcript = response.results?.map((result) => result.alternatives?.first?.transcript).join(" ");
    return transcript ?? "";
  }


  Future<auth.ServiceAccountCredentials> loadServiceAccountCredentials(String path) async {
    String jsonString = await rootBundle.loadString(path);
    Map<String, dynamic> credentialsJson = json.decode(jsonString);
    return auth.ServiceAccountCredentials.fromJson(credentialsJson);
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

    ChatMessage message = ChatMessage(
      text: text,
      //name: "You",
      type: true,
    );

    setState(() {
      _messages.clear(); // Hapus semua pesan sebelumnya
      _messages.insert(0, message);
    });

    // DetectIntentResponse dataEnglish = await dialogflow.detectIntent(text, 'en-US');
    // String fulfillmentText = dataEnglish.queryResult.fulfillmentText;

    DetectIntentResponse dataIndo = await dialogflow.detectIntent(text, 'id-ID');
    String fulfillmentTextIndo = dataIndo.queryResult.fulfillmentText;
    if(fulfillmentTextIndo.isNotEmpty){
      ChatMessage botMessage = ChatMessage(
        text: fulfillmentTextIndo,
        // name: "Bot",
        type: false,
      );

      setState(() {
        _messages.insert(0, botMessage);
      });

    }
  }

  void handleStream() async {
    _recorder.start();

    //_audioStream = BehaviorSubject<List<int>>();
    _audioStream = BehaviorSubject<Uint8List>();
    _audioStreamSubscription = _recorder.audioStream.listen((data) {
      print(data);
      _audioStream.add(Uint8List.fromList(data));
    });


    // TODO Create SpeechContexts
    // Create an audio InputConfig
    var biasList = SpeechContextV2Beta1(
        phrases: [
          'Dialogflow CX',
          'Dialogflow Essentials',
          'Action Builder',
          'HIPAA'
        ],
        boost: 20.0
    );

    // See: https://cloud.google.com/dialogflow/es/docs/reference/rpc/google.cloud.dialogflow.v2#google.cloud.dialogflow.v2.InputAudioConfig
    var config = InputConfigV2beta1(
        encoding: 'AUDIO_ENCODING_LINEAR_16',
        languageCode: 'id-ID',
        sampleRateHertz: 16000,
        singleUtterance: false,
        speechContexts: [biasList]
    );

    // TODO Make the streamingDetectIntent call, with the InputConfig and the audioStream
    final responseStream = dialogflow.streamingDetectIntent(config, _audioStream);
    // TODO Get the transcript and detectedIntent and show on screen
    // Get the transcript and detectedIntent and show on screen
    responseStream.listen((data) {
      //print('----');
      setState(() {
        //print(data);
        String transcript = data.recognitionResult.transcript;
        String queryText = data.queryResult.queryText;
        String fulfillmentText = data.queryResult.fulfillmentText;

        // Mengubah teks menjadi Uint8List menggunakan encoding UTF-8
        // Uint8List transcriptBytes = Uint8List.fromList(transcript.codeUnits);
        // Uint8List queryTextBytes = Uint8List.fromList(queryText.codeUnits);
        // Uint8List fulfillmentTextBytes = Uint8List.fromList(fulfillmentText.codeUnits);

        if(fulfillmentText.isNotEmpty) {
          // ChatMessage message = new ChatMessage(
          //   text: queryText,
          //   //name: "You",
          //   type: true,
          // );

          ChatMessage botMessage = new ChatMessage(
            text: fulfillmentText,
            //name: "Sportkit",
            type: false,
          );

          // _messages.insert(0, message);
          // _textController.clear();
          // _messages.insert(0, botMessage);
          // Kondisional untuk menghapus pesan sebelumnya dan menambahkan pesan baru ke dalam daftar _messages
          if (_messages.isNotEmpty) {
            setState(() {
              _messages.clear(); // Menghapus semua pesan sebelumnya
              _textController.clear();
              _messages.insert(0, botMessage); // Menambahkan pesan baru ke dalam daftar
            });
          } else {
            setState(() {
              _messages.insert(0, botMessage); // Menambahkan pesan baru ke dalam daftar
            });
          }
        }
        if(transcript.isNotEmpty) {
          _textController.text = transcript;
        }

      });
    },onError: (e){
      //print(e);
    },onDone: () {
      //print('done');
    });

  }


  // The chat interface
  //
  //------------------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      Flexible(
          child: ListView.builder(
            padding: EdgeInsets.all(8.0),
            reverse: true,
            // itemBuilder: (_, int index) => _messages[index],
            itemBuilder: (BuildContext context, int index) {
              final reversedIndex = _messages.length - 1 - index;
              return _messages[reversedIndex];
            },
            itemCount: _messages.length,
          )),
      Divider(height: 1.0),
      Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor),
          child: IconTheme(
            data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(
                      padding: EdgeInsets.only(bottom: 15.0, left: 8, top: 15.0, right: 8.0),
                      child: FloatingActionButton(
                        onPressed: _isRecording ? stopStream : handleStream,
                        child: Icon(
                          _isRecording ? Icons.mic_off : Icons.mic,
                          size: 30,
                        ),
                      ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: EdgeInsets.only(left: 18.0), // Set the left margin here
                      child: TextField(
                        enabled: false,
                        controller: _textController,
                        onSubmitted: handleSubmitted,
                        decoration: InputDecoration.collapsed(hintText: "Output Speech To Text"),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
      ),
    ]);
  }
}


//------------------------------------------------------------------------------------
// The chat message balloon
//
//------------------------------------------------------------------------------------
class ChatMessage extends StatelessWidget {
  ChatMessage({required this.text, required this.type});

  final String text;
  // final String name;
  final bool type;

  List<Widget> otherMessage(context) {
    return <Widget>[
      // new Container(
      //   margin: const EdgeInsets.only(right: 16.0),
      //   child: CircleAvatar(child: new Text('B')),
      // ),
      Center(
        child: Card(
          // Properti untuk menyesuaikan penampilan kartu
          elevation: 4, // Ketebalan bayangan kartu
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10), // Membuat sudut kartu menjadi melengkung
          ),
          color: Colors.white, // Warna latar belakang kartu

          // Konten di dalam kartu
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              text,
              style: TextStyle(fontSize: 18),
            ),
          ),
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
            //Text(this.name, style: Theme.of(context).textTheme.subtitle1),
            Container(
              margin: const EdgeInsets.only(top: 5.0),
              child: Text(text),
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(left: 16.0),
        child: const CircleAvatar(
            // child: Text(
            //   this.name[0],
            //   style: TextStyle(fontWeight: FontWeight.bold),
            // )
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