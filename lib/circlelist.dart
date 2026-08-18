// circlelist.dart 수정본
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'circlelogo.dart';
import 'circle_event_manage.dart'; // 👈 새로 만들 행사 관리 화면 import
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _memberNo; // 👈 멤버 번호 저장을 위한 변수

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['memberNo'] != null) {
      _memberNo = args['memberNo'].toString();
      final memberNo = int.tryParse(_memberNo!) ?? 0;
      setState(() {
        _circleList = fetchCircleList(memberNo);
      });
    }
  }

  Future<List<Circle>> fetchCircleList(int memberNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

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
      throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // main.dart에 정의된 테마 색상 적용
    const Color primaryNavy = Color(0xFF003366);
    const Color primaryGold = Color(0xFFFFC107);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        title: const Text('써클 리스트', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8F9FA), // main.dart의 bgColor와 통일
      body: SafeArea(
        child: _circleList == null
            ? const Center(child: Text('No member selected'))
            : FutureBuilder<List<Circle>>(
          future: _circleList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryNavy));
            } else if (snapshot.hasError) {
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
              return const Center(child: Text('소속된 써클이 없습니다.'));
            } else {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final circle = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 써클 이름 영역 (클릭 시 기존 써클 홈으로 이동)
                          InkWell(
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
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryNavy.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.stars, color: primaryNavy),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    circle.circleName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryNavy,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                          ),
                          const Divider(height: 24, thickness: 1),
                          // 행사 관리 버튼 영역
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CircleEventManageScreen(
                                      circleNo: circle.circleNo,
                                      circleName: circle.circleName,
                                      memberNo: _memberNo ?? '',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.event_available, color: primaryNavy),
                              label: const Text(
                                '행사 및 참석자 관리',
                                style: TextStyle(
                                  color: primaryNavy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: primaryNavy, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
