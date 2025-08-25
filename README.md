# udp_test

# ESP32 Scale Scanner

# ESP32 Scale Scanner with Riverpod

แอปพลิเคชัน Flutter ที่ใช้ **Riverpod** สำหรับสแกนหาและเชื่อมต่อกับ ESP32 ที่ส่งข้อมูลน้ำหนักผ่าน UDP แบบเรียลไทม์

## ✨ ฟีเจอร์หลัก

### 📱 แอป Flutter
- **🔍 สแกนหา ESP32**: สแกนหาอุปกรณ์ในเครือข่าย WiFi ที่เปิด port 4210
- **📋 รายการอุปกรณ์**: แสดงรายการ IP ที่พบพร้อมสถานะเรียลไทม์
- **🎯 เลือกเชื่อมต่อ**: เลือก ESP32 ที่ต้องการเชื่อมต่อด้วยตัวเอง
- **⚖️ แสดงน้ำหนัก**: แสดงค่าน้ำหนักแบบเรียลไทม์จาก ESP32 ที่เลือก
- **🔄 อัปเดตสด**: อัปเดตข้อมูลอุปกรณ์และน้ำหนักแบบเรียลไทม์
- **🏗️ Riverpod Architecture**: ใช้ State Management ที่ทันสมัย

### 🔧 ESP32
- ส่งข้อมูลน้ำหนักผ่าน UDP broadcast
- รองรับการเชื่อมต่อ WiFi
- จำลองข้อมูลน้ำหนักหรือใช้ Load Cell จริง

## 🚀 การติดตั้งและใช้งาน

### 1. ESP32 Setup
1. เปิดไฟล์ `esp32_code/esp32_scale.ino` ใน Arduino IDE
2. แก้ไข WiFi credentials:
   ```cpp
   const char* ssid = "YOUR_WIFI_SSID";          // ชื่อ WiFi ของคุณ
   const char* password = "YOUR_WIFI_PASSWORD";  // รหัสผ่าน WiFi ของคุณ
   ```
3. อัปโหลดโค้ดลง ESP32
4. เปิด Serial Monitor เพื่อดู IP address ของ ESP32

### 2. Flutter App Setup
1. Clone โปรเจค:
   ```bash
   git clone [your-repository-url]
   cd udp_test
   ```

2. ติดตั้ง dependencies:
   ```bash
   flutter pub get
   ```

3. รันแอป:
   ```bash
   flutter run
   ```

## 📱 การใช้งาน

### แท็บ "สแกน" 🔍
1. กดปุ่ม **"สแกนหา ESP32"** เพื่อค้นหาอุปกรณ์ในเครือข่าย
2. รอให้การสแกนเสร็จสิ้น (จะแสดงรายการ IP ที่พบ)
3. อุปกรณ์ที่เป็น ESP32 จะแสดง:
   - ไอคอนเครื่องชั่ง ⚖️
   - ข้อความ "ESP32 Scale (Port 4210 เปิดอยู่)"
   - สีเขียวเมื่อพร้อมใช้งาน
4. **แตะเลือก ESP32** ที่ต้องการเชื่อมต่อ
5. จะมีแสดงสถานะ "เชื่อมต่อกับ: [IP]" ด้านล่าง

### แท็บ "น้ำหนัก" ⚖️
1. แสดงน้ำหนักปัจจุบันจาก ESP32 ที่เลือก (ขนาดใหญ่)
2. แสดงสถานะการเชื่อมต่อ
3. แสดงรายการอุปกรณ์ทั้งหมดที่ส่งข้อมูลมาแบบเรียลไทม์
4. แสดงเวลาที่อัปเดตล่าสุดของแต่ละอุปกรณ์

## 🏗️ Architecture

### Riverpod State Management
```dart
// State Providers
final weightProvider = StateProvider<double>           // น้ำหนักปัจจุบัน
final selectedIpProvider = StateProvider<String?>      // IP ที่เลือก
final isScanningProvider = StateProvider<bool>         // สถานะการสแกน

// StateNotifier Provider
final scannedDevicesProvider = StateNotifierProvider   // รายการอุปกรณ์

// Service Providers  
final networkScannerProvider = Provider<NetworkScanner> // ตัวสแกนเครือข่าย
final udpListenerProvider = Provider<UDPListener>       // UDP listener
```

### คลาสหลัก
- **`ScannedDevice`**: Model สำหรับอุปกรณ์ที่พบ
- **`ScannedDevicesNotifier`**: จัดการ state ของรายการอุปกรณ์
- **`NetworkScanner`**: จัดการการสแกนเครือข่าย
- **`UDPListener`**: จัดการการรับส่งข้อมูล UDP

## ⚙️ การทำงาน

