import 'package:flutter/material.dart';
import 'membertab.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 토큰을 불러오기 위해 추가

class Member {
  final int memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;

  Member({
    required this.memberNo,
    required this.memberName,
    required this.memberPhone,
    required this.rankTitle,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      memberNo: json['memberNo'],
      memberName: json['memberName'],
      memberPhone: json['memberPhone'] ?? '',
      rankTitle: json['rankTitle'] ?? '',
    );
  }
}

class MemberListScreen extends StatefulWidget {
  final int clubNo;
  final String clubName;
  final String? mclubNo;

  const MemberListScreen({
    super.key,
    required this.clubNo,
    required this.clubName,
    required this.mclubNo,
  });

  @override
  _MemberListScreenState createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  late Future<List<Member>> _memberList;
  List<Member> _allMembers = []; // 전체 멤버 리스트
  List<Member> _filteredMembers = []; // 필터링된 멤버 리스트
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _memberList = fetchMemberList(widget.clubNo);
    _searchController.addListener(_filterMembers); // 검색어 변경 시 필터링
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Member>> fetchMemberList(int clubNo) async {
    // 1. 저장된 토큰 불러오기
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    // 2. 헤더에 토큰을 담아서 GET 요청 보내기
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/memberList/$clubNo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> members = data['members'];
      List<Member> memberList =
      members.map((json) => Member.fromJson(json)).toList();

      setState(() {
        _allMembers = memberList; // 전체 멤버 리스트 저장
        _filteredMembers = memberList; // 초기에는 전체 멤버를 표시
      });

      return memberList;
    } else {
      // 💡 에러 발생 시 상태 코드와 내용을 화면에 출력하도록 수정
      throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
    }
  }

  void _filterMembers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMembers =
          _allMembers.where((member) {
            return member.memberName.toLowerCase().contains(query) ||
                member.memberPhone.toLowerCase().contains(query);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.yellow,
              pinned: true, // AppBar는 고정, flexibleSpace는 스크롤 시 사라짐
              expandedHeight: 120.0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  '${widget.clubName} 회원 리스트',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    shadows: [],
                  ),
                ),
                background: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 슬로건 영역
                    Container(
                      width: double.infinity,
                      color: Colors.yellow[200],
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        '여기에 클럽 슬로건을 입력하세요!',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: '검색',
                    hintText: '이름 또는 전화번호로 검색',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              child: FutureBuilder<List<Member>>(
                future: _memberList,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    // 에러 메시지를 잘 보이게 빨간색으로 가운데 정렬
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No members found'));
                  } else {
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(), // 중첩 스크롤 방지
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];

                        // 💡 썸네일 이미지 경로에 mphoto_ 추가
                        final imageUrl =
                            '${ApiConf.baseUrl}/thumbnails/mphoto_${member.memberNo}.png';

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
                                      'assets/default.png',
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
                                Text('직책: ${member.rankTitle}'),
                                Text(
                                  '연락처: ${member.memberPhone.isEmpty
                                      ? "N/A"
                                      : member.memberPhone}',
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MemberDetailScreen(
                                        memberNo: member.memberNo,
                                        memberName: member.memberName,
                                        mclubNo: widget.mclubNo,
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
          ],
        ),
      ),
    );
  }
}
