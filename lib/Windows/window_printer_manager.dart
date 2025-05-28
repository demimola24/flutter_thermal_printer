import 'dart:async';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:print_usb/model/usb_device.dart';
import 'package:print_usb/print_usb.dart';
import 'package:win32/win32.dart';
import 'package:win_ble/win_ble.dart';
import 'package:win_ble/win_file.dart';

import 'print_data.dart';
import 'printers_data.dart';

class WindowPrinterManager {
  WindowPrinterManager._privateConstructor();

  static WindowPrinterManager? _instance;

  static WindowPrinterManager get instance {
    _instance ??= WindowPrinterManager._privateConstructor();
    return _instance!;
  }

  static bool isInitialized = false;

  static init() async {
    if (!isInitialized) {
        WinBle.initialize(serverPath: await WinServer.path()).then((value) {
          isInitialized = true;
        }, onError: (e){
          if(e.toString().contains("already initialized")){
            isInitialized = true;
          }
          debugPrint(e.toString());
        });
    }
  }

  final StreamController<List<Printer>> _devicesstream = StreamController<List<Printer>>.broadcast();

  Stream<List<Printer>> get devicesStream => _devicesstream.stream;

  // Stop scanning for BLE devices
  Future<void> stopscan() async {
    if (isInitialized) {
      WinBle.stopScanning();
    }
  }

  // Connect to a BLE device
  Future<bool> connect(Printer device) async {
    if(device.connectionType==ConnectionType.USB){
     return await PrintUsb.connect(name: device.name??"");
    }
    if (!isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    await WinBle.connect(device.address!);
    await Future.delayed(const Duration(seconds: 5));
    return await WinBle.isPaired(device.address!);
  }

  // Print data to a BLE device
  Future<bool> printData(
    Printer device,
    List<int> bytes, {
    bool longData = false,
    WindowsLib version = WindowsLib.V1
  }) async {
    try{
    if (device.connectionType == ConnectionType.USB) {
      if(version == WindowsLib.V1){
        using((Arena alloc) {
          final printer = RawPrinter(device.name!, alloc);
          printer.printEscPosWin32(bytes);
        });
        return true;
      }else{
        return await PrintUsb.printBytes(bytes: bytes, device: UsbDevice(name: device.name??"", model: device.address??"",isDefault: false, available: true));
      }
    }
    if (!isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    final services = await WinBle.discoverServices(device.address!);
    final service = services.first;
    final characteristics = await WinBle.discoverCharacteristics(
      address: device.address!,
      serviceId: service,
    );
    final characteristic = characteristics.firstWhere((element) => element.properties.write ?? false).uuid;
    final mtusize = await WinBle.getMaxMtuSize(device.address!);

     if (longData) {
       int mtu = mtusize - 50;
       if (mtu.isNegative) {
         mtu = 20;
       }
       final numberOfTimes = bytes.length / mtu;
       final numberOfTimesInt = numberOfTimes.toInt();
       int timestoPrint = 0;
       if (numberOfTimes > numberOfTimesInt) {
         timestoPrint = numberOfTimesInt + 1;
       } else {
         timestoPrint = numberOfTimesInt;
       }
       for (var i = 0; i < timestoPrint; i++) {
         final data = bytes.sublist(i * mtu, ((i + 1) * mtu) > bytes.length ? bytes.length : ((i + 1) * mtu));
         await WinBle.write(
           address: device.address!,
           service: service,
           characteristic: characteristic,
           data: Uint8List.fromList(data),
           writeWithResponse: false,
         );
       }
     } else {
       await WinBle.write(
         address: device.address!,
         service: service,
         characteristic: characteristic,
         data: Uint8List.fromList(bytes),
         writeWithResponse: false,
       );
     }
     return true;
   }catch(e){
     return false;
   }
  }

  Future<bool> isPaired(String address) async{
    try{
      return await WinBle.isPaired(address);
    }catch(e){
      return false;
    }
  }

  // Getprinters
  void getPrinters({
    Duration refreshDuration = const Duration(seconds: 10),
    List<ConnectionType> connectionTypes = const [
      ConnectionType.BLE,
      ConnectionType.USB,
    ],
    WindowsLib version = WindowsLib.V1
  }) async {
    if (connectionTypes.contains(ConnectionType.BLE)) {
      await init();
      if (!isInitialized) {
        await init();
      }
      if (!isInitialized) {
        throw Exception(
          'WindowBluetoothManager is not initialized. Try starting the scan again',
        );
      }
      List<Printer> btlist = [];
      WinBle.stopScanning();
      WinBle.startScanning();
       WinBle.scanStream.map((item) async => Printer(
         address: item.address,
         name: item.name,
         connectionType: ConnectionType.BLE,
         isConnected: await isPaired(item.address),
       )).listen((value) async {
         final device  = await value;
       final index = btlist.indexWhere((element) => element.name == device.name);
       if (index != -1) {
         btlist[index] = device;
       } else {
         btlist.add(device);
       }
       _devicesstream.add(btlist);
      });

    } else if (connectionTypes.contains(ConnectionType.USB)) {
      if(version == WindowsLib.V1){
          final devices = PrinterNames(PRINTER_ENUM_LOCAL);
          List<Printer> templist = [];
          for (var e in devices.all()) {
            final device = Printer(
              vendorId: e,
              productId: "N/A",
              name: e,
              connectionType: ConnectionType.USB,
              address: e,
              isConnected: true,
            );
            templist.add(device);
          }
          _devicesstream.add(templist);
      }else{
        _devicesstream.add((await PrintUsb.getList()).map((device) => Printer(name: device.name, address: device.model, connectionType: ConnectionType.USB, isConnected: device.available, vendorId: "", productId: "")).toList());
      }
    }else{
      _devicesstream.add([]);
    }
  }

  turnOnBluetooth() async {
    if (!isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    await WinBle.updateBluetoothState(true);
  }

  Stream<bool> isBleTurnedOnStream = WinBle.bleState.map(
    (event) {
      return event == BleState.On;
    },
  );

  Future<bool> isBleTurnedOn() async {
    if (!isInitialized) {
      throw Exception('WindowBluetoothManager is not initialized');
    }
    return (await WinBle.getBluetoothState()) == BleState.On;
  }

  void dispose(){
    if(isInitialized){
      WinBle.dispose();
    }
  }
}
