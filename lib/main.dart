import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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

class ChartData {
  ChartData(this.time, this.value);
  final DateTime time;
  final double value;
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
  String _incomingBuffer = '';

  // Chart
  List<ChartData> chartData = [];
  ChartSeriesController? _chartController;

  @override
  void initState() {
    super.initState();
    final available = SerialPort.availablePorts;
    ports = available;
    if (available.isNotEmpty) selectedPort = available.first;
  }

  void _connectOrDisconnect() {
    if (isConnected) {
      _readSubscription?.cancel();
      port?.close();
      port = null;
      isConnected = false;
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
      _readSubscription = reader.stream.listen(_handleSerialData);


      port = p;
      isConnected = true;
    }
    setState(() {});
  }

  void _handleSerialData(Uint8List data) {
  _incomingBuffer += String.fromCharCodes(data);

  int newlineIndex;
  while ((newlineIndex = _incomingBuffer.indexOf('\n')) != -1) {
    final line = _incomingBuffer.substring(0, newlineIndex).trim();
    _incomingBuffer = _incomingBuffer.substring(newlineIndex + 1);

    if (line.isNotEmpty) {
      _appendToLog(line);
      _addChartPoint(line);
      }
    }
  }


  void _appendToLog(String text) {
    setState(() {
      _logLines.add(text);
      if (_logLines.length > 500) _logLines = _logLines.sublist(_logLines.length - 500);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

DateTime _lastChartUpdate = DateTime.now();

void _addChartPoint(String text) {
  final value = double.tryParse(text);
  if (value == null) {
    print('Ignored non-numeric data: $text');
    return;
  }

  // Limit rate for the graph
  final now = DateTime.now();
  if(now.difference(_lastChartUpdate).inMilliseconds < 33){
    return; // limit to ~30fps (1000/33ms)
  }
  _lastChartUpdate = now;
  //Comment section above to remove limited update rate for graph


  print('Adding chart value: $value');
  final point = ChartData(DateTime.now(), value);
  chartData.add(point);
  if (chartData.length > 1000) chartData.removeAt(0);

  if (_chartController != null) {
    if (chartData.length == 1000) {
      _chartController!.updateDataSource(
        addedDataIndex: chartData.length - 1,
        removedDataIndex: 0,
      );
    } else {
      _chartController!.updateDataSource(
        addedDataIndex: chartData.length - 1,
      );
    }
  }
}


  @override
  void dispose() {
    _readSubscription?.cancel();
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
                items: ports.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => selectedPort = v),
              ),
              const SizedBox(height: 16),
              const Text('Baud Rate'),
              const SizedBox(height: 8),
              DropdownButton<int>(
                isExpanded: true,
                value: selectedBaudRate,
                items: baudRates.map((r) => DropdownMenuItem(value: r, child: Text('$r'))).toList(),
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
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                isConnected ? 'Connected: $selectedPort @ $selectedBaudRate' : 'Not Connected',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Expanded(
                flex: 2,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(),
                  series: <LineSeries<ChartData, DateTime>>[
                    LineSeries<ChartData, DateTime>(
                      dataSource: chartData,
                      animationDuration: 0, //sets the animation of the chart 0 (no animation)
                      xValueMapper: (d, _) => d.time,
                      yValueMapper: (d, _) => d.value,
                      onRendererCreated: (controller) => _chartController = controller,
                    ),
                  ],
                ),
              ),
              // const SizedBox(height: 10),
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                  // color: const Color.fromARGB(255, 255, 255, 255),
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _logLines.length,
                      itemBuilder: (_, i) => Text(_logLines[i],
                        style: const TextStyle(
                          color: Colors.black87, fontFamily: 'Courier', fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ]),
    );
  }
}