1. **การสแกน**: แอปจะสแกน IP ในเครือข่าย WiFi เดียวกันทั้งหมด (192.168.x.1-254)
2. **การตรวจสอบ ESP32**: ลองเชื่อมต่อ port 4210 เพื่อยืนยันว่าเป็น ESP32
3. **การรับข้อมูล**: รับข้อมูลรูปแบบ `"WEIGHT:xx.xx"` ผ่าน UDP
4. **การอัปเดต**: อัปเดตข้อมูลอุปกรณ์และน้ำหนักแบบเรียลไทม์ผ่าน Riverpod

## 📋 ข้อกำหนด

### Flutter App
- **Flutter SDK**: 3.7.2+
- **Dart**: 3.0+
- **Dependencies**:
  - `flutter_riverpod: ^2.4.9` - State Management
  - `udp: ^5.0.3` - UDP Communication  
  - `network_info_plus: ^6.0.0` - Network Information

### ESP32
- ESP32 DevKit
- Arduino IDE with ESP32 support
- WiFi connection
- (Optional) HX711 + Load Cell สำหรับการวัดน้ำหนักจริง

## 🔧 การปรับแต่ง

### ESP32
- **เปลี่ยน UDP port**: แก้ไข `udpPort = 4210` และใน Flutter app
- **เพิ่ม Load Cell จริง**: uncomment โค้ดส่วน HX711 ในไฟล์ .ino
- **ปรับความถี่ส่งข้อมูล**: แก้ไข `sendInterval = 1000` (milliseconds)

### Flutter App
- **ปรับช่วง IP สแกน**: แก้ไขลูป `for (int i = 1; i <= 254; i++)`
- **เปลี่ยน timeout**: แก้ไข `Duration` ในฟังก์ชัน `_pingHost` และ `_checkIfESP32`
- **ปรับ UI**: แก้ไข Widget ต่าง ๆ ใน `main.dart`

## 📝 Protocol

### UDP Message Format
ESP32 ส่งข้อมูลในรูปแบบ:
```
WEIGHT:[value]
```

ตัวอย่าง:
```
WEIGHT:12.34
WEIGHT:0.00
WEIGHT:156.78
```

## 🎯 การทดสอบ

1. **ทดสอบการสแกน**: เปิดแอปและกดสแกน ควรพบอุปกรณ์ในเครือข่าย
2. **ทดสอบ ESP32**: อัปโหลดโค้ด ESP32 และตรวจสอบ Serial Monitor
3. **ทดสอบการเชื่อมต่อ**: เลือก ESP32 ในแอปและดูข้อมูลน้ำหนัก
4. **ทดสอบเรียลไทม์**: ข้อมูลควรอัปเดตทุกวินาที

## 🚨 หมายเหตุสำคัญ

- ESP32 และ Flutter app **ต้องอยู่ในเครือข่าย WiFi เดียวกัน**
- แอปใช้การเชื่อมต่อ socket เพื่อตรวจสอบ ESP32 ซึ่งอาจใช้เวลาสักครู่
- ข้อมูลน้ำหนักจะอัปเดตทุกวินาทีตามการตั้งค่าใน ESP32
- หาก ESP32 ไม่ปรากฏในรายการ ให้ตรวจสอบ:
  - WiFi connection
  - Port 4210 เปิดอยู่หรือไม่
  - Serial Monitor ของ ESP32

## 🎉 Features Completed

- ✅ **Riverpod State Management** - ใช้ Provider pattern
- ✅ **Network Scanning** - สแกนหา IP ในเครือข่าย
- ✅ **ESP32 Detection** - ตรวจสอบ port 4210
- ✅ **Device Selection** - เลือก IP ที่ต้องการเชื่อมต่อ
- ✅ **Real-time Weight Display** - แสดงน้ำหนักแบบเรียลไทม์
- ✅ **Multiple Device Support** - รองรับหลายอุปกรณ์พร้อมกัน
- ✅ **Modern UI** - Material Design 3
- ✅ **Tab Navigation** - แยกหน้าสแกนและแสดงผล

พร้อมใช้งานเต็มรูปแบบแล้ว! 🚀

## ฟีเจอร์หลัก

### 📱 แอป Flutter
- **สแกนหา ESP32**: สแกนหาอุปกรณ์ในเครือข่าย WiFi ที่เปิด port 4210
- **รายการอุปกรณ์**: แสดงรายการ IP ที่พบพร้อมสถานะเรียลไทม์
- **เลือกเชื่อมต่อ**: เลือก ESP32 ที่ต้องการเชื่อมต่อ
- **แสดงน้ำหนัก**: แสดงค่าน้ำหนักแบบเรียลไทม์จาก ESP32 ที่เลือก
- **อัปเดตสด**: อัปเดตข้อมูลอุปกรณ์และน้ำหนักแบบเรียลไทม์

