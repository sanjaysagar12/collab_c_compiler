import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

void main() {
  runApp(CollabCompilerApp());
}

class CollabCompilerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collaborative C Compiler',
      theme: ThemeData.dark(),
      home: CompilerScreen(),
    );
  }
}

class CompilerScreen extends StatefulWidget {
  @override
  _CompilerScreenState createState() => _CompilerScreenState();
}

class _CompilerScreenState extends State<CompilerScreen> {
  final codeController = TextEditingController();
  String output = "Output will appear here...";
  late IOWebSocketChannel socket;

  @override
  void initState() {
    super.initState();

    // Change this to your local IP if testing on real mobile over WiFi
    socket = IOWebSocketChannel.connect("ws://collab-c-compiler.selfmade.one");

    socket.stream.listen((message) {
      if (message != codeController.text) {
        setState(() {
          codeController.text = message;
        });
      }
    });

    codeController.addListener(() {
      socket.sink.add(codeController.text);
    });
  }

  Future<void> runCode() async {
    final res = await http.post(
      Uri.parse("https://collab-c-compiler.selfmade.one/run"),
      headers: {'Content-Type': 'text/plain'},
      body: codeController.text,
    );

    setState(() {
      output = res.body;
    });
  }

  @override
  void dispose() {
    socket.sink.close();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('C Compiler (Mobile)'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: screenHeight * 0.4,
              child: TextField(
                controller: codeController,
                maxLines: null,
                expands: true,
                style: TextStyle(fontFamily: 'Courier'),
                decoration: InputDecoration(
                  hintText: 'Write C code here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.play_arrow),
                label: Text("Run Code"),
                onPressed: runCode,
              ),
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              height: screenHeight * 0.3,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.black,
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  output,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.greenAccent,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
