import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LidarScannerApp());
}

class LidarScannerApp extends StatelessWidget {
  const LidarScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiDAR Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('lidar_scanner');
  bool isScanning = false;

  Future<void> startScan() async {
    try {
      await platform.invokeMethod('startScan');
      setState(() => isScanning = true);
    } on PlatformException catch (e) {
      debugPrint("Error starting scan: '${e.message}'.");
    }
  }

  Future<void> stopScan() async {
    try {
      await platform.invokeMethod('stopScan');
      setState(() => isScanning = false);
    } on PlatformException catch (e) {
      debugPrint("Error stopping scan: '${e.message}'.");
    }
  }

  Future<void> exportModel() async {
    try {
      await platform.invokeMethod('exportModel');
    } on PlatformException catch (e) {
      debugPrint("Error exporting model: '${e.message}'.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LiDAR 3D Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: isScanning ? null : startScan,
              child: const Text('Начать сканирование'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isScanning ? stopScan : null,
              child: const Text('Остановить сканирование'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: exportModel,
              child: const Text('Экспортировать .obj в Файлы'),
            ),
          ],
        ),
      ),
    );
  }
}
