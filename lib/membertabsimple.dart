import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👈 토큰을 불러오기 위해 추가

class Memberdtl {
  final int? memberNo;
  final String memberName;
  final String memberPhone;
  final String rankTitle;
  final String? mPhotoBase64; // 이제 Base64가 아니라 URL 경로가 담깁니다.
  final String? memberMF;
  final String? memberAddress;
  final String? memberEmail;
  final String? addMemo;
  final String? memberBirth;
  final String? clubName;
  final String? clubNo;
  final String? nameCard; // URL 경로
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
      clubRank: json['clubRank']?.toString(),
    );
  }
}

class MemberSimpleDetailScreen extends StatefulWidget {
  final int memberNo;
  final String memberName;
  final String? mclubNo;

  const MemberSimpleDetailScreen({
    super.key,
    required this.memberNo,
    required this.memberName,
    this.mclubNo,
  });

  @override
  _MemberSimpleDetailScreenState createState() => _MemberSimpleDetailScreenState();
}

class _MemberSimpleDetailScreenState extends State<MemberSimpleDetailScreen> {
  late Future<Memberdtl> _memberDetail;

  @override
  void initState() {
    super.initState();
    _memberDetail = fetchMemberDetail(widget.memberNo);
  }

  Future<Memberdtl> fetchMemberDetail(int memberNo) async {
    // 1. 저장된 토큰 불러오기
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    // 2. 헤더에 토큰을 담아서 GET 요청 보내기
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/memberDtl/$memberNo'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);

      if (data.containsKey('memberdtl') && (data['memberdtl'] as List).isNotEmpty) {
        final memberData = data['memberdtl'][0];
        return Memberdtl.fromJson(memberData);
      } else {
        throw Exception('회원 상세 정보를 찾을 수 없습니다.');
      }
    } else {
      // 💡 에러 발생 시 상태 코드와 내용을 화면에 출력하도록 수정
      throw Exception('서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
    }
  }

  TableRow _buildTableRow(String label, String value, {bool isPhone = false}) {
    Widget valueWidget = Text(
      value,
      style: TextStyle(fontSize: 18, color: isPhone ? Colors.blue : Colors.black),
    );

    if (isPhone && value != '정보 없음' && value != '비공개') {
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

  // 💡 네트워크 이미지 위젯 생성 헬퍼 함수 (Base64 대신 URL 사용)
  Widget _buildNetworkImage(String? urlPath, double height, double width) {
    if (urlPath != null && urlPath.isNotEmpty && urlPath != '0') {
      final imageUrl = urlPath.startsWith('http') ? urlPath : '${ApiConf.baseUrl}$urlPath';

      return Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/defaultphoto.png',
            height: height,
            width: width,
            fit: BoxFit.cover,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: height,
            width: width,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
    } else {
      return Image.asset(
        'assets/defaultphoto.png',
        height: height,
        width: width,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? mclubNo = widget.mclubNo;
    return Scaffold(
      appBar: AppBar(title: Text('회원 정보')),
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
              } else if (!snapshot.hasData) {
                return Center(child: Text('No data found'));
              } else {
                final member = snapshot.data!;
                List<Widget> pages = [
                  _buildMemberInfoPage(member),
                  _buildNameCardPage(member),
                ];
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
              // 💡 Base64 대신 네트워크 이미지 함수 사용
              child: _buildNetworkImage(member.mPhotoBase64, 280, 200),
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
                  _buildTableRow('추가기재', member.addMemo ?? '없음'),
                ],
              ),
            ),
          ],
        ),
      ),
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
            // 💡 명함 이미지도 네트워크 이미지 함수 사용
            Center(
              child: _buildNetworkImage(member.nameCard, 200, 360),
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
}
