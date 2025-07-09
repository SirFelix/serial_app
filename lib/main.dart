//Basic Serial Port reader
//Working code for serial port coms, baudrate, connect button, and a live readout of the information coming over the serial port
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

void main() => runApp(const MainApp());

class MainApp extends StatelessWidget {
  const MainApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SerialApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SerialApp extends StatefulWidget {
  const SerialApp({super.key});
  @override
  State<SerialApp> createState() => _SerialAppState();
}

class _SerialAppState extends State<SerialApp> {
  List<String> ports = [];
  List<int> baudRates = [9600, 19200, 38400, 57600, 115200];
  String? selectedPort;
  int selectedBaudRate = 115200;
  bool isConnected = false;

  SerialPort? port;
  StreamSubscription<Uint8List>? _readSubscription;
  final ScrollController _scrollController = ScrollController();
  List<String> _logLines = [];


  @override
  void initState() {
    super.initState();
    final available = SerialPort.availablePorts;
    print('Available ports: $available');
    setState(() {
      ports = available;
      if (available.isNotEmpty) selectedPort = available.first;
    });
  }

  void _connectOrDisconnect() {
    if (isConnected) {
      _readSubscription?.cancel();
      _readSubscription = null;
      port?.close();
      port = null;
      setState(() => isConnected = false);
    } else {
      if (selectedPort == null) return;

      final p = SerialPort(selectedPort!);
      if (!p.openReadWrite()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Port error: ${SerialPort.lastError}')),
        );
        return;
      }

      final config = SerialPortConfig()
        ..baudRate = selectedBaudRate
        ..bits = 8
        ..parity = SerialPortParity.none
        ..stopBits = 1;
      p.config = config;

      final reader = SerialPortReader(p);
      _readSubscription = reader.stream.listen((data) {
        final text = String.fromCharCodes(data);
        _appendToLog(text);
      });

      setState(() {
        port = p;
        isConnected = true;
      });
    }
  }

void _appendToLog(String text) {
  final lines = text.split('\n');
  setState(() {
    _logLines.addAll(lines);
    // Limit to last 500 lines
    if (_logLines.length > 500) {
      _logLines = _logLines.sublist(_logLines.length - 500);
    }
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  });
}



  @override
  void dispose() {
    _readSubscription?.cancel();
    _scrollController.dispose();
    port?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        Container(
          width: 250,
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Serial Port'),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedPort,
                items: ports
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => selectedPort = v),
              ),
              const SizedBox(height: 16),
              const Text('Baud Rate'),
              const SizedBox(height: 8),
              DropdownButton<int>(
                isExpanded: true,
                value: selectedBaudRate,
                items: baudRates
                    .map((r) => DropdownMenuItem(value: r, child: Text('$r')))
                    .toList(),
                onChanged: (v) => setState(() => selectedBaudRate = v!),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _connectOrDisconnect,
                child: Text(isConnected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8),
            color: Colors.black,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logLines.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logLines[index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
