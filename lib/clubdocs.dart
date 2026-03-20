import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 토큰을 불러오기 위해 추가

class ClubDocsScreen extends StatelessWidget {
  const ClubDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? mclubNo = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('클럽 문서 목록')),
      backgroundColor: Colors.yellow,
      body:
      mclubNo != null
          ? FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchClubDocs(mclubNo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            // 💡 에러 메시지를 잘 보이게 빨간색으로 가운데 정렬
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          } else if (snapshot.hasData) {
            final docs = snapshot.data!;
            if (docs.isEmpty) {
              return Center(child: Text('문서가 없습니다.'));
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(doc['docTitle'] ?? '제목 없음'),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/docViewer',
                        arguments: doc['docNo'], // 문서 번호 전달
                      );
                    },
                  ),
                );
              },
            );
          } else {
            return Center(child: Text('문서를 불러오는 중 문제가 발생했습니다.'));
          }
        },
      )
          : Center(child: Text('클럽 번호가 없습니다.')),
    );
  }

  Future<List<Map<String, dynamic>>> fetchClubDocs(String mclubNo) async {
    try {
      // 1. 저장된 토큰 불러오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      // 2. 헤더에 토큰을 담아서 GET 요청 보내기
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/clubdocs/$mclubNo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // UTF-8 디코딩을 통해 한글 처리
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        if (data['docs'] != null && data['docs'] is List) {
          return List<Map<String, dynamic>>.from(data['docs']);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        // 💡 에러 발생 시 상태 코드와 내용을 화면에 출력하도록 수정
        throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
      }
    } catch (e) {
      throw Exception('문서를 불러오는 중 오류가 발생했습니다: $e');
    }
  }
}
