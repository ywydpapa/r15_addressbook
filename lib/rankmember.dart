import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'member.dart'; // 필요시 주석 해제
import 'config/api_config.dart';

// Member 모델 정의
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
    // 빈 문자열 직책은 '미지정'으로 치환
    String rank = (json['rankTitle'] ?? '').toString().trim();
    if (rank.isEmpty) rank = '미지정';
    return Member(
      memberNo: json['memberNo'],
      memberName: json['memberName'],
      memberPhone: json['memberPhone'] ?? '',
      rankTitle: rank,
      clubName: json['clubName'] ?? '',
    );
  }
}

// 메인 화면
class RankMemberScreen extends StatefulWidget {
  const RankMemberScreen({super.key});

  @override
  _RankMemberScreenState createState() => _RankMemberScreenState();
}

class _RankMemberScreenState extends State<RankMemberScreen> {
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  String _selectedRank = '전체';
  List<String> _rankTitles = [];
  int? mregionNo;
  String? mclubNo;
  bool _isLoading = true;
  String? _errorMsg;

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
      if (mregionNo != null) {
        _fetchMemberList(mregionNo!);
      }
    }
  }

  Future<void> _fetchMemberList(int mregionNo) async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/rnkmemberList/$mregionNo'),
      );

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        Map<String, dynamic> data = json.decode(decodedResponse);
        List<dynamic> members = data['members'];
        List<Member> memberList =
        members.map((json) => Member.fromJson(json)).toList();

        final rankTitles = memberList
            .map((member) => member.rankTitle)
            .toSet()
            .toList()
          ..sort();

        setState(() {
          _allMembers = memberList;
          // 여기서 _filteredMembers를 _selectedRank에 따라 할당
          if (_selectedRank == '전체') {
            _filteredMembers = memberList;
          } else {
            _filteredMembers = memberList.where((m) => m.rankTitle == _selectedRank).toList();
          }
          _rankTitles = rankTitles;
          if (!_rankTitles.contains(_selectedRank) && _selectedRank != '전체') {
            _selectedRank = '전체';
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMsg = 'Failed to load member list';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Error: $e';
        _isLoading = false;
      });
    }
  }


  void _filterMembersByRank(String rankTitle) {
    setState(() {
      _selectedRank = rankTitle;
      if (rankTitle == '전체') {
        _filteredMembers = _allMembers;
      } else {
        _filteredMembers = _allMembers.where((member) => member.rankTitle == rankTitle).toList();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    // value가 items에 없으면 강제로 '전체'로 맞춤
    final dropdownItems = ['전체', ..._rankTitles];
    if (!dropdownItems.contains(_selectedRank)) {
      _selectedRank = '전체';
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('직책별 회원 리스트')),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: Column(
          children: [
            // 드롭다운 필터
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedRank,
                items: dropdownItems
                    .map((rank) => DropdownMenuItem(value: rank, child: Text(rank)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _filterMembersByRank(value);
                  }
                },
                decoration: InputDecoration(
                  labelText: '직책 선택',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            // 멤버 리스트
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _errorMsg != null
                  ? Center(child: Text(_errorMsg!))
                  : _filteredMembers.isEmpty
                  ? Center(child: Text('No members found'))
                  : InteractiveViewer(
                panEnabled: true,     // 드래그로 이동 가능
                scaleEnabled: true,   // 핀치 줌 가능
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
                                mclubNo: mclubNo,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
