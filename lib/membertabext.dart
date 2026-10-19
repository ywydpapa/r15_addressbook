import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemberdtlExt {
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

  MemberdtlExt({
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

  factory MemberdtlExt.fromJson(Map<String, dynamic> json) {
    return MemberdtlExt(
      memberNo: json['memberNo'] as int?,
      // 💡 한자 이름이 null일 경우를 대비해 안전하게 파싱
      memberName: json['memberName']?.toString() ?? json['memberCName']?.toString() ?? json['name']?.toString() ?? 'N/A',
      memberPhone: json['memberPhone'] ?? 'N/A',
      rankTitle: json['rankTitle'] ?? 'N/A',
      mPhotoBase64: (json['mPhotoBase64'] != null && json['mPhotoBase64'].toString().isNotEmpty)
          ? json['mPhotoBase64'].toString()
          : null,
      memberMF: json['memberMF']?.toString() ?? '',
      memberAddress: json['memberAddress']?.toString() ?? '',
      memberEmail: json['memberEmail']?.toString() ?? '',
      addMemo: json['addMemo']?.toString() ?? '',
      memberBirth: json['memberBirth']?.toString() ?? '',
      clubName: json['clubName']?.toString() ?? 'N/A',
      clubNo: json['clubNo']?.toString(),
      nameCard: (json['nameCard'] != null && json['nameCard'].toString().isNotEmpty)
          ? json['nameCard'].toString()
          : null,
      spousePhoto: (json['spousePhoto'] != null && json['spousePhoto'].toString().isNotEmpty)
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
      clubRank: json['clubRank']?.toString(),
    );
  }
}

class MemberDetailExtScreen extends StatefulWidget {
  final int memberNo;
  final String memberName;
  final String? mclubNo;

  const MemberDetailExtScreen({
    super.key,
    required this.memberNo,
    required this.memberName,
    this.mclubNo,
  });

  @override
  _MemberDetailExtScreenState createState() => _MemberDetailExtScreenState();
}

class _MemberDetailExtScreenState extends State<MemberDetailExtScreen> {
  late Future<MemberdtlExt> _memberDetail;

  @override
  void initState() {
    super.initState();
    _memberDetail = fetchMemberDetail(widget.memberNo);
  }

  Future<MemberdtlExt> fetchMemberDetail(int memberNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    // 🌟 게스트 전용 API 호출
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/memberDtlext/$memberNo'),
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
        return MemberdtlExt.fromJson(memberData);
      } else {
        throw Exception('Member details not found.');
      }
    } else {
      throw Exception('Server Error!\nStatus: ${response.statusCode}');
    }
  }

  // 💡 값이 유효한지(null, 빈칸, 비공개, Private, N/A 등이 아님) 확인하는 헬퍼 함수
  bool _isVisible(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower == '비공개' ||
        lower == 'private' ||
        lower == '[비공개]' ||
        lower == '[private]' ||
        lower == '(비공개)' ||
        lower == '(private)' ||
        lower == 'n/a' ||
        lower == 'na' ||
        lower == 'none' ||
        lower == 'null' ||
        lower == '정보 없음' ||
        lower == '정보없음' ||
        lower == '없음') {
      return false;
    }
    return true;
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isPhone = false}) {
    Widget valueWidget = Text(
      value,
      style: TextStyle(
        fontSize: 17,
        color: isPhone ? Colors.blueAccent : Colors.black87,
        fontWeight: isPhone ? FontWeight.w600 : FontWeight.w500,
      ),
      textAlign: TextAlign.right,
    );

    if (isPhone && _isVisible(value)) {
      valueWidget = InkWell(
        onTap: () async {
          final Uri phoneUri = Uri(scheme: 'tel', path: value.replaceAll('-', ''));
          if (await canLaunchUrl(phoneUri)) {
            await launchUrl(phoneUri);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Cannot make a call.')),
              );
            }
          }
        },
        child: valueWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade500),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
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

  Widget _buildNetworkImage(String? urlPath, double height, double width, {double borderRadius = 16.0}) {
    Widget imageWidget;
    if (urlPath != null && _isVisible(urlPath) && urlPath != '0') {
      final imageUrl = urlPath.startsWith('http') ? urlPath : '${ApiConf.baseUrl}$urlPath';
      imageWidget = Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _defaultImage(height, width),
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
            color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildPageTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? mclubNo = widget.mclubNo;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Member Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        minScale: 1.0,
        maxScale: 3.0,
        child: SafeArea(
          child: FutureBuilder<MemberdtlExt>(
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
                return Center(child: Text('Data not found.', style: TextStyle(color: Colors.grey)));
              } else {
                final member = snapshot.data!;

                // 💡 비즈니스 탭 제거
                List<Widget> pages = [
                  _buildMemberInfoPage(member),
                ];

                final bool hasSpousePhoto = _isVisible(member.spousePhoto) && member.spousePhoto != '0';
                final bool hasSpouseData = hasSpousePhoto ||
                    _isVisible(member.spouseName) ||
                    _isVisible(member.spousePhone) ||
                    _isVisible(member.spouseBirth);

                if (member.clubNo != null &&
                    mclubNo != null &&
                    member.clubNo.toString() == mclubNo.toString() &&
                    hasSpouseData) {
                  pages.add(_buildSpouseInfoPage(member));
                }

                return PageView(
                  physics: BouncingScrollPhysics(),
                  children: pages,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMemberInfoPage(MemberdtlExt member) {
    final displayName = _isVisible(member.memberName)
        ? member.memberName
        : (_isVisible(widget.memberName) ? widget.memberName : member.memberName);

    // 1. 직책 관련 로직 정리
    final isDifferentClub = member.clubNo?.toString() != widget.mclubNo?.toString();
    final rankLabel = isDifferentClub ? 'Rank' : 'Club Rank';
    final rankValue = isDifferentClub ? member.rankTitle : (member.clubRank ?? member.rankTitle);

    // 2. 비공개(Private, 비공개, N/A 등) 및 유효하지 않은 항목은 제외하고 표시할 항목만 리스트에 담기
    final List<Widget> infoRows = [
      _buildInfoRow(Icons.person, 'Name', displayName),

      if (_isVisible(member.clubName))
        _buildInfoRow(Icons.groups, 'Club', member.clubName!),

      if (_isVisible(rankValue))
        _buildInfoRow(Icons.badge, rankLabel, rankValue),

      if (_isVisible(member.memberPhone))
        _buildInfoRow(Icons.phone_iphone, 'Mobile No', member.memberPhone, isPhone: true),

      if (_isVisible(member.memberAddress))
        _buildInfoRow(Icons.location_on, 'Address', member.memberAddress!),

      if (_isVisible(member.memberEmail))
        _buildInfoRow(Icons.email, 'Email', member.memberEmail!),

      if (_isVisible(member.memberBirth))
        _buildInfoRow(Icons.cake, 'Birth Date', member.memberBirth!),

      if (_isVisible(member.addMemo))
        _buildInfoRow(Icons.note_alt, 'Memo', member.addMemo!),
    ];

    // 3. 항목들 사이에만 Divider를 끼워 넣은 최종 리스트 생성
    final List<Widget> columnChildren = infoRows.isEmpty
        ? []
        : infoRows
            .expand((widget) => [
                  widget,
                  Divider(height: 1, color: Colors.grey.shade200),
                ])
            .toList()
          ..removeLast(); // 맨 마지막에 추가된 불필요한 Divider 제거

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPageTitle('Member Info'),
            _buildNetworkImage(member.mPhotoBase64, 260, 200, borderRadius: 20),
            if (columnChildren.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: columnChildren,
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSpouseInfoPage(MemberdtlExt member) {
    // 배우자 정보 중 비공개 및 유효하지 않은 항목 제외
    final List<Widget> spouseRows = [
      if (_isVisible(member.spouseName))
        _buildInfoRow(Icons.favorite, 'Spouse Name', member.spouseName!),

      if (_isVisible(member.spousePhone))
        _buildInfoRow(Icons.phone_iphone, 'Spouse Phone', member.spousePhone!, isPhone: true),

      if (_isVisible(member.spouseBirth))
        _buildInfoRow(Icons.cake, 'Spouse Birth Date', member.spouseBirth!),
    ];

    final List<Widget> columnChildren = spouseRows.isEmpty
        ? []
        : spouseRows
            .expand((widget) => [
                  widget,
                  Divider(height: 1, color: Colors.grey.shade200),
                ])
            .toList()
          ..removeLast();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPageTitle('Spouse Info'),
            _buildNetworkImage(member.spousePhoto, 260, 200, borderRadius: 20),
            if (columnChildren.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: columnChildren,
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
