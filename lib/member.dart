import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Memberdtl {
  final int? memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;
  final String? mPhotoBase64;

  Memberdtl({
    required this.memberNo,
    required this.memberName,
    required this.memberPhone,
    required this.rankTitle,
    this.mPhotoBase64,
  });

  factory Memberdtl.fromJson(Map<String, dynamic> json) {
    return Memberdtl(
      memberNo: json['memberNo'] != null ? int.tryParse(json['memberNo'].toString()) : null,
      memberName: json['memberName'] ?? '',
      memberPhone: json['memberPhone'] ?? '',
      rankTitle: json['rankTitle'] ?? '',
      mPhotoBase64: json['mPhotoBase64'],
    );
  }
}

class MemberDetailScreen extends StatefulWidget {
  final int memberNo;
  final String memberName;

  MemberDetailScreen({required this.memberNo, required this.memberName});

  @override
  _MemberDetailScreenState createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late Future<Memberdtl> _memberDetail;

  @override
  void initState() {
    super.initState();
    _memberDetail = fetchMemberDetail(widget.memberNo);
  }

  Future<Memberdtl> fetchMemberDetail(int memberNo) async {
    final response = await http.get(Uri.parse('http://192.168.11.2:8000/phapp/memberDtl/$memberNo'));

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);

      if (data.containsKey('memberdtl') && (data['memberdtl'] as List).isNotEmpty) {
        final memberData = data['memberdtl'][0];
        if (memberData.containsKey('mPhotoBase64')) {
        }
        return Memberdtl.fromJson(memberData);
      } else {
        throw Exception('No member detail found');
      }
    } else {
      throw Exception('Failed to load member detail');
    }
  }

  String cleanBase64Data(String base64Data) {
    // 헤더 제거 (예: data:image/jpeg;base64,)
    if (base64Data.contains(',')) {
      base64Data = base64Data.split(',')[1];
    }
    base64Data = base64Data.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
    return addBase64Padding(base64Data);
  }

  String addBase64Padding(String base64) {
    while (base64.length % 4 != 0) {
      base64 += '=';
    }
    return base64;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('회원 상세 정보'),
      ),
      body: FutureBuilder<Memberdtl>(
        future: _memberDetail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No data found'));
          } else {
            final member = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center, // 수평 중앙 정렬
              mainAxisAlignment: MainAxisAlignment.start, // 전체 레이아웃 상단부터 시작
              children: [
                SizedBox(height: 16), // 상단 여백
                // 사진 표시 로직
                member.mPhotoBase64 != null && member.mPhotoBase64!.isNotEmpty
                    ? Image.memory(
                  base64Decode(cleanBase64Data(member.mPhotoBase64!)),
                  height: 280,
                  width: 200,
                  fit: BoxFit.cover,
                )
                    : Image.asset(
                  'assets/defaultphoto.png',
                  height: 280,
                  width: 200,
                  fit: BoxFit.cover,
                ),
                SizedBox(height: 24), // 사진 아래 여백
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name: ${member.memberName.isNotEmpty ? member.memberName : 'No Name Available'}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text('Rank: ${member.rankTitle}'),
                      SizedBox(height: 8),
                      Text('Phone: ${member.memberPhone.isNotEmpty ? member.memberPhone : 'No Phone Available'}'),
                      SizedBox(height: 8),
                      Text('Member No: ${member.memberNo ?? 'Unknown'}'),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
