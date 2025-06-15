import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'firebase_options.dart';


class AnalysisScreen extends StatefulWidget {
  @override
  _AnalysisScreenState createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final db = FirebaseDatabase.instance.ref().child("fire_alarm/history");
  List<FlSpot> floor1Spots = [];
  List<FlSpot> floor2Spots = [];
  List<Map<String, dynamic>> fireEvents = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    // Fetch last 50 points
    final snap1 = await db.child("floor1").orderByKey().limitToLast(50).get();
    final snap2 = await db.child("floor2").orderByKey().limitToLast(50).get();

    List<FlSpot> list1 = [], list2 = [];
    List<Map<String, dynamic>> events = [];

    int idx = 0;
    for (var c in snap1.children) {
      double v = (c.child("value").value as int).toDouble();
      list1.add(FlSpot(idx.toDouble(), v));
      if (v == 1) {
        events.add({
          "floor": 1,
          "timestamp": c.child("timestamp").value as String,
          "humans": c.child("humans").value as int
        });
      }
      idx++;
    }

    idx = 0;
    for (var c in snap2.children) {
      double v = (c.child("value").value as int).toDouble();
      list2.add(FlSpot(idx.toDouble(), v));
      if (v == 1) {
        events.add({
          "floor": 2,
          "timestamp": c.child("timestamp").value as String,
          "humans": c.child("humans").value as int
        });
      }
      idx++;
    }

    // Sort events by timestamp descending
    events.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

    setState(() {
      floor1Spots = list1;
      floor2Spots = list2;
      fireEvents = events;
      loading = false;
    });
  }

  LineChartData _chartData(List<FlSpot> spots) {
    return LineChartData(
      lineBarsData: [ LineChartBarData(spots: spots, isCurved: false, dotData: FlDotData(show: true), belowBarData: BarAreaData(show: false)) ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Floor 1 History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: LineChart(_chartData(floor1Spots))),
            SizedBox(height: 24),
            Text("Floor 2 History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 200, child: LineChart(_chartData(floor2Spots))),
            SizedBox(height: 32),
            Text("Fire Detected Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: fireEvents.length,
              itemBuilder: (ctx, i) {
                final e = fireEvents[i];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Icon(Icons.local_fire_department, color: Colors.red),
                    title: Text("Floor ${e['floor']} at ${e['timestamp']}"),
                    subtitle: Text("Humans detected: ${e['humans']}"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
