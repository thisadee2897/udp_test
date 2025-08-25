import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:udp/udp.dart';
import 'package:network_info_plus/network_info_plus.dart';

// Model สำหรับ Device ที่พบ
class ScannedDevice {
  final String ip;
  final bool isOnline;
  final double? weight;
  final DateTime lastSeen;
  final bool isESP32;

  ScannedDevice({
    required this.ip,
    required this.isOnline,
    this.weight,
    required this.lastSeen,
    this.isESP32 = false,
  });

  ScannedDevice copyWith({
    String? ip,
    bool? isOnline,
    double? weight,
    DateTime? lastSeen,
    bool? isESP32,
  }) {
    return ScannedDevice(
      ip: ip ?? this.ip,
      isOnline: isOnline ?? this.isOnline,
      weight: weight ?? this.weight,
      lastSeen: lastSeen ?? this.lastSeen,
      isESP32: isESP32 ?? this.isESP32,
    );
  }
}

// State ของน้ำหนัก (ค่าเริ่มต้น 0.0)
final weightProvider = StateProvider<double>((ref) => 0.0);

// State ของ IP ที่เลือก
final selectedIpProvider = StateProvider<String?>((ref) => null);

// State ของรายการ device ที่สแกนพบ
final scannedDevicesProvider = StateNotifierProvider<ScannedDevicesNotifier, List<ScannedDevice>>((ref) {
  return ScannedDevicesNotifier();
});

// State สำหรับสถานะการสแกน
final isScanningProvider = StateProvider<bool>((ref) => false);

class ScannedDevicesNotifier extends StateNotifier<List<ScannedDevice>> {
  ScannedDevicesNotifier() : super([]);

