import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';            // ← For timestamps
import 'package:fl_chart/fl_chart.dart';   // ← For charts
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(FireAlarmApp());
}

class FireAlarmApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Floor Fire Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: FireAlarmScreen(),
    );
  }
}

class FireAlarmScreen extends StatefulWidget {
  @override
  _FireAlarmScreenState createState() => _FireAlarmScreenState();
}

class _FireAlarmScreenState extends State<FireAlarmScreen> {
  bool isAlarmTriggered = false;
  bool isAlarmFloor1 = false;
  bool isAlarmFloor2 = false;
  bool isAutoMode = true;
  int detectedHumans = 0;
    String esp8266Url = "http://192.168.198.65"; // ← Your ESP IP

  final databaseRef = FirebaseDatabase.instance.ref();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    // Load saved ESP8266 IP address from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      String? savedIP = prefs.getString("esp_ip");
      if (savedIP != null && mounted) {
        setState(() => esp8266Url = savedIP);
      }
    });

    // Listen for human count & global alarm flag in Firebase
    databaseRef.child("fire_alarm/detectedHumans").onValue.listen((e) {
      if (e.snapshot.exists) {
        setState(() => detectedHumans = e.snapshot.value as int);
      }
    });
    databaseRef.child("fire_alarm/isAlarmTriggered").onValue.listen((e) {
      if (e.snapshot.exists) {
        bool newStatus = e.snapshot.value as bool;
        if (newStatus != isAlarmTriggered) {
          setState(() => isAlarmTriggered = newStatus);
          if (isAlarmTriggered) {
            _vibrate(); _playSound();
          } else {
            _stopSound(); Vibration.cancel();
          }
        }
      }
    });

    startMonitoring();
  }

  Future<void> startMonitoring() async {
    final histRef = databaseRef.child("fire_alarm/history");
    while (mounted) {
      if (isAutoMode && esp8266Url.isNotEmpty) {
        try {
          final res = await http.get(Uri.parse("$esp8266Url/fire"));
          if (res.statusCode == 200) {
            final data = json.decode(res.body) as Map<String, dynamic>;
            bool f1 = data['floor1'] == "1";
            bool f2 = data['floor2'] == "1";

            // If changed, update state, Firebase, and history
            if (f1 != isAlarmFloor1 || f2 != isAlarmFloor2) {
              setState(() {
                isAlarmFloor1 = f1;
                isAlarmFloor2 = f2;
                isAlarmTriggered = f1 || f2;
              });
              if (isAlarmTriggered) { _vibrate(); _playSound(); }
              else { _stopSound(); Vibration.cancel(); }

              // Update global alarm flag
              await databaseRef.child("fire_alarm").update({
                "isAlarmTriggered": isAlarmTriggered,
              });

              // Push timestamped history
              String now = DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now());
              await histRef.child("floor1").push().set({
                "timestamp": now,
                "value": f1 ? 1 : 0,
              });
              await histRef.child("floor2").push().set({
                "timestamp": now,
                "value": f2 ? 1 : 0,
              });
            }
          }
        } catch (e) {
          print("ESP Error: $e");
        }
      }
      await Future.delayed(Duration(seconds: 1));
    }
  }

  void _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 500], repeat: 1);
    }
  }

  void _playSound() async => await _audioPlayer.play(AssetSource('alarm.mp3'));
  void _stopSound() async => await _audioPlayer.stop();

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("About This Project"),
        content: SingleChildScrollView(
          child: Text(
              "This is a multi-floor fire detection system:\n\n"
                  "• ESP8266 polls two IR sensors and serves a JSON API.\n"
                  "• Flutter app shows each floor’s status, plays alarm, vibrates, changes color.\n"
                  "• SOS alert and human count via Firebase.\n\n"
                  "Feature Enhancements:\n"
                  "• Per-floor manual reset controls.\n"
                  "• Push notifications (SMS/Email).\n"
                  "• Sensor history graphs (✔️ implemented!).\n"
                  "• Dynamic support for more floors.\n"
                  "• User authentication & roles."
          ),
        ),
        actions: [ TextButton(onPressed: () => Navigator.pop(context), child: Text("Close")) ],
      ),
    );
  }

  void _showSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    TextEditingController ipController = TextEditingController(text: esp8266Url);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("ESP8266 IP Address"),
        content: TextField(
          controller: ipController,
          decoration: InputDecoration(hintText: "e.g. 192.168.198.65"),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              String newIP = ipController.text.trim();
              if (newIP.isNotEmpty) {
                if (!newIP.startsWith("http")) newIP = "http://$newIP";
                setState(() => esp8266Url = newIP);
                prefs.setString("esp_ip", newIP);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("✅ IP updated to $newIP")),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("❌ IP cannot be empty")),
                );
              }
            },
            child: Text("Save"),
          ),
        ],
      ),
    );
  }



  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = isAlarmTriggered ? Colors.red : Colors.green;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text("Fire Alarm",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AnalysisScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showInfoDialog,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _floorCard(1, isAlarmFloor1)),
                  SizedBox(width: 20),
                  Expanded(child: _floorCard(2, isAlarmFloor2)),
                ],
              ),
              SizedBox(height: 20),
              if (isAlarmTriggered) ...[
                Text("👥 Detected Humans: $detectedHumans",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => databaseRef.child("fire_alarm").update({"sosAlert": true}),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: Text("🚨 Send SOS Alert"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _floorCard(int floor, bool isAlarm) {
    return GestureDetector(
      onTap: () {
        if (!isAlarm) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("✅ Floor $floor is safe!"))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "🔥 Floor $floor is on fire. Make responsible measures. Can't turn off alarm. False detection? Tap to read more."
              ),
              action: SnackBarAction(
                label: "Read More",
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text("Fire Alarm – Sensor Check"),
                      content: Text(
                          "To ensure accurate fire detection, it's crucial to regularly inspect, repair, or replace faulty sensors.\n\n"
                              "- Check wiring & cleanliness\n"
                              "- Replace damaged/old sensors\n"
                              "- Prevent false triggers (smoke, steam, insects)\n\n"
                              "Proper maintenance prevents false alarms and ensures safety."
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: Text("OK")),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text("Floor $floor", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Icon(
                isAlarm ? Icons.local_fire_department : Icons.health_and_safety_sharp,
                size: 60,
                color: isAlarm ? Colors.red : Colors.green,
              ),
              SizedBox(height: 10),
              Text(
                isAlarm ? "🔥 Fire Detected!" : "No Fire",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

///
/// AnalysisScreen: fetches last 50 history points and plots them.
///
class AnalysisScreen extends StatefulWidget {
  @override
  _AnalysisScreenState createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final db = FirebaseDatabase.instance.ref().child("fire_alarm/history");
  List<FlSpot> floor1Spots = [];
  List<FlSpot> floor2Spots = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final snap1 = await db.child("floor1").orderByKey().limitToLast(50).get();
    final snap2 = await db.child("floor2").orderByKey().limitToLast(50).get();

    List<FlSpot> list1 = [];
    List<FlSpot> list2 = [];

    int idx = 0;
    for (var c in snap1.children) {
      double v = (c.child("value").value as int).toDouble();
      list1.add(FlSpot(idx.toDouble(), v));
      idx++;
    }

    idx = 0;
    for (var c in snap2.children) {
      double v = (c.child("value").value as int).toDouble();
      list2.add(FlSpot(idx.toDouble(), v));
      idx++;
    }

    setState(() {
      floor1Spots = list1;
      floor2Spots = list2;
      loading = false;
    });
  }

  LineChartData _chartData(List<FlSpot> spots) {
    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
      ),
      gridData: FlGridData(show: true),
      borderData: FlBorderData(show: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sensor History Analysis")),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Floor 1 History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: LineChart(_chartData(floor1Spots))),
            SizedBox(height: 24),
            Text("Floor 2 History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: LineChart(_chartData(floor2Spots))),
          ],
        ),
      ),
    );
  }
}

///
/// Secret feature placeholder.
///
class SecretFeaturePage extends StatelessWidget {
  final DatabaseReference databaseRef;
  SecretFeaturePage({required this.databaseRef});

  void _setToggle(bool status) async {
    await databaseRef.child("fire_alarm").update({"screate_toggle": status});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _setToggle(true),
        onTapUp: (_) => _setToggle(false),
        onTapCancel: () => _setToggle(false),
        child: Center(child: Text(" ", style: TextStyle(color: Colors.black))),
      ),
    );
  }
}
