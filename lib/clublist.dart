import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clublogo.dart';
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 토큰을 불러오기 위해 추가

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ClubListScreen(),
      useInheritedMediaQuery: true, // Edge-to-Edge 대응 옵션 (Flutter 3.13+)
    );
  }
}

class Club {
  final int clubNo;
  final String clubName;
  final int regionNo;

  Club({required this.clubNo, required this.clubName, required this.regionNo});

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      clubNo: json['clubNo'],
      clubName: json['clubName'],
      regionNo: json['regionNo'],
    );
  }
}

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  _ClubListScreenState createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  Future<List<Club>>? _clubList;
  int? mregionNo;
  String? mclubNo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final regionArg = args['mregionNo'];
      if (regionArg is int) {
        mregionNo = regionArg;
      } else if (regionArg is String) {
        mregionNo = int.tryParse(regionArg);
      }
      mclubNo = args['mclubNo']?.toString();
      if (_clubList == null && mregionNo != null) {
        _clubList = fetchClubList(mregionNo!);
      }
    }
  }

  Future<List<Club>> fetchClubList(int mregionNo) async {
    try {
      // 1. 저장된 토큰 불러오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      // 2. 헤더에 토큰을 담아서 GET 요청 보내기
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/clubList/$mregionNo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        Map<String, dynamic> data = json.decode(decodedResponse);
        List<dynamic> clubs = data['clubs'];
        return clubs.map((json) => Club.fromJson(json)).toList();
      } else {
        // 💡 에러 발생 시 상태 코드와 내용을 화면에 출력하도록 수정
        throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
      }
    } catch (e) {
      throw Exception('클럽 리스트를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: const Text('클럽 리스트'),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: _clubList == null
            ? const Center(child: Text('No region selected'))
            : FutureBuilder<List<Club>>(
          future: _clubList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              // 💡 에러 메시지를 잘 보이게 빨간색으로 가운데 정렬
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No clubs found'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final club = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(club.clubNo.toString())),
                      title: Text(club.clubName),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoadingScreen(
                              clubNo: club.clubNo,
                              clubName: club.clubName,
                              mclubNo: mclubNo,
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