### 🔧 ESP32
- ส่งข้อมูลน้ำหนักผ่าน UDP broadcast
- รองรับการเชื่อมต่อ WiFi
- จำลองข้อมูลน้ำหนักหรือใช้ Load Cell จริง

## การติดตั้งและใช้งาน

### 1. ESP32
1. เปิดไฟล์ `esp32_code/esp32_scale.ino` ใน Arduino IDE
2. แก้ไข WiFi credentials:
   ```cpp
   const char* ssid = "YOUR_WIFI_SSID";
   const char* password = "YOUR_WIFI_PASSWORD";
   ```
3. อัปโหลดโค้ดลง ESP32
4. เปิด Serial Monitor เพื่อดู IP address ของ ESP32

### 2. Flutter App
1. ติดตั้ง dependencies:
   ```bash
   flutter pub get
   ```
2. รันแอป:
   ```bash
   flutter run
   ```

## การใช้งาน

### แท็บ "สแกน"
1. กดปุ่ม **"สแกนหา ESP32"** เพื่อค้นหาอุปกรณ์ในเครือข่าย
2. รอให้การสแกนเสร็จสิ้น (จะแสดงรายการ IP ที่พบ)
3. อุปกรณ์ที่เป็น ESP32 จะแสดงไอคอนเครื่องชั่งและข้อความ "ESP32 Scale"
4. แตะเลือก ESP32 ที่ต้องการเชื่อมต่อ

### แท็บ "น้ำหนัก"
1. แสดงน้ำหนักปัจจุบันจาก ESP32 ที่เลือก
2. แสดงสถานะการเชื่อมต่อ
3. แสดงรายการอุปกรณ์ทั้งหมดที่ส่งข้อมูลมา

## โครงสร้างโค้ด

### Riverpod Providers
- `weightProvider`: เก็บค่าน้ำหนักปัจจุบัน
- `selectedIpProvider`: เก็บ IP ที่เลือกเชื่อมต่อ
- `scannedDevicesProvider`: เก็บรายการอุปกรณ์ที่สแกนพบ
- `isScanningProvider`: สถานะการสแกน
- `networkScannerProvider`: สำหรับสแกนเครือข่าย
- `udpListenerProvider`: สำหรับรับข้อมูล UDP

### คลาสหลัก
- `ScannedDevice`: Model สำหรับอุปกรณ์ที่พบ
- `NetworkScanner`: จัดการการสแกนเครือข่าย
- `UDPListener`: จัดการการรับส่งข้อมูล UDP

## การทำงาน

1. **การสแกน**: แอปจะสแกน IP ในเครือข่าย WiFi เดียวกันทั้งหมด (192.168.x.1-254)
2. **การตรวจสอบ ESP32**: ลองเชื่อมต่อ port 4210 เพื่อยืนยันว่าเป็น ESP32
3. **การรับข้อมูล**: รับข้อมูลรูปแบบ "WEIGHT:xx.xx" ผ่าน UDP
4. **การอัปเดต**: อัปเดตข้อมูลอุปกรณ์และน้ำหนักแบบเรียลไทม์

## ข้อกำหนด

### Flutter App
- Flutter SDK 3.7.2+
- Dart 3.0+
- Dependencies:
  - flutter_riverpod: ^2.4.9
  - udp: ^5.0.3
  - network_info_plus: ^6.0.0

### ESP32
- ESP32 DevKit
- Arduino IDE with ESP32 support
- WiFi connection
- (Optional) HX711 + Load Cell สำหรับการวัดน้ำหนักจริง

## การปรับแต่ง

### ESP32
- เปลี่ยน port UDP: แก้ไข `udpPort` และใน Flutter app
- เพิ่ม Load Cell จริง: uncomment โค้ดส่วน HX711
- ปรับความถี่การส่งข้อมูล: แก้ไข `sendInterval`

### Flutter App
- ปรับช่วง IP สแกน: แก้ไขลูป `for (int i = 1; i <= 254; i++)`
- เปลี่ยน timeout: แก้ไข `Duration` ในฟังก์ชัน `_pingHost`
- ปรับ UI: แก้ไขใน `main.dart`

## หมายเหตุ

- ESP32 และ Flutter app ต้องอยู่ในเครือข่าย WiFi เดียวกัน
- แอปใช้การเชื่อมต่อ socket เพื่อตรวจสอบ ESP32 ซึ่งอาจใช้เวลาสักครู่
- ข้อมูลน้ำหนักจะอัปเดตทุกวินาทีตามการตั้งค่าใน ESP32
