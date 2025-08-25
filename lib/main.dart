import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'udp_listener.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("ESP32 Scale Demo")),
        body: const WeightScreen(),
      ),
    );
  }
}

class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // เรียกใช้งาน UDP Listener
    ref.watch(udpListenerProvider);

    final weight = ref.watch(weightProvider);
    return Center(
      child: Text(
        "${weight.toStringAsFixed(2)} kg",
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
      ),
    );
  }
}
