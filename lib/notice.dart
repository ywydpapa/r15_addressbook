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
    int? mmemberNo;

    if (args is Map<String, dynamic>) {
      final dynamic regionValue = args['mregionNo'];
      if (regionValue is int) {
        mregionNo = regionValue;
      } else if (regionValue is String) {
        mregionNo = int.tryParse(regionValue);
      }
      mclubNo = int.tryParse(args['mclubNo']?.toString() ?? '');
      mfuncNo = args['mfuncNo']?.toString();
      mmemberNo = int.tryParse(args['memberNo']?.toString() ?? '');
    }


    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('공지사항목록'),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: (mregionNo != null && mclubNo != null && mmemberNo != null)
            ? (mfuncNo == '1'
            ? NoticeListWidget(
          title: '클럽 공지',
          future: fetchClubDocs(mclubNo: mclubNo, memberNo: mmemberNo),
          noticeType: 'CLUB',
          memberNo: mmemberNo,
          mfuncNo: mfuncNo,
        )
            : NoticeTabWidget(
          mregionNo: mregionNo!,
          mclubNo: mclubNo!,
          mfuncNo: mfuncNo,
          mmemberNo: mmemberNo,
        ))
            : Center(child: Text('지역 번호, 클럽 번호 또는 회원 번호가 없습니다.')),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> fetchClubDocs({int? mregionNo, int? mclubNo, int? memberNo ,String? mfuncNo}) async {
    try {
      String url;
      if (mfuncNo == '1' || (mregionNo == null && mclubNo != null)) {
        url = '${ApiConf.baseUrl}/phapp/clubnotice/$mclubNo/$memberNo';
      } else {
        url = '${ApiConf.baseUrl}/phapp/notice/$mregionNo/$memberNo';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        if (data['docs'] != null && data['docs'] is List) {
          return List<Map<String, dynamic>>.from(data['docs']);
        } else {
          throw Exception('Invalid response format: docs not found or not a list');
        }
      } else {
        throw Exception('Failed to load documents: ${response.statusCode}');
      }
    } catch (e, stack) {
      throw Exception('문서를 불러오는 중 오류가 발생했습니다.');
    }
  }
}

// 공지 읽음 처리 함수
Future<void> postNoticeRead({
  required int memberNo,
  required int noticeNo,
  required String noticeType,
}) async {
  final url = '${ApiConf.baseUrl}/phapp/noticeRead/$memberNo/$noticeNo/$noticeType';
  final response = await http.post(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('Failed to mark notice as read');
  }
}

// 공지 목록 위젯
class NoticeListWidget extends StatelessWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> future;
  final String noticeType; // 'REGION' 또는 'CLUB'
  final int memberNo;
  final String? mfuncNo;

  const NoticeListWidget({
    Key? key,
    required this.title,
    required this.future,
    required this.noticeType,
    required this.memberNo,
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
              final isRead = doc['readYN'] == 'Y';
              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  leading: Icon(
                    isRead ? Icons.drafts : Icons.markunread, // 읽음: 개봉, 안읽음: 미개봉
                    color: isRead ? Colors.grey : Colors.blue,
                  ),
                  title: Text(doc['noticeTitle'] ?? '제목 없음'),
                  onTap: () async {
                    final noticeNo = doc['noticeNo'];
                    try {
                      await postNoticeRead(
                        memberNo: memberNo,
                        noticeNo: noticeNo,
                        noticeType: noticeType,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('읽음 처리 중 오류 발생')),
                      );
                    }
                    Navigator.pushNamed(
                      context,
                      '/noticeViewer',
                      arguments: {
                        'noticeNo': noticeNo,
                        'mfuncNo': mfuncNo,
                        'noticeType': noticeType,
                        'memberNo': memberNo,
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
  final int mmemberNo;
  final String? mfuncNo;

  const NoticeTabWidget({
    Key? key,
    required this.mregionNo,
    required this.mclubNo,
    required this.mmemberNo,
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
                  future: NoticeScreen().fetchClubDocs(mregionNo: mregionNo, memberNo: mmemberNo),
                  noticeType: 'REGION', // 지역탭이니 REGION
                  memberNo: mmemberNo,
                  mfuncNo: mfuncNo,
                ),
                NoticeListWidget(
                  title: '클럽 공지',
                  future: NoticeScreen().fetchClubDocs(mclubNo: mclubNo, memberNo: mmemberNo, mfuncNo: '1'),
                  noticeType: 'CLUB', // 클럽탭이니 CLUB
                  memberNo: mmemberNo,
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
