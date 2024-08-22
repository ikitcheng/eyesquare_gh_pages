import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:parking_app/models/parking_space.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
//import 'package:encrypt/encrypt.dart' as encrypt;
//import 'package:flutter_dotenv/flutter_dotenv.dart';
//import 'dart:io' show Platform;

/*
class SecureKeyManager {
  static String? _cachedEncryptedKey;
  static final _aesKey = encrypt.Key.fromLength(32);
  static final _iv = encrypt.IV.fromLength(16);

  static String encryptKey(String plainKey) {
    if (_cachedEncryptedKey == null) {
      final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey));
      _cachedEncryptedKey = encrypter.encrypt(plainKey, iv: _iv).base64;
    }
    return _cachedEncryptedKey!;
  }

  static String decryptKey(String encryptedKey) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_aesKey));
    return encrypter.decrypt64(encryptedKey, iv: _iv);
  }

  static String getDecryptedKey() {
    if (_cachedEncryptedKey != null) {
      return decryptKey(_cachedEncryptedKey!);
    }
    throw Exception("Encrypted key not set");
  }
}
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

    // Load the .env file
  //await dotenv.load(fileName: ".env");
/*
   String baseUrl;
   String anonKey;
    
    //String baseUrl = const String.fromEnvironment('baseUrl', defaultValue: '');
    //String anonKey = const String.fromEnvironment('anonKey', defaultValue: '');

    await dotenv.load(fileName: ".env");
    baseUrl = dotenv.env['baseurl'] ?? '';
    anonKey = dotenv.env['anonKey'] ?? '';

  if (const bool.fromEnvironment('dart.vm.product')) {
    // Production mode (Netlify)
    baseUrl = Platform.environment['baseurl'] ?? '';
    anonKey = Platform.environment['anonKey'] ?? '';
  } else {
    // Development mode
    await dotenv.load(fileName: ".env");
    baseUrl = dotenv.env['baseurl'] ?? '';
    anonKey = dotenv.env['anonKey'] ?? '';
  }
*/
const String anonKey = String.fromEnvironment("SBKey", defaultValue: '');
const String baseUrl = String.fromEnvironment("SBUrl", defaultValue: '');
  try {
    await Supabase.initialize(
      url: baseUrl,
      anonKey: anonKey,

    );

    
    print("Supabase initialized successfully");
  } catch (e) {
    print("Error initializing Supabase: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      //title: 'Open Street Map in Flutter',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late MapController mapController;
  List<ParkingSpace> parkingSpaces = [];
  bool isLoading = true;
  Timer? _timer;
  final supabase = Supabase.instance.client;
  
  int _selectedLayer = 0;
  Set<int> _favoriteParkingSpaces = {};
  int _selectedVehicleType = 1; // 0: 全部, 1: 汽車, 2: 電單車

  List<Marker> allParkingMarkers = [];
  List<Marker> roadsideParkingMarkers = [];
  List<Marker> favoriteParkingMarkers = [];
  Marker? destinationMarker;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  List<ParkingSpace> nearestParkingSpaces = [];

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    loadParkingSpaces().then((_) => _updateLayers());
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      loadParkingSpaces().then((_) => _updateLayers());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadParkingSpaces() async {
    setState(() {
      isLoading = true;
    });

    try {
      final allParkingSpaces = await supabase.from('parking_space').select();
      if (allParkingSpaces != null) {
        print("成功加載停車場數據。數據條數: ${allParkingSpaces.length}");
        
        setState(() {
          parkingSpaces = (allParkingSpaces as List<dynamic>)
              .map((row) => ParkingSpace.fromJson(row as Map<String, dynamic>))
              .toList();
          isLoading = false;
        });
        _updateLayers();
      } else {
        print("加載停車場數據失敗：返回的數據為空");
        setState(() {
          isLoading = false;
        });
      }
    } catch (error) {
      print("加載停車場數據時出錯: $error");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final response = await http.get(Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=$query'));

    if (response.statusCode == 200) {
      final List<dynamic> results = json.decode(response.body);
      setState(() {
        _searchResults = results.map((result) => {
          'display_name': result['name'],
          'lat': double.parse(result['lat']),
          'lon': double.parse(result['lon']),
        }).toList();
      });
    } else {
      print('Failed to load search results');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Open Street Map in Flutter',
          style: TextStyle(fontSize: 22),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildVehicleTypeSelector(),
          _buildLayerSelector(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: LatLng(22.1987, 113.5439),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(markers: _getVisibleMarkers()),
                      if (destinationMarker != null)
                        MarkerLayer(markers: [destinationMarker!]),

                    // 版權信息
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Icon designed by Freepik from flaticon',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),

                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索地點',
              suffixIcon: Image.asset('assets/search.png', width: 24, height: 24), // 假設你也想改變搜索圖標
            ),
            onChanged: (value) {
              searchLocation(value);
            },
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            height: 200,
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_searchResults[index]['display_name']),
                  onTap: () {
                    LatLng selectedLocation = LatLng(_searchResults[index]['lat'], _searchResults[index]['lon']);
                    mapController.move(selectedLocation, 17);
                    setState(() {
                      destinationMarker = Marker(
                        point: selectedLocation,
                        width: 40,
                        height: 40,
                        child: Image.asset('assets/placeholder.png', width: 40, height: 40),
                      );
                      _searchResults = [];
                      _searchController.clear();
                    });
                    _findNearestParkingSpaces(selectedLocation);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLayerSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLayerButton(0, 'assets/all.png', '所有停車位'),
        _buildLayerButton(1, 'assets/street_park.png', '街位'),
        _buildLayerButton(2, 'assets/star.png', '常用'),
      ],
    );
  }

  Widget _buildVehicleTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        //_buildVehicleTypeButton(0, 'assets/all.png', '全部'),
        _buildVehicleTypeButton(1, 'assets/car.png', '汽車'),
        _buildVehicleTypeButton(2, 'assets/moto.png', '電單車'),
      ],
    );
  }

  Widget _buildLayerButton(int layer, dynamic icon, String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedLayer == layer ? Color.fromARGB(255, 180, 206, 181) : Colors.grey,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon is IconData)
            Icon(icon, color: _selectedLayer == layer ? Colors.yellow : Colors.white)
          else if (icon is String)
            Image.asset(icon, width: 24, height: 24),
          SizedBox(width: 8),
          Text(label),
        ],
      ),
      onPressed: () {
        setState(() {
          _selectedLayer = layer;
          _updateLayers();
        });
      },
    );
  }

  Widget _buildVehicleTypeButton(int type, String iconPath, String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedVehicleType == type ? Color.fromARGB(255, 180, 206, 181) : Colors.grey,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            iconPath,
            width: 24,
            height: 24,
          ),
          SizedBox(width: 8),
          Text(label),
        ],
      ),
      onPressed: () {
        setState(() {
          _selectedVehicleType = type;
          _updateLayers();
        });
      },
    );
  }

  void _updateLayers() {
    setState(() {
      allParkingMarkers.clear();
      roadsideParkingMarkers.clear();
      favoriteParkingMarkers.clear();

      for (var space in parkingSpaces) {
        if (_shouldShowParkingSpace(space)) {
          var marker = _createMarker(space);
          allParkingMarkers.add(marker);
          if (space.isRoadside) {
            roadsideParkingMarkers.add(marker);
          }
          if (_favoriteParkingSpaces.contains(space.id)) {
            favoriteParkingMarkers.add(marker);
          }
        }
      }
    });
    print("更新後的標記數量: 全部=${allParkingMarkers.length}, 路邊=${roadsideParkingMarkers.length}, 收藏=${favoriteParkingMarkers.length}");
  }

  bool _shouldShowParkingSpace(ParkingSpace space) {
    switch (_selectedVehicleType) {
      case 1: // 汽車
        return space.vehicleSpace != '-1' || space.eVehicleSpace != '-1';
      case 2: // 電單車
        return (space.motorcycleSpace != '-1') ||
               (space.eMotorcycleSpace != '-1');
      default: // 全部
        return true;
    }
  }


  Marker _createMarker(ParkingSpace space) {
  bool isNearestParkingSpace = nearestParkingSpaces.contains(space);
  double size = isNearestParkingSpace ? 40 : 20;
  final GlobalKey<TooltipState> tooltipkey = GlobalKey<TooltipState>();

  return Marker(
    point: LatLng(space.latitude, space.longitude),
    width: size,
    height: size,
    child: Tooltip(
      key: tooltipkey,
      triggerMode: TooltipTriggerMode.manual,
      message: _createTooltipContent(space),
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: Colors.white),
        child: GestureDetector(
        onTap: () {
          setState(() {
            tooltipkey.currentState?.ensureTooltipVisible();
          });
          },
        onDoubleTap: () {
          // Toggle favorite on long press
          setState(() {
            if (_favoriteParkingSpaces.contains(space.id)) {
              _favoriteParkingSpaces.remove(space.id);
            } else {
              _favoriteParkingSpaces.add(space.id);
            }
            _updateLayers();
          });
        },
        child: Image.asset(
          _favoriteParkingSpaces.contains(space.id) ? 'assets/star.png' : 'assets/parkicon.png',
          width: size,
          height: size,
        ),
      ),
    ),
  );
}


  List<Marker> _getVisibleMarkers() {
    switch (_selectedLayer) {
      case 1:
        return roadsideParkingMarkers;
      case 2:
        return favoriteParkingMarkers;
      default:
        return allParkingMarkers;
    }
  }



  void _findNearestParkingSpaces(LatLng location) {
    List<ParkingSpace> sortedSpaces = List.from(parkingSpaces);
    sortedSpaces.sort((a, b) {
      double distanceA = _calculateDistance(location, LatLng(a.latitude, a.longitude));
      double distanceB = _calculateDistance(location, LatLng(b.latitude, b.longitude));
      return distanceA.compareTo(distanceB);
    });

    setState(() {
      nearestParkingSpaces = sortedSpaces.take(3).toList();
      _updateLayers(); // This will update the markers to highlight the nearest parking spaces
    });
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((point2.latitude - point1.latitude) * p)/2 + 
            c(point1.latitude * p) * c(point2.latitude * p) * 
            (1 - c((point2.longitude - point1.longitude) * p))/2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R; R = 6371 km, 結果轉換為米
  }

  String _createTooltipContent(ParkingSpace space) {
    String content = '${space.parkingName}\n';
    if (_selectedVehicleType == 0 || _selectedVehicleType == 1) {
      content += '汽車: ${space.vehicleSpace == '-1' ? "-" : space.vehicleSpace}\n';
      content += '電車: ${space.eVehicleSpace== '-1' ? "-" : space.eVehicleSpace}\n';
    }
    if (_selectedVehicleType == 0 || _selectedVehicleType == 2) {
      content += '電單車: ${space.motorcycleSpace== '-1' ? "-" : space.motorcycleSpace}\n';
      content += '電動電單車: ${space.eMotorcycleSpace== '-1' ? "-" : space.eMotorcycleSpace}\n';
    }
    
    // Modify this line to handle potential errors
    content += '更新: ${DateFormat('MM/dd HH:mm').format(space.refreshTime)}';
    return content;
    }

}