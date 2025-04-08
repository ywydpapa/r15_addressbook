import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import "member.dart";

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

class MemberSearchScreen extends StatefulWidget {
  @override
  _MemberSearchScreenState createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _errorMessage = '';
  List<Member> _searchResults = [];

  Future<void> _searchMembers() async {
    final keyword = _searchController.text;

    if (keyword.isEmpty) {
      setState(() {
        _errorMessage = '검색어를 입력하세요.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://192.168.11.2:8000/phapp/searchmember/$keyword'),
      );

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        Map<String, dynamic> data = json.decode(decodedResponse);

        if (data.containsKey('members')) {
          List<dynamic> members = data['members'];
          setState(() {
            _searchResults = members.map((json) => Member.fromJson(json)).toList();
            _errorMessage = ''; // 에러 메시지 초기화
          });
        } else {
          setState(() {
            _errorMessage = '검색 결과가 없습니다.';
            _searchResults = [];
          });
        }
      } else {
        setState(() {
          _errorMessage = '서버 오류 (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('회원 검색'),
      ),
      body: Column(
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
          ElevatedButton(
            onPressed: _searchMembers,
            child: Text('검색'),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(child: Text('검색 결과가 없습니다.'))
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final member = _searchResults[index];
                final imageUrl = 'http://192.168.11.2:8000/thumbnails/${member.memberNo}.png';

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
                        Text('연락처: ${member.memberPhone.isEmpty ? "N/A" : member.memberPhone}'),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MemberDetailScreen(memberNo: member.memberNo, memberName: member.memberName),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