  void addOrUpdateDevice(String ip, {double? weight, bool isESP32 = false}) {
    final existingIndex = state.indexWhere((device) => device.ip == ip);
    
    if (existingIndex != -1) {
      // อัปเดต device ที่มีอยู่
      state = [
        ...state.sublist(0, existingIndex),
        state[existingIndex].copyWith(
          isOnline: true,
          weight: weight ?? state[existingIndex].weight,
          lastSeen: DateTime.now(),
          isESP32: isESP32 || state[existingIndex].isESP32,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      // เพิ่ม device ใหม่
      state = [
        ...state,
        ScannedDevice(
          ip: ip,
          isOnline: true,
          weight: weight,
          lastSeen: DateTime.now(),
          isESP32: isESP32,
        ),
      ];
    }
  }

  void markDeviceOffline(String ip) {
    final existingIndex = state.indexWhere((device) => device.ip == ip);
    if (existingIndex != -1) {
      state = [
        ...state.sublist(0, existingIndex),
        state[existingIndex].copyWith(isOnline: false),
        ...state.sublist(existingIndex + 1),
      ];
    }
  }

  void clearDevices() {
    state = [];
  }
}

// Provider สำหรับ Network Scanner
final networkScannerProvider = Provider<NetworkScanner>((ref) {
  return NetworkScanner(ref);
});

// Provider ที่คอยฟัง UDP จาก ESP32
final udpListenerProvider = Provider<UDPListener>((ref) {
  final listener = UDPListener(ref);
  return listener;
});

class NetworkScanner {
  final Ref ref;
  
  NetworkScanner(this.ref);

  Future<void> scanNetwork() async {
    try {
      ref.read(isScanningProvider.notifier).state = true;
      ref.read(scannedDevicesProvider.notifier).clearDevices();

      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      
      if (wifiIP == null) {
        if (kDebugMode) print('ไม่สามารถหา IP ของ WiFi ได้');
        return;
      }

      final subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      if (kDebugMode) print('กำลังสแกน subnet: $subnet.x');

      // ลอง UDP broadcast ก่อนเพื่อหา ESP32
      await _broadcastDiscovery(subnet);
      
      // รอสักครู่ให้ ESP32 ตอบกลับ
      await Future.delayed(const Duration(seconds: 3));

      // สแกนหา device ในเครือข่าย โดยการ ping แต่ละ IP (ลดจำนวนลง)
      final List<Future<void>> scanTasks = [];
      for (int i = 1; i <= 254; i++) {
        final targetIp = '$subnet.$i';
        scanTasks.add(_pingHost(targetIp));
      }
      
      // รอให้การสแกนทั้งหมดเสร็จ
      await Future.wait(scanTasks);
      
    } catch (e) {
      if (kDebugMode) print('Error scanning network: $e');
    } finally {
      ref.read(isScanningProvider.notifier).state = false;
    }
  }

  Future<void> _broadcastDiscovery(String subnet) async {
    try {
      if (kDebugMode) print('ส่ง UDP broadcast discovery...');
      
      final udp = await UDP.bind(Endpoint.any(port: Port(0)));
      
      // ส่ง broadcast ไปยัง ESP32
      final discoveryMessage = utf8.encode("DISCOVER");
      
      await udp.send(discoveryMessage, Endpoint.broadcast(port: Port(4210)));
      
      // ฟังการตอบกลับ
      final subscription = udp.asStream().timeout(const Duration(seconds: 5)).listen(
        (datagram) {
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            final senderIp = datagram.address.address;
            
            if (kDebugMode) print('ได้รับตอบกลับจาก $senderIp: $response');
            
            if (response.contains("ESP32") || response.startsWith("WEIGHT:") || response.contains("PONG")) {
              if (response.startsWith("WEIGHT:")) {
                final weight = double.tryParse(response.split(":")[1]);
                ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(senderIp, weight: weight, isESP32: true);
              } else {
                ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(senderIp, isESP32: true);
              }
            }
          }
        },
        onError: (e) {
          if (kDebugMode) print('Broadcast discovery error: $e');
        },
      );
      
      // รอให้เสร็จแล้วปิด UDP
      await Future.delayed(const Duration(seconds: 5));
      await subscription.cancel();
      udp.close();
      
    } catch (e) {
      if (kDebugMode) print('Error in broadcast discovery: $e');
    }
  }

  Future<void> _pingHost(String ip) async {
    try {
      // ลองเชื่อมต่อ socket หลายๆ port ที่เป็นไปได้
      bool isReachable = false;
      
      // ลอง port ทั่วไป
      final commonPorts = [80, 22, 443, 8080, 3000];
      for (final port in commonPorts) {
        try {
          final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 1000));
          socket.destroy();
          isReachable = true;
          break;
        } catch (e) {
          // ลองต่อ port ถัดไป
        }
      }
      
      if (isReachable) {
        if (kDebugMode) print('พบ device: $ip');
        ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(ip);
      }
      
      // ลอง UDP ping เพื่อตรวจสอบ ESP32
      await _checkIfESP32(ip);
    } catch (e) {
      // ลอง UDP ping แม้ TCP ping ไม่สำเร็จ
      await _checkIfESP32(ip);
    }
  }

  Future<void> _checkIfESP32(String ip) async {
    try {
      // ส่ง UDP discovery message ไปยัง ESP32
      final udp = await UDP.bind(Endpoint.any(port: Port(0)));
      
      // ส่งข้อความ discovery
      final discoveryMessage = utf8.encode("DISCOVER");
      await udp.send(discoveryMessage, Endpoint.unicast(
        InternetAddress(ip),
        port: Port(4210),
      ));
      
      // รอการตอบกลับเป็นเวลา 2 วินาที
      bool foundESP32 = false;
      final subscription = udp.asStream().timeout(const Duration(seconds: 2)).listen(
        (datagram) {
          if (datagram != null) {
            final response = utf8.decode(datagram.data);
            final senderIp = datagram.address.address;
            
            if (senderIp == ip && (response.contains("ESP32") || response.startsWith("WEIGHT:") || response.contains("PONG"))) {
              foundESP32 = true;
              if (kDebugMode) print('พบ ESP32: $ip (ตอบกลับ: $response)');
              
              // ถ้าได้ข้อมูลน้ำหนักมาด้วย
              if (response.startsWith("WEIGHT:")) {
                final weight = double.tryParse(response.split(":")[1]);
                ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(ip, weight: weight, isESP32: true);
              } else {
                ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(ip, isESP32: true);
              }
            }
          }
        },
        onError: (e) {
          // Timeout หรือ error อื่นๆ
        },
      );
      
      // รอให้เสร็จแล้วปิด UDP
      await Future.delayed(const Duration(seconds: 2));
      await subscription.cancel();
      udp.close();
      
      if (!foundESP32 && kDebugMode) {
        // ไม่ต้อง print ข้อความ error เพราะจะมีเยอะเกินไป
      }
      
    } catch (e) {
      // ไม่ต้อง print error เพราะจะมีเยอะเกินไป
    }
  }
}

