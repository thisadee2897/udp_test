import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:udp/udp.dart';

// State ของน้ำหนัก
final weightProvider = StateProvider<double>((ref) => 0.0);

// Provider ที่คอยฟัง UDP จาก ESP32
final udpListenerProvider = Provider<UDPListener>((ref) {
  final listener = UDPListener(ref);
  listener.start();
  return listener;
});

class UDPListener {
  final Ref ref;
  UDPListener(this.ref);

  Future<void> start() async {
    var receiver = await UDP.bind(Endpoint.any(port: Port(4210)));

    receiver.asStream().listen((datagram) {
      if (datagram != null) {
        String msg = utf8.decode(datagram.data);
        if (msg.startsWith("WEIGHT:")) {
          final value = double.tryParse(msg.split(":")[1]) ?? 0.0;
          ref.read(weightProvider.notifier).state = value;
        }
      }
    });
  }
}
