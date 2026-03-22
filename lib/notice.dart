import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        title: const Text('공지사항목록', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: (mmemberNo != null)
            ? NoticeTabWidget(
          mregionNo: mregionNo,
          mclubNo: mclubNo,
          mfuncNo: mfuncNo,
          mmemberNo: mmemberNo,
        )
            : const Center(child: Text('회원 정보가 없습니다.')),
      ),
    );
  }

  // 🌟 [수정됨] 지역 및 클럽 '목록'용 API 호출 (Viewer 주소가 아닌 목록 주소로 복구)
  static Future<List<Map<String, dynamic>>> fetchDocs({
    int? mregionNo,
    int? mclubNo,
    required int memberNo,
    required String noticeType,
  }) async {
    try {
      String url;
      // 💡 noticeType에 따라 목록을 불러오는 정확한 API 주소 할당
      if (noticeType == 'CLUB') {
        url = '${ApiConf.baseUrl}/phapp/clubnotice/$mclubNo/$memberNo';
      } else {
        // REGION (지역 공지)
        url = '${ApiConf.baseUrl}/phapp/notice/$mregionNo/$memberNo';
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        final data = json.decode(decodedBody);
        if (data['docs'] != null && data['docs'] is List) {
          return List<Map<String, dynamic>>.from(data['docs']);
        } else {
          throw Exception('Invalid response format: docs not found or not a list');
        }
      } else {
        throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('문서를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  // 🎨 써클 공지 전용 API 호출 (docs와 circlenames 모두 반환)
  static Future<Map<String, dynamic>> fetchCircleDocs({required int memberNo}) async {
    try {
      final url = '${ApiConf.baseUrl}/phapp/circlenotice/$memberNo';
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = utf8.decode(response.bodyBytes);
        return json.decode(decodedBody);
      } else {
        throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('써클 문서를 불러오는 중 오류가 발생했습니다: $e');
    }
  }
}

// 공지 읽음 처리 함수
Future<void> postNoticeRead({
  required int memberNo,
  required int noticeNo,
  required String noticeType,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token') ?? '';

  final url = '${ApiConf.baseUrl}/phapp/noticeRead/$memberNo/$noticeNo/$noticeType';

  final response = await http.post(
    Uri.parse(url),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode != 200) {
    throw Exception('읽음 처리 실패!\n상태 코드: ${response.statusCode}');
  }
}

// 🎨 지역 및 클럽 공지 목록 위젯
class NoticeListWidget extends StatelessWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> future;
  final String noticeType;
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
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
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
        } else if (snapshot.hasData) {
          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('문서가 없습니다.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final isRead = doc['readYN'] == 'Y';
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: Icon(
                    isRead ? Icons.drafts : Icons.markunread,
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
                        SnackBar(content: Text('읽음 처리 중 오류 발생: $e')),
                      );
                    }
                    Navigator.pushNamed(
                      context,
                      '/noticeViewer',
                      arguments: {
                        'noticeNo': noticeNo,
                        'mfuncNo': mfuncNo,
                        'noticeType': noticeType, // 🌟 뷰어로 타입 정상 전달
                        'memberNo': memberNo,
                      },
                    );
                  },
                ),
              );
            },
          );
        } else {
          return const Center(child: Text('문서를 불러오는 중 문제가 발생했습니다.'));
        }
      },
    );
  }
}

// 🎨 써클 공지 전용 위젯 (내부에 써클명 서브 탭 생성)
class CircleNoticeWidget extends StatelessWidget {
  final int memberNo;
  final String? mfuncNo;

  const CircleNoticeWidget({Key? key, required this.memberNo, this.mfuncNo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: NoticeScreen.fetchCircleDocs(memberNo: memberNo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
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
        } else if (snapshot.hasData) {
          final data = snapshot.data!;
          final List<String> circleNames = List<String>.from(data['circlenames'] ?? []);
          final List<Map<String, dynamic>> docs = List<Map<String, dynamic>>.from(data['docs'] ?? []);

          if (circleNames.isEmpty) {
            return const Center(child: Text('소속된 써클이 없습니다.'));
          }

          return DefaultTabController(
            length: circleNames.length,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    labelColor: Colors.black,
                    indicatorColor: Colors.blue,
                    tabs: circleNames.map((name) => Tab(text: name)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: circleNames.map((name) {
                      final circleDocs = docs.where((doc) => doc['circleName'] == name).toList();

                      if (circleDocs.isEmpty) {
                        return Center(child: Text('$name 써클의 공지사항이 없습니다.'));
                      }

                      return ListView.builder(
                        itemCount: circleDocs.length,
                        itemBuilder: (context, index) {
                          final doc = circleDocs[index];
                          final isRead = doc['readYN'] == 'Y';
                          return Card(
                            margin: const EdgeInsets.all(8.0),
                            child: ListTile(
                              leading: Icon(
                                isRead ? Icons.drafts : Icons.markunread,
                                color: isRead ? Colors.grey : Colors.blue,
                              ),
                              title: Text(doc['noticeTitle'] ?? '제목 없음'),
                              onTap: () async {
                                final noticeNo = doc['noticeNo'];
                                try {
                                  await postNoticeRead(
                                    memberNo: memberNo,
                                    noticeNo: noticeNo,
                                    noticeType: 'CIRCLE',
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('읽음 처리 중 오류 발생: $e')),
                                  );
                                }
                                Navigator.pushNamed(
                                  context,
                                  '/noticeViewer',
                                  arguments: {
                                    'noticeNo': noticeNo,
                                    'mfuncNo': mfuncNo,
                                    'noticeType': 'CIRCLE', // 🌟 뷰어로 타입 정상 전달
                                    'memberNo': memberNo,
                                  },
                                );
                              },
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        } else {
          return const Center(child: Text('데이터를 불러올 수 없습니다.'));
        }
      },
    );
  }
}

// 🎨 메인 탭 위젯 (지역/클럽/써클)
class NoticeTabWidget extends StatelessWidget {
  final int? mregionNo;
  final int? mclubNo;
  final int mmemberNo;
  final String? mfuncNo;

  const NoticeTabWidget({
    Key? key,
    this.mregionNo,
    this.mclubNo,
    required this.mmemberNo,
    this.mfuncNo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Tab> tabs = [];
    List<Widget> tabViews = [];

    if (mfuncNo != '1' && mfuncNo != '2') {
      if (mregionNo != null) {
        tabs.add(const Tab(text: '지역 공지'));
        tabViews.add(NoticeListWidget(
          title: '지역 공지',
          future: NoticeScreen.fetchDocs(mregionNo: mregionNo, memberNo: mmemberNo, noticeType: 'REGION'),
          noticeType: 'REGION',
          memberNo: mmemberNo,
          mfuncNo: mfuncNo,
        ));
      }
    }

    if (mfuncNo != '2') {
      if (mclubNo != null) {
        tabs.add(const Tab(text: '클럽 공지'));
        tabViews.add(NoticeListWidget(
          title: '클럽 공지',
          future: NoticeScreen.fetchDocs(mclubNo: mclubNo, memberNo: mmemberNo, noticeType: 'CLUB'),
          noticeType: 'CLUB',
          memberNo: mmemberNo,
          mfuncNo: mfuncNo,
        ));
      }
    }

    tabs.add(const Tab(text: '써클 공지'));
    tabViews.add(CircleNoticeWidget(
      memberNo: mmemberNo,
      mfuncNo: mfuncNo,
    ));

    if (tabs.length == 1) {
      return tabViews[0];
    }

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.black,
            indicatorColor: Colors.black,
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }
}
