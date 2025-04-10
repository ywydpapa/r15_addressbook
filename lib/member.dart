import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Memberdtl {
  final int? memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;
  final String? mPhotoBase64;
  final String? memberMF;
  final String? memberAddress;
  final String? memberEmail;
  final String? addMemo;
  final String? memberBirth;
  final String? clubName;
  final String? clubNo;
  final String? nameCard;
  final String? spousePhoto;
  final String? spouseName;
  final String? spousePhone;
  final String? spouseBirth;
  final String? officeAddress;

  Memberdtl({
    required this.memberNo,
    required this.memberName,
    required this.memberPhone,
    required this.rankTitle,
    this.mPhotoBase64,
    this.memberMF,
    this.memberAddress,
    this.memberEmail,
    this.addMemo,
    this.memberBirth,
    required this.clubName,
    this.clubNo,
    this.nameCard,
    this.spousePhoto,
    this.spouseName,
    this.spousePhone,
    this.spouseBirth,
    this.officeAddress,
  });

  factory Memberdtl.fromJson(Map<String, dynamic> json) {
    return Memberdtl(
      memberNo:
          json['memberNo'] != null
              ? int.tryParse(json['memberNo'].toString())
              : null,
      memberName: json['memberName'] ?? '',
      memberPhone: json['memberPhone'] ?? '',
      rankTitle: json['rankTitle'] ?? '',
      mPhotoBase64: json['mPhotoBase64'],
      memberMF: json['memberMF'] ?? '',
      memberAddress: json['memberAddress'] ?? '',
      memberEmail: json['memberEmail'] ?? '',
      addMemo: json['addMemo'] ?? '',
      memberBirth: json['memberBirth'] ?? '',
      clubName: json['clubName'] ?? '소속클럽 없음',
      clubNo: json['clubNo'] != null ? json['clubNo'].toString() : null,
      nameCard: json['nameCard'],
      spousePhoto: json['spousePhoto'],
      spouseName: json['spouseName'],
      spousePhone: json['spousePhone'],
      spouseBirth: json['spouseBirth'],
      officeAddress: json['officeAddress'],
    );
  }
}

class MemberDetailScreen extends StatefulWidget {
  final int memberNo;
  final String memberName;
  final String? mclubNo;

  const MemberDetailScreen({
    super.key,
    required this.memberNo,
    required this.memberName,
    this.mclubNo,
  });

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
    final response = await http.get(
      Uri.parse('http://192.168.11.2:8000/phapp/memberDtl/$memberNo'),
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);

      if (data.containsKey('memberdtl') &&
          (data['memberdtl'] as List).isNotEmpty) {
        final memberData = data['memberdtl'][0];
        return Memberdtl.fromJson(memberData);
      } else {
        throw Exception('No member detail found');
      }
    } else {
      throw Exception('Failed to load member detail');
    }
  }

  String cleanBase64Data(String base64Data) {
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
    final String? mclubNo = widget.mclubNo;
    print('멤버디테일에서 로그인클럽: $mclubNo'); // 디버깅용 출력
    return Scaffold(
      appBar: AppBar(title: Text('회원 상세 정보')),
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
            print('clubNo: ${member.clubNo}'); // 디버깅용 출력

            List<Widget> pages = [
              // 첫 번째 페이지: 기본 회원 정보
              _buildMemberInfoPage(member),
              // 두 번째 페이지: 명함 이미지와 소속 클럽
              _buildNameCardPage(member),
            ];

            // clubNo와 mclubNo를 비교하여 배우자 페이지 추가
            if (member.clubNo != null &&
                mclubNo != null &&
                member.clubNo == mclubNo) {
              pages.add(_buildSpouseInfoPage(member));
            }

            return PageView(children: pages);
          }
        },
      ),
    );
  }

  Widget _buildMemberInfoPage(Memberdtl member) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Center(
          child:
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
        ),
        SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '회원성명: ${member.memberName}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('소속클럽: ${member.clubName}'),
              SizedBox(height: 10),
              Text('직책: ${member.rankTitle}'),
              SizedBox(height: 10),
              Text('연락처: ${member.memberPhone}'),
              SizedBox(height: 10),
              Text('주소: ${member.memberAddress ?? 'Unknown'}'),
              SizedBox(height: 10),
              Text('생년월일: ${member.memberBirth ?? 'Unknown'}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNameCardPage(Memberdtl member) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        member.nameCard != null && member.nameCard!.isNotEmpty
            ? Image.memory(
              base64Decode(cleanBase64Data(member.nameCard!)),
              height: 200,
              width: 360,
              fit: BoxFit.cover,
            )
            : Image.asset(
              'assets/defaultphoto.png',
              height: 200,
              width: 300,
              fit: BoxFit.cover,
            ),
        SizedBox(height: 16),
        Text('소속클럽: ${member.clubName}', style: TextStyle(fontSize: 18)),
        Text('사무실주소: ${member.officeAddress}', style: TextStyle(fontSize: 18)),
      ],
    );
  }

  Widget _buildSpouseInfoPage(Memberdtl member) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        member.spousePhoto != null && member.spousePhoto!.isNotEmpty
            ? Image.memory(
              base64Decode(cleanBase64Data(member.spousePhoto!)),
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
        SizedBox(height: 16),
        Text(
          '배우자 이름: ${member.spouseName ?? 'Unknown'}',
          style: TextStyle(fontSize: 18),
        ),
        SizedBox(height: 10),
        Text(
          '배우자 연락처: ${member.spousePhone ?? 'Unknown'}',
          style: TextStyle(fontSize: 18),
        ),
        SizedBox(height: 10),
        Text(
          '배우자 생일: ${member.spouseBirth ?? 'Unknown'}',
          style: TextStyle(fontSize: 18),
        ),
      ],
    );
  }
}
