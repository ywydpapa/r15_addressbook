import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final String? bisTitle;
  final String? bisRank;
  final String? bisType;
  final String? bistypeTitle;
  final String? offTel;
  final String? offAddress;
  final String? offEmail;
  final String? offPostNo;
  final String? offWeb;
  final String? offSns;
  final String? bisMemo;
  final String? clubRank;

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
    this.bisTitle,
    this.bisRank,
    this.bisType,
    this.bistypeTitle,
    this.offTel,
    this.offAddress,
    this.offEmail,
    this.offPostNo,
    this.offWeb,
    this.offSns,
    this.bisMemo,
    this.clubRank,
  });

  factory Memberdtl.fromJson(Map<String, dynamic> json) {
    return Memberdtl(
      memberNo: json['memberNo'] as int?,
      memberName: json['memberName'] ?? '정보 없음',
      memberPhone: json['memberPhone'] ?? '정보 없음',
      rankTitle: json['rankTitle'] ?? '정보 없음',
      mPhotoBase64: (json['mPhotoBase64'] != null &&
          json['mPhotoBase64'].toString() != '0')
          ? json['mPhotoBase64'].toString()
          : null,
      memberMF: json['memberMF']?.toString() ?? '',
      memberAddress: json['memberAddress']?.toString() ?? '',
      memberEmail: json['memberEmail']?.toString() ?? '',
      addMemo: json['addMemo']?.toString() ?? '',
      memberBirth: json['memberBirth']?.toString() ?? '',
      clubName: json['clubName']?.toString() ?? '소속클럽 없음',
      clubNo: json['clubNo']?.toString(),
      nameCard: (json['nameCard'] != null && json['nameCard'].toString() != '0')
          ? json['nameCard'].toString()
          : null,
      spousePhoto: (json['spousePhoto'] != null &&
          json['spousePhoto'].toString() != '0')
          ? json['spousePhoto'].toString()
          : null,
      spouseName: json['spouseName']?.toString(),
      spousePhone: json['spousePhone']?.toString(),
      spouseBirth: json['spouseBirth']?.toString(),
      officeAddress: json['officeAddress']?.toString(),
      bisTitle: json['bisTitle']?.toString(),
      bisRank: json['bisRank']?.toString(),
      bisType: json['bisType']?.toString(),
      bistypeTitle: json['bistypeTitle']?.toString(),
      offTel: json['offtel']?.toString(),
      offAddress: json['offAddress']?.toString(),
      offEmail: json['offEmail']?.toString(),
      offPostNo: json['offPost']?.toString(),
      offWeb: json['offWeb']?.toString(),
      offSns: json['offSns']?.toString(),
      bisMemo: json['bisMemo']?.toString(),
      clubRank: json['clubRank'].toString(),
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
      Uri.parse('${ApiConf.baseUrl}/phapp/memberDtl/$memberNo'),
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);

      if (data.containsKey('memberdtl') && (data['memberdtl'] as List).isNotEmpty) {
        final memberData = data['memberdtl'][0];
        return Memberdtl.fromJson(memberData);
      } else {
        throw Exception('No member detail found');
      }
    } else {
      throw Exception('Failed to load member detail');
    }
  }

  TableRow _buildTableRow(String label, String value, {bool isPhone = false}) {
    Widget valueWidget = Text(
      value,
      style: TextStyle(fontSize: 18, color: isPhone ? Colors.blue : Colors.black),
    );

    if (isPhone && value != '정보 없음') {
      valueWidget = InkWell(
        onTap: () async {
          final Uri phoneUri = Uri(scheme: 'tel', path: value.replaceAll('-', ''));
          if (await canLaunchUrl(phoneUri)) {
            await launchUrl(phoneUri);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('전화를 걸 수 없습니다.')),
            );
          }
        },
        child: valueWidget,
      );
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: valueWidget,
        ),
      ],
    );
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
    return Scaffold(
      appBar: AppBar(title: Text('회원 상세 정보')),
      body: InteractiveViewer(
        panEnabled: true, // 드래그로 이동 가능
        scaleEnabled: true, // 핀치로 확대/축소 가능
        minScale: 1.0, // 최소 1배
        maxScale: 3.0, // 최대 3배
        child: SafeArea(
          child: FutureBuilder<Memberdtl>(
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
                List<Widget> pages = [
                  _buildMemberInfoPage(member),
                  _buildNameCardPage(member),
                ];

                if (member.clubNo != null && mclubNo != null && member.clubNo.toString() == mclubNo.toString()) {
                  pages.add(_buildSpouseInfoPage(member));
                }

                return PageView(children: pages);
              }
            },
          ),
        ),
      ),
    );
  }


  Widget _buildMemberInfoPage(Memberdtl member) {
    return SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            Center(
              child: member.mPhotoBase64 != null && member.mPhotoBase64!.isNotEmpty
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
              padding: const EdgeInsets.only(left: 16.0),
              child: Table(
                columnWidths: {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                },
                children: [
                  _buildTableRow('회원성명', member.memberName),
                  _buildTableRow('소속클럽', member.clubName ?? '정보 없음'),
                (member.clubNo?.toString() != (widget.mclubNo?.toString()))
                  ? _buildTableRow('직책', (member.rankTitle ?? ''))
                  : _buildTableRow('클럽직책', (member.clubRank ?? '')),
                  _buildTableRow('연락처', member.memberPhone, isPhone: true),
                  _buildTableRow('주소', member.memberAddress ?? '주소 없음'),
                  _buildTableRow('생년월일', member.memberBirth ?? '정보 없음'),
                  _buildTableRow('추가기재', member.addMemo ?? '없음'),
                ],
              ),
            ),
          ],
         ),
       )
    );
  }

  Widget _buildNameCardPage(Memberdtl member) {
    final String bizTypeText = (member.bisType?.trim().toUpperCase() == 'SELF')
        ? ((member.bistypeTitle?.trim().isNotEmpty == true)
        ? member.bistypeTitle!.trim()
        : '없음')
        : ((member.bisType?.trim().isNotEmpty == true)
        ? member.bisType!.trim()
        : '없음');
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Column(
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
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Table(
                columnWidths: {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                },
                children: [
                  _buildTableRow('소속클럽', member.clubName ?? '없음'),
                  _buildTableRow('업체명', member.bisTitle ?? '없음'),
                  _buildTableRow('직책', member.bisRank ?? '없음'),
                  _buildTableRow('업종', bizTypeText),
                  _buildTableRow('사무실주소', member.offAddress ?? '없음'),
                  _buildTableRow('우편번호', member.offPostNo ?? '없음'),
                  _buildTableRow('사무실전화', member.offTel ?? '없음'),
                  _buildTableRow('웹페이지', member.offWeb ?? '없음'),
                ],
              ),
            ),
          ],
        ),
      ),
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
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Table(
            columnWidths: {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
            },
            children: [
              _buildTableRow('배우자 이름', member.spouseName ?? 'Unknown'),
              _buildTableRow('배우자 연락처', member.spousePhone ?? 'Unknown'),
              _buildTableRow('배우자 생일', member.spouseBirth ?? 'Unknown'),
            ],
          ),
        ),
      ],
    );
  }
}
