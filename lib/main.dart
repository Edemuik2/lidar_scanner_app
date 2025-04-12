import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const LidarApp());
}

const platform = MethodChannel('lidar_scanner_channel');

class LidarApp extends StatelessWidget {
  const LidarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LiDAR Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScannerHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  Future<void> _invokeMethod(String method) async {
    try {
      final result = await platform.invokeMethod(method);
      debugPrint('Method $method result: $result');
    } catch (e) {
      debugPrint('Error invoking $method: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LiDAR Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(onPressed: () => _invokeMethod('startScan'), child: const Text('Start Scan')),
            ElevatedButton(onPressed: () => _invokeMethod('stopScan'), child: const Text('Stop Scan')),
            ElevatedButton(onPressed: () => _invokeMethod('exportModel'), child: const Text('Export Model (.obj)')),
            ElevatedButton(onPressed: () => _invokeMethod('viewModelInAR'), child: const Text('View Model in AR')),
          ],
        ),
      ),
    );
  }
}