class UDPListener {
  final Ref ref;
  UDP? receiver;
  
  UDPListener(this.ref);

  Future<void> start() async {
    final selectedIp = ref.read(selectedIpProvider);
    if (selectedIp == null) return;

    try {
      // ปิด listener เก่าถ้ามี
      await stop();
      
      receiver = await UDP.bind(Endpoint.any(port: Port(4210)));

      receiver!.asStream().listen((datagram) {
        if (datagram != null) {
          String msg = utf8.decode(datagram.data);
          final senderIp = datagram.address.address;
          
          // ต้องเช็คว่า IP ของ datagram ตรงกับ selectedIp ที่เลือกไว้
          final currentSelectedIp = ref.read(selectedIpProvider);
          
          if (msg.startsWith("WEIGHT:") && currentSelectedIp != null && senderIp == currentSelectedIp) {
            // อัปเดตน้ำหนักเฉพาะเมื่อ IP ตรงกับที่เลือกไว้
            final value = double.tryParse(msg.split(":")[1]) ?? 0.0;
            ref.read(weightProvider.notifier).state = value;
            
            // อัปเดตข้อมูล device ที่ส่งข้อมูลมา
            ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(senderIp, weight: value, isESP32: true);
          } else if (msg.startsWith("WEIGHT:")) {
            // ถ้า IP ไม่ตรงกับที่เลือก แค่อัปเดตข้อมูล device แต่ไม่อัปเดตน้ำหนัก
            final value = double.tryParse(msg.split(":")[1]) ?? 0.0;
            ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(senderIp, weight: value, isESP32: true);
          }
        }
      });

      if (kDebugMode) print('เริ่มฟัง UDP บน port 4210');
    } catch (e) {
      if (kDebugMode) print('Error starting UDP listener: $e');
    }
  }

  Future<void> stop() async {
    if (receiver != null) {
      receiver!.close();
      receiver = null;
      if (kDebugMode) print('หยุด UDP listener');
    }
  }
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ESP32 Scale Scanner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("ESP32 Scale Scanner"),
        ),
        body: DeviceScannerTab(),
      ),
    );
  }
}

class DeviceScannerTab extends ConsumerStatefulWidget {
  const DeviceScannerTab({super.key});

  @override
  ConsumerState<DeviceScannerTab> createState() => _DeviceScannerTabState();
}

class _DeviceScannerTabState extends ConsumerState<DeviceScannerTab> {
  UDP? scannerUdp;

