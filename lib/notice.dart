import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';

class NoticeScreen extends StatelessWidget {
  const NoticeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    int? mregionNo;
    int? mclubNo;
    String? mfuncNo;

    if (args is Map<String, dynamic>) {
      final dynamic regionValue = args['mregionNo'];
      if (regionValue is int) {
        mregionNo = regionValue;
      } else if (regionValue is String) {
        mregionNo = int.tryParse(regionValue);
      }
      mclubNo = int.parse(args['mclubNo']);
      mfuncNo = args['mfuncNo']?.toString();
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('공지사항목록')),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: (mregionNo != null && mclubNo != null)
            ? FutureBuilder<List<Map<String, dynamic>>>(
          future: fetchClubDocs(mregionNo, mclubNo, mfuncNo: mfuncNo),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Text('문서를 불러오는 중 오류가 발생했습니다: ${snapshot.error}'),
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
                      title: Text(doc['noticeTitle'] ?? '제목 없음'),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/noticeViewer',
                          arguments: {
                            'noticeNo': doc['noticeNo'],
                            'mfuncNo': mfuncNo,
                          },
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
            : Center(child: Text('지역 번호 또는 클럽 번호가 없습니다.')),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchClubDocs(int mregionNo, int mclubNo, {String? mfuncNo}) async {
    try {
      String url;
      if (mfuncNo == '1') {
        url = '${ApiConf.baseUrl}/phapp/clubnotice/$mclubNo';
      } else {
        url = '${ApiConf.baseUrl}/phapp/notice/$mregionNo';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        if (data['docs'] != null && data['docs'] is List) {
          return List<Map<String, dynamic>>.from(data['docs']);
        } else {
          throw Exception('Invalid response format');
        }
      } else {
        throw Exception('Failed to load documents: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('문서를 불러오는 중 오류가 발생했습니다.');
    }
  }
}