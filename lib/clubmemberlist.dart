import 'package:flutter/material.dart';
import 'membertab.dart';
import 'membertabext.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Member {
  final int memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;
  final String clubRank;

  Member({
    required this.memberNo,
    required this.memberName,
    required this.memberPhone,
    required this.rankTitle,
    required this.clubRank,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      memberNo: json['memberNo'] ?? 0,
      memberName: json['memberName']?.toString() ?? json['memberCName']?.toString() ?? json['name']?.toString() ?? '이름 없음',
      memberPhone: json['memberPhone']?.toString() ?? json['phone']?.toString() ?? '',
      rankTitle: json['rankTitle']?.toString() ?? '',
      clubRank: json['clubRank']?.toString() ?? '',
    );
  }
}


class ClubMemberListScreen extends StatefulWidget {
  const ClubMemberListScreen({super.key});

  @override
  _ClubMemberListScreenState createState() => _ClubMemberListScreenState();
}

class _ClubMemberListScreenState extends State<ClubMemberListScreen> {
  late int clubNo;
  late String clubName;
  String? mclubNo;
  String? funcNo;

  late Future<List<Member>> _memberList;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  final TextEditingController _searchController = TextEditingController();

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
      clubNo = int.parse(args['clubNo'].toString());
      clubName = args['clubName'];
      mclubNo = args['mclubNo']?.toString();
      // 💡 main.dart에서 'mfuncNo'로 넘겨주므로 안전하게 둘 다 체크
      funcNo = (args['mfuncNo'] ?? args['funcNo'])?.toString();

      _memberList = fetchClubMemberList(clubNo);
      _searchController.addListener(_filterMembers);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Member>> fetchClubMemberList(int clubNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final String endpoint = (funcNo == '4')
        ? '/phapp/memberListext/$clubNo'
        : '/phapp/memberList/$clubNo';

    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> members = data['members'];

      members.removeWhere((item) =>
      item['phone'] == '35500150042' ||
          item['phoneno'] == '35500150042' ||
          item['mobile'] == '35500150042' ||
          item['memberPhone'] == '35500150042'
      );

      List<Member> memberList =
      members.map((json) => Member.fromJson(json)).toList();

      setState(() {
        _allMembers = memberList;
        _filteredMembers = memberList;
      });
      return memberList;
    } else {
      throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
    }
  }

  void _filterMembers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMembers = _allMembers.where((member) {
        return member.memberName.toLowerCase().contains(query) ||
            member.memberPhone.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 💡 게스트 여부에 따라 상단 타이틀 변경
    final String appBarTitle = (funcNo == '4') ? 'Member List' : '$clubName 회원 목록';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text(appBarTitle),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: Column(
          children: [
            // 검색 입력 필드
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  // 💡 게스트 여부에 따라 검색창 텍스트 변경
                  labelText: (funcNo == '4') ? 'Search' : '검색',
                  hintText: (funcNo == '4') ? 'Search by name or phone' : '이름 또는 전화번호로 검색',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            // 멤버 리스트
            Expanded(
              child: FutureBuilder<List<Member>>(
                future: _memberList,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text((funcNo == '4') ? 'No members found' : '회원 정보가 없습니다.'));
                  } else {
                    return InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.8,
                      maxScale: 3.0,
                      child: ListView.builder(
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          final imageUrl = '${ApiConf.baseUrl}/thumbnails/mphoto_${member.memberNo}.png';

                          return Card(
                            margin: EdgeInsets.all(8.0),
                            child: ListTile(
                              leading: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[200],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/defaultphoto.png',
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              title: Text(member.memberName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 💡 게스트 여부에 따라 직책 텍스트 변경 (RANK)
                                  (mclubNo.toString() == clubNo.toString() && member.clubRank.isNotEmpty)
                                      ? Text((funcNo == '4') ? 'RANK: ${member.clubRank}' : '클럽직책: ${member.clubRank}')
                                      : Text((funcNo == '4') ? 'RANK: ${member.rankTitle ?? ""}' : '직책: ${member.rankTitle ?? ""}'),

                                  // 💡 게스트 여부에 따라 연락처 텍스트 변경 (Mobile No)
                                  Text(
                                    (funcNo == '4')
                                        ? 'Mobile No: ${member.memberPhone.isEmpty ? "N/A" : member.memberPhone}'
                                        : '연락처: ${member.memberPhone.isEmpty ? "N/A" : member.memberPhone}',
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      // 🌟 게스트 모드일 경우 영문/한자 전용 페이지로 이동
                                      if (funcNo == '4') {
                                        return MemberDetailExtScreen(
                                          memberNo: member.memberNo,
                                          memberName: member.memberName,
                                          mclubNo: mclubNo,
                                        );
                                      }
                                      // 🌟 일반 모드일 경우 기존 한글 페이지로 이동
                                      else {
                                        return MemberDetailScreen(
                                          memberNo: member.memberNo,
                                          memberName: member.memberName,
                                          mclubNo: mclubNo,
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
