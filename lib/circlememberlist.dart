import 'package:flutter/material.dart';
import 'member.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

class Member {
  final int memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;
  final String clubName;

  Member({
    required this.memberNo,
    required this.memberName,
    required this.memberPhone,
    required this.rankTitle,
    required this.clubName,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      memberNo: json['memberNo'],
      memberName: json['memberName'],
      memberPhone: json['memberPhone'] ?? '',
      rankTitle: json['rankTitlekor'] ?? '',
      clubName: json['clubName'] ?? '',
    );
  }
}

class CircleMemberListScreen extends StatefulWidget {
  final int circleNo;
  final String circleName;

  const CircleMemberListScreen({
    super.key,
    required this.circleNo,
    required this.circleName,
  });

  @override
  _CircleMemberListScreenState createState() => _CircleMemberListScreenState();
}


class _CircleMemberListScreenState extends State<CircleMemberListScreen> {
  late int circleNo;
  late String circleName;
  late Future<List<Member>> _memberList;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  final TextEditingController _searchController = TextEditingController();

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      circleNo = widget.circleNo;
      circleName = widget.circleName;
      _memberList = fetchCircleMemberList(circleNo);
      _searchController.addListener(_filterMembers);
      _initialized = true;
    }
  }


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Member>> fetchCircleMemberList(int circleNo) async {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/getcirclemembers/$circleNo'),
    );
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> members = data['cmembers'];
      List<Member> memberList =
      members.map((json) => Member.fromJson(json)).toList();

      setState(() {
        _allMembers = memberList;
        _filteredMembers = memberList;
      });

      return memberList;
    } else {
      throw Exception('Failed to load member list');
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('$circleName 회원 목록'),
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
                  labelText: '검색',
                  hintText: '이름 또는 전화번호로 검색',
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
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No members found'));
                  } else {
                    return InteractiveViewer(
                      panEnabled: true, // 화면 이동 허용
                      scaleEnabled: true, // 확대/축소 허용
                      minScale: 0.8,
                      maxScale: 3.0,
                      child: ListView.builder(
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = _filteredMembers[index];
                          final imageUrl =
                              '${ApiConf.baseUrl}/thumbnails/${member.memberNo}.png';
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
                              title: Row(
                                children: [
                                  Text(member.memberName),
                                  SizedBox(width: 8),
                                  Text(
                                    '(${member.clubName})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('직책: ${member.rankTitle}'),
                                  Text(
                                    '연락처: ${member.memberPhone.isEmpty ? "N/A" : member.memberPhone}',
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MemberDetailScreen(
                                      memberNo: member.memberNo,
                                      memberName: member.memberName,
                                      mclubNo: '42',
                                    ),
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
