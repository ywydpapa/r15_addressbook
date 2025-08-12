import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'circlelogo.dart';

class Circle {
  final int circleNo;
  final String circleName;

  Circle({required this.circleNo, required this.circleName});

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      circleNo: json['circleNo'] ?? 0,
      circleName: json['circleName'] ?? '',
    );
  }
}

class CircleListScreen extends StatefulWidget {
  const CircleListScreen({super.key});

  @override
  State<CircleListScreen> createState() => _CircleListScreenState();
}

class _CircleListScreenState extends State<CircleListScreen> {
  Future<List<Circle>>? _circleList;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['memberNo'] != null) {
      final memberNo = int.tryParse(args['memberNo'].toString()) ?? 0;
      setState(() {
        _circleList = fetchCircleList(memberNo);
      });
    }
  }

  Future<List<Circle>> fetchCircleList(int memberNo) async {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/getmycircle/$memberNo'),
    );
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> circles = data['circles'];
      return circles.map((json) => Circle.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load circle list');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: const Text('써클 리스트'),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: _circleList == null
            ? const Center(child: Text('No member selected'))
            : FutureBuilder<List<Circle>>(
          future: _circleList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No circle found'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final circle = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(circle.circleName),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoadingScreen(
                              circleNo: circle.circleNo,
                              circleName: circle.circleName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}
