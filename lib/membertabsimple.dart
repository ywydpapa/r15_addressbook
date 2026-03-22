import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  _MemberSimpleDetailScreenState createState() =>
      _MemberSimpleDetailScreenState();
}

class _MemberSimpleDetailScreenState extends State<MemberSimpleDetailScreen> {
  late Future<Memberdtl> _memberDetail;

  @override
  void initState() {
    super.initState();
    _memberDetail = fetchMemberDetail(widget.memberNo);
  }

  Future<Memberdtl> fetchMemberDetail(int memberNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

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

      if (data.containsKey('memberdtl') &&
          (data['memberdtl'] as List).isNotEmpty) {
        final memberData = data['memberdtl'][0];
        return Memberdtl.fromJson(memberData);
      } else {
        throw Exception('회원 상세 정보를 찾을 수 없습니다.');
      }
    } else {
      throw Exception(
          '서버 에러 발생!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}');
    }
  }

  // 🎨 글씨 크기를 키우고 세련되게 변경한 리스트 항목 위젯
  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isPhone = false}) {
    Widget valueWidget = Text(
      value,
      style: TextStyle(
        fontSize: 17, // 💡 글씨 크기 확대 (기존 15 -> 17)
        color: isPhone ? Colors.blueAccent : Colors.black87,
        fontWeight: isPhone ? FontWeight.w600 : FontWeight.w500,
      ),
      textAlign: TextAlign.right,
    );

    if (isPhone && value != '정보 없음' && value != '비공개') {
      valueWidget = InkWell(
        onTap: () async {
          final Uri phoneUri =
          Uri(scheme: 'tel', path: value.replaceAll('-', ''));
          if (await canLaunchUrl(phoneUri)) {
            await launchUrl(phoneUri);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('전화를 걸 수 없습니다.')),
              );
            }
          }
        },
        child: valueWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), // 💡 여백도 살짝 넓힘
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade500), // 💡 아이콘 크기 확대
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 17, // 💡 라벨 글씨 크기 확대
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget,
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 그림자와 둥근 모서리가 적용된 이미지 위젯
  Widget _buildNetworkImage(String? urlPath, double height, double width,
      {double borderRadius = 16.0}) {
    Widget imageWidget;
    if (urlPath != null && urlPath.isNotEmpty && urlPath != '0') {
      final imageUrl = urlPath.startsWith('http')
          ? urlPath
          : '${ApiConf.baseUrl}$urlPath';
      imageWidget = Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _defaultImage(height, width),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: height,
            width: width,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    } else {
      imageWidget = _defaultImage(height, width);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      ),
    );
  }

  Widget _defaultImage(double height, double width) {
    return Image.asset(
      'assets/defaultphoto.png',
      height: height,
      width: width,
      fit: BoxFit.cover,
    );
  }

  // 🎨 페이지 상단 타이틀 위젯
  Widget _buildPageTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22, // 💡 타이틀 글씨 크기도 약간 키움
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // 🎨 배경색 지정
      appBar: AppBar(
        title: Text('회원 정보', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0, // 🎨 앱바 그림자 제거로 모던함 강조
        centerTitle: true,
      ),
      body: InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 3.0,
        child: SafeArea(
          child: FutureBuilder<Memberdtl>(
            future: _memberDetail,
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
                      style: TextStyle(color: Colors.redAccent, fontSize: 16),
                    ),
                  ),
                );
              } else if (!snapshot.hasData) {
                return Center(
                    child: Text('데이터를 찾을 수 없습니다.',
                        style: TextStyle(color: Colors.grey)));
              } else {
                final member = snapshot.data!;
                List<Widget> pages = [
                  _buildMemberInfoPage(member),
                  _buildNameCardPage(member),
                ];
                return PageView(
                  physics: BouncingScrollPhysics(), // 🎨 부드러운 스크롤 효과
                  children: pages,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMemberInfoPage(Memberdtl member) {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPageTitle('기본 정보'),
            _buildNetworkImage(member.mPhotoBase64, 260, 200, borderRadius: 20),
            SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.person, '회원성명', member.memberName),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(
                      Icons.groups, '소속클럽', member.clubName ?? '정보 없음'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  (member.clubNo?.toString() != (widget.mclubNo?.toString()))
                      ? _buildInfoRow(
                      Icons.badge, '직책', member.rankTitle.isNotEmpty ? member.rankTitle : '정보 없음')
                      : _buildInfoRow(
                      Icons.badge, '클럽직책', member.clubRank ?? '정보 없음'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.phone_iphone, '연락처', member.memberPhone,
                      isPhone: true),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.note_alt, '추가기재', member.addMemo ?? '없음'),
                ],
              ),
            ),
            SizedBox(height: 30), // 하단 여백
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
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPageTitle('명함 정보'),
            _buildNetworkImage(member.nameCard, 220, double.infinity,
                borderRadius: 12),
            SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildInfoRow(Icons.groups, '소속클럽', member.clubName ?? '없음'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(
                      Icons.business, '업체명', member.bisTitle ?? '없음'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.work, '직책', member.bisRank ?? '없음'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.category, '업종', bizTypeText),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.business_center, '사무실주소',
                      member.offAddress ?? '없음'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(
                      Icons.markunread_mailbox, '우편번호', member.offPostNo ?? '없음'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.phone, '사무실전화', member.offTel ?? '없음',
                      isPhone: true),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow(Icons.language, '웹페이지', member.offWeb ?? '없음'),
                ],
              ),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
