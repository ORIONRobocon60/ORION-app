import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ORION',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'ORION'),
      );
}

class Sensor {
  int id;
  String name;

  Sensor(this.id, this.name);

  static List<Sensor> getSensors() {
    return <Sensor>[
      Sensor(0, 'CO2 Level'),
      Sensor(1, 'VOC Level'),
      Sensor(2, 'Temperature'),
      Sensor(3, 'Forecast')
    ];
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  final FlutterBlue flutterBlue = FlutterBlue.instance;
  final List<BluetoothDevice> devicesList = new List<BluetoothDevice>();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<BluetoothService> _services;

  List<Sensor> _sensors = Sensor.getSensors();
  List<DropdownMenuItem<Sensor>> _dropdownSensorMenuItems;
  Sensor _selectedSensor;

  List<DropdownMenuItem<BluetoothDevice>> _dropdownMenuItems;
  BluetoothDevice _selectedDevice;

  String _data = "";
  String _result = "";
  Color _glColor = Color(0xFF40C4E0);

  _addDeviceTolist(final BluetoothDevice device) {
    if (!widget.devicesList.contains(device)) {
      setState(() {
        widget.devicesList.add(device);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.flutterBlue.connectedDevices
        .asStream()
        .listen((List<BluetoothDevice> devices) {
      for (BluetoothDevice device in devices) {
        _addDeviceTolist(device);
      }
    });
    widget.flutterBlue.scanResults.listen((List<ScanResult> results) {
      for (ScanResult result in results) {
        _addDeviceTolist(result.device);
      }
    });
    widget.flutterBlue.startScan();

    _dropdownMenuItems = buildDropdownMenuItems();
    _dropdownSensorMenuItems = buildSensorDropdownMenuItems(_sensors);
    // _selectedDevice = _dropdownMenuItems[0].value;

    super.initState();
  }

  List<DropdownMenuItem<Sensor>> buildSensorDropdownMenuItems(List sensors) {
    List<DropdownMenuItem<Sensor>> items = List();

    for (Sensor sensor in sensors) {
      items.add(
        DropdownMenuItem(
          value: sensor,
          child: Text(sensor.name, style: TextStyle(fontSize: 20)),
        ),
      );
    }
    return items;
  }

  List<DropdownMenuItem<BluetoothDevice>> buildDropdownMenuItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (widget.devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('No device detected. Please press refresh button.'),
      ));
    } else {
      widget.devicesList.forEach((device) {
        if (device.name != '') {
          items.add(DropdownMenuItem(
            child: Text(device.name),
            value: device,
          ));
        }
      });
    }
    return items;
  }

  onChangeDropdownSensorItem(Sensor selectedSensor) {
    setState(() {
      _selectedSensor = selectedSensor;
    });
  }

  onChangeDropdownItem(BluetoothDevice selectedDevice) {
    setState(() {
      _selectedDevice = selectedDevice;
    });
    setState(() async {
      widget.flutterBlue.stopScan();
      try {
        await selectedDevice.connect();
      } catch (e) {
        if (e.code != 'already_connected') {
          throw e;
        }
      } finally {
        _services = await selectedDevice.discoverServices();
        getData();
      }
    });
  }

  getData() async {
    for (BluetoothService service in _services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          characteristic.value.listen((value) {
            setState(() {
              var val = new String.fromCharCodes(value).split(",");
              _data = val[_selectedSensor.id].trim();

              switch (_selectedSensor.id) {
                case 0:
                  var intVal = int.parse(val[_selectedSensor.id]);
                  if (intVal > 2000) {
                    _result = "BAD";
                    _glColor = Colors.red;
                  } else {
                    _result = "NORMAL";
                    _glColor = Color(0xFF40C4E0);
                  }
                  break;
                case 1:
                  var intVal = int.parse(val[_selectedSensor.id]);
                  if (intVal < 300) {
                    _result = "LOW";
                    _glColor = Color(0xFF40C4E0);
                  } else if (intVal < 500) {
                    _result = "ACCEPTABLE";
                    _glColor = Color(0xFF40C4E0);
                  } else {
                    _result = "BAD";
                    _glColor = Colors.red;
                  }
                  break;
                case 2:
                case 3:
                  _result = "";
                  break;
              }
            });
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(children: <Widget>[
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: ExactAssetImage('images/bg.jpg'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Container(
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text("Select a device",
                    style: TextStyle(color: Color(0xFF40C4E0), fontSize: 20)),
                DropdownButton(
                  value: _selectedDevice,
                  items: _dropdownMenuItems,
                  onChanged: onChangeDropdownItem,
                ),
                Text("Select a sensor",
                    style: TextStyle(color: Color(0xFF40C4E0), fontSize: 20)),
                DropdownButton(
                  value: _selectedSensor,
                  items: _dropdownSensorMenuItems,
                  onChanged: onChangeDropdownSensorItem,
                ),
                Text(_data,
                    style: TextStyle(color: Color(0xFF40C4E0), fontSize: 50)),
                Text(_result, style: TextStyle(color: _glColor, fontSize: 50)),
                // Text('Selected: ${_selectedDevice}'),
                SizedBox(
                  height: 50.0,
                ),
                FlatButton.icon(
                  icon: Icon(
                    Icons.refresh,
                    color: Colors.white,
                  ),
                  label: Text(
                    "Refresh",
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  splashColor: Colors.deepPurple,
                  onPressed: () async {
                    setState(() {
                      _dropdownMenuItems = buildDropdownMenuItems();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        // _buildView()
      ]));
}
