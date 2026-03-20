import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'circlelogo.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 토큰을 불러오기 위해 추가

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
    // 1. 저장된 토큰 불러오기
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    // 2. 헤더에 토큰을 담아서 GET 요청 보내기
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/getmycircle/$memberNo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> circles = data['circles'];
      return circles.map((json) => Circle.fromJson(json)).toList();
    } else {
      // 💡 에러 발생 시 상태 코드와 내용을 화면에 출력하도록 수정
      throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
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
              // 에러 메시지를 잘 보이게 빨간색으로 가운데 정렬
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              );
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
