import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'membertab.dart';
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 토큰을 불러오기 위해 추가

// Member 모델은 그대로 두세요
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
      rankTitle: json['rankTitle'] ?? '',
      clubName: json['clubName'] ?? '',
    );
  }
}

// StatefulWidget으로 선언
class MemberSearchScreen extends StatefulWidget {
  const MemberSearchScreen({Key? key}) : super(key: key);

  @override
  _MemberSearchScreenState createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _errorMessage = '';
  List<Member> _searchResults = [];
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
    }
  }

  Future<void> _searchMembers() async {
    final keyword = _searchController.text;

    if (keyword.isEmpty) {
      setState(() {
        _errorMessage = '검색어를 입력하세요.';
      });
      return;
    }

    if (mregionNo == null) {
      setState(() {
        _errorMessage = '지역 정보가 없습니다.';
      });
      return;
    }

    try {
      // 1. 저장된 토큰 불러오기
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      // 2. 헤더에 토큰을 담아서 GET 요청 보내기
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/rsearchmember/$mregionNo/$keyword'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        Map<String, dynamic> data = json.decode(decodedResponse);

        if (data.containsKey('members')) {
          List<dynamic> members = data['members'];
          setState(() {
            _searchResults =
                members.map((json) => Member.fromJson(json)).toList();
            _errorMessage = ''; // 에러 메시지 초기화
          });
        } else {
          setState(() {
            _errorMessage = '검색 결과가 없습니다.';
            _searchResults = [];
          });
        }
      } else {
        // 💡 에러 발생 시 상태 코드와 내용을 화면에 출력하도록 수정
        setState(() {
          _errorMessage = '서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}';
          _searchResults = [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류: $e';
        _searchResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.yellow, title: Text('회원 검색')),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '검색어를 입력하세요',
                  hintText: '이름 또는 전화번호로 검색',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            ElevatedButton(onPressed: _searchMembers, child: Text('검색')),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: _searchResults.isEmpty && _errorMessage.isEmpty
                  ? Center(child: Text('검색 결과가 없습니다.'))
                  : InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.8,
                maxScale: 3.0,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final member = _searchResults[index];

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