  @override
  void initState() {
    super.initState();
    // เริ่มการสแกนอัตโนมัติเมื่อเข้าหน้า
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScanning();
    });
  }

  @override
  void dispose() {
    _stopUdpListener();
    super.dispose();
  }

  Future<void> _startAutoScanning() async {
    // เริ่ม UDP listener เพื่อฟังข้อมูลจาก ESP32
    await _startUdpListener();
    
    // ทำการสแกนอัตโนมัติ
    final networkScanner = ref.read(networkScannerProvider);
    networkScanner.scanNetwork();
  }

  Future<void> _startUdpListener() async {
    try {
      await _stopUdpListener();
      
      scannerUdp = await UDP.bind(Endpoint.any(port: Port(4210)));
      
      scannerUdp!.asStream().listen((datagram) {
        if (datagram != null) {
          String msg = utf8.decode(datagram.data);
          final senderIp = datagram.address.address;
          
          // if (kDebugMode) print('ได้รับ UDP จาก $senderIp: $msg');
          
          if (msg.startsWith("WEIGHT:")) {
            final value = double.tryParse(msg.split(":")[1]) ?? 0.0;
            
            // เช็คว่า IP ตรงกับที่เลือกไว้ก่อนอัปเดตน้ำหนัก
            final currentSelectedIp = ref.read(selectedIpProvider);
            if (currentSelectedIp != null && senderIp == currentSelectedIp) {
              ref.read(weightProvider.notifier).state = value; // อัปเดต weight provider เฉพาะเมื่อ IP ตรงกัน
            }
            
            // อัปเดตข้อมูล device เสมอ (ไม่ว่าจะเลือกหรือไม่)
            ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(senderIp, weight: value, isESP32: true);
          } else if (msg.contains("ESP32") || msg.contains("PONG")) {
            ref.read(scannedDevicesProvider.notifier).addOrUpdateDevice(senderIp, isESP32: true);
          }
        }
      });

      if (kDebugMode) print('เริ่มฟัง UDP บน port 4210 ในหน้าสแกน');
    } catch (e) {
      if (kDebugMode) print('Error starting scanner UDP listener: $e');
    }
  }

  Future<void> _stopUdpListener() async {
    if (scannerUdp != null) {
      scannerUdp!.close();
      scannerUdp = null;
      if (kDebugMode) print('หยุด scanner UDP listener');
    }
  }

  Future<void> _sendBroadcastPing() async {
    try {
      final tempUdp = await UDP.bind(Endpoint.any(port: Port(0)));
      
      // ส่ง ping message
      final pingMessage = utf8.encode("PING");
      await tempUdp.send(pingMessage, Endpoint.broadcast(port: Port(4210)));
      
      if (kDebugMode) print('ส่ง broadcast ping แล้ว');
      
      tempUdp.close();
      
    } catch (e) {
      if (kDebugMode) print('Error sending broadcast ping: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = ref.watch(isScanningProvider);
    final devices = ref.watch(scannedDevicesProvider);
    final selectedIp = ref.watch(selectedIpProvider);
    final currentWeight = ref.watch(weightProvider);
    final networkScanner = ref.watch(networkScannerProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // แสดงน้ำหนักปัจจุบัน
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.monitor_weight, color: Colors.blue, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'น้ำหนักปัจจุบัน',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '${currentWeight.toStringAsFixed(2)} kg',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // ปุ่มสแกน
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isScanning ? null : () {
                    networkScanner.scanNetwork();
                  },
                  icon: isScanning 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                  label: Text(isScanning ? 'กำลังสแกน...' : 'สแกนใหม่'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isScanning ? null : () {
                  _sendBroadcastPing();
                },
                icon: const Icon(Icons.wifi_find),
                label: const Text('Ping'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // รายการ device ที่พบ
          Expanded(
            child: devices.isEmpty
              ? Center(
                  child: Text(
                    isScanning 
                      ? 'กำลังค้นหา device ในเครือข่าย...'
                      : 'กดปุ่มสแกนเพื่อค้นหา ESP32',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final isSelected = selectedIp == device.ip;
                    
                    return Card(
                      elevation: isSelected ? 4 : 1,
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: device.isOnline 
                            ? (device.isESP32 ? Colors.green : Colors.orange)
                            : Colors.grey,
                          child: Icon(
                            device.isESP32 
                              ? Icons.scale 
                              : Icons.device_unknown,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          device.ip,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.isESP32 
                                ? 'ESP32 Scale (Port 4210 เปิดอยู่)'
                                : 'อุปกรณ์ทั่วไป',
                              style: TextStyle(
                                color: device.isESP32 ? Colors.green : Colors.grey,
                              ),
                            ),
                            if (device.weight != null)
                              Text(
                                'น้ำหนัก: ${device.weight!.toStringAsFixed(2)} kg',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            Text(
                              'สถานะ: ${device.isOnline ? "ออนไลน์" : "ออฟไลน์"}',
                              style: TextStyle(
                                color: device.isOnline ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                        onTap: device.isESP32 ? () {
                          // รีเซ็ตน้ำหนักเป็น 0.0 เมื่อเลือก IP ใหม่
                          ref.read(weightProvider.notifier).state = 0.0;
                          ref.read(selectedIpProvider.notifier).state = device.ip;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('เลือก ESP32: ${device.ip}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } : null,
                      ),
                    );
                  },
                ),
          ),
          
          // แสดง IP ที่เลือก
          if (selectedIp != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'เชื่อมต่อกับ: $selectedIp',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // ยกเลิกการเลือกและรีเซ็ตน้ำหนักเป็น 0.0
                      ref.read(selectedIpProvider.notifier).state = null;
                      ref.read(weightProvider.notifier).state = 0.0;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ยกเลิกการเลือก ESP32 แล้ว'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear, color: Colors.red),
                    tooltip: 'ยกเลิกการเลือก',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}