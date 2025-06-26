import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

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
  IO.Socket? socket;
  bool isConnected = false;
  String connectionStatus = "Connecting...";

  @override
  void initState() {
    super.initState();
    _connectSocket();
    
    codeController.addListener(() {
      if (isConnected && socket != null) {
        try {
          socket!.emit('codeChange', codeController.text);
        } catch (e) {
          // Silent error handling for production
        }
      }
    });
  }

  void _connectSocket() {
    try {
      setState(() {
        connectionStatus = "Connecting...";
        isConnected = false;
      });

      // Close existing connection if any
      socket?.disconnect();

      socket = IO.io('https://collab-c-compiler.selfmade.one', 
        IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .setTimeout(15000)
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build()
      );

      socket!.onConnect((_) {
        setState(() {
          isConnected = true;
          connectionStatus = "Connected";
        });
      });

      socket!.on('codeUpdate', (data) {
        if (data != codeController.text) {
          setState(() {
            codeController.text = data.toString();
          });
        }
      });

      socket!.onDisconnect((_) {
        setState(() {
          isConnected = false;
          connectionStatus = "Disconnected";
        });
        _scheduleReconnect();
      });

      socket!.onConnectError((error) {
        setState(() {
          isConnected = false;
          connectionStatus = "Connection failed";
        });
        _scheduleReconnect();
      });

      socket!.onError((error) {
        setState(() {
          isConnected = false;
          connectionStatus = "Connection error";
        });
      });

      socket!.connect();

    } catch (e) {
      setState(() {
        isConnected = false;
        connectionStatus = "Failed to connect";
      });
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    Future.delayed(Duration(seconds: 5), () {
      if (!isConnected && mounted) {
        _connectSocket();
      }
    });
  }

  Future<void> runCode() async {
    try {
      final response = await http.post(
        Uri.parse("https://collab-c-compiler.selfmade.one/run"),
        headers: {'Content-Type': 'text/plain'},
        body: codeController.text,
      );

      setState(() {
        output = response.body;
      });
    } catch (e) {
      setState(() {
        output = "Error connecting to server: $e";
      });
    }
  }

  @override
  void dispose() {
    socket?.disconnect();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text('Collaborative C Compiler'),
        centerTitle: true,
        actions: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            color: isConnected ? Colors.green : Colors.red,
          ),
          SizedBox(width: 16)
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
            child: Text(
              connectionStatus,
              style: TextStyle(
                color: isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
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
          ),
        ],
      ),
    );
  }
}
