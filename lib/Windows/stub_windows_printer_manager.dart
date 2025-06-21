
import 'package:flutter_thermal_printer/utils/printer.dart';

class WindowPrinterManager {

  WindowPrinterManager._privateConstructor();

  static WindowPrinterManager? _instance;

  static WindowPrinterManager get instance {
    _instance ??= WindowPrinterManager._privateConstructor();
    return _instance!;
  }


  Stream<List<Printer>> get devicesStream =>const Stream.empty();

  // Stop scanning for BLE devices
  Future<void> stopscan() async { return Future.value(); }

  // Connect to a BLE device
  Future<bool> connect(Printer device) async { return Future.value(false); }

  // Print data to a BLE device
  Future<bool> printData(
      Printer device,
      List<int> bytes, {
        bool longData = false,
        WindowsLib version = WindowsLib.V1
      }) async {
    return Future.value(false);
  }

  Future<bool> isPaired(String address) async{
    return Future.value(false);
  }

  // Getprinters
  void getPrinters({
    Duration refreshDuration = const Duration(seconds: 10),
    List<ConnectionType> connectionTypes = const [
      ConnectionType.BLE,
      ConnectionType.USB,
    ],
    WindowsLib version = WindowsLib.V1
  }) async {}

  turnOnBluetooth() async {
  }

  Stream<bool> isBleTurnedOnStream = Stream.value(false);

  Future<bool> isBleTurnedOn() async {
    return Future.value(false);
  }

  void dispose(){
  }
}