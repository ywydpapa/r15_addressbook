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
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('공지사항목록'),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: (mregionNo != null && mclubNo != null)
            ? (mfuncNo == '1'
            ? NoticeListWidget(
          title: '클럽 공지',
          future: fetchClubDocs(mclubNo: mclubNo),
          mfuncNo: mfuncNo,
        )
            : NoticeTabWidget(
          mregionNo: mregionNo!,
          mclubNo: mclubNo!,
          mfuncNo: mfuncNo,
        ))
            : Center(child: Text('지역 번호 또는 클럽 번호가 없습니다.')),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchClubDocs({int? mregionNo, int? mclubNo, String? mfuncNo}) async {
    try {
      String url;
      if (mfuncNo == '1' || (mregionNo == null && mclubNo != null)) {
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

// 공지 목록 위젯
class NoticeListWidget extends StatelessWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> future;
  final String? mfuncNo;

  const NoticeListWidget({
    Key? key,
    required this.title,
    required this.future,
    this.mfuncNo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
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
    );
  }
}

// TabBarView로 두 목록을 보여주는 위젯
class NoticeTabWidget extends StatelessWidget {
  final int mregionNo;
  final int mclubNo;
  final String? mfuncNo;

  const NoticeTabWidget({
    Key? key,
    required this.mregionNo,
    required this.mclubNo,
    this.mfuncNo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: '지역 공지'),
              Tab(text: '클럽 공지'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                NoticeListWidget(
                  title: '지역 공지',
                  future: NoticeScreen().fetchClubDocs(mregionNo: mregionNo),
                  mfuncNo: mfuncNo,
                ),
                NoticeListWidget(
                  title: '클럽 공지',
                  future: NoticeScreen().fetchClubDocs(mclubNo: mclubNo, mfuncNo: '1'),
                  mfuncNo: '1',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
