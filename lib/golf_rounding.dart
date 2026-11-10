import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'package:r15_addressbook/config/secure_storage.dart';

const Color primaryNavy = Color(0xFF003366);
const Color primaryGold = Color(0xFFFFC107);
const Color bgColor = Color(0xFFF8F9FA);

// =========================================================
// 1. 써클별 골프 라운딩 목록 화면
// =========================================================
class GolfRoundingListScreen extends StatefulWidget {
  final int circleNo;
  final String circleName;

  const GolfRoundingListScreen({
    super.key,
    required this.circleNo,
    required this.circleName,
  });

  @override
  State<GolfRoundingListScreen> createState() => _GolfRoundingListScreenState();
}

class _GolfRoundingListScreenState extends State<GolfRoundingListScreen> {
  List<dynamic> _roundings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoundings();
  }

  Future<void> _fetchRoundings() async {
    setState(() => _isLoading = true);
    try {
      final token = await SecureStorage.getAccessToken();
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/getcirclerounding/${widget.circleNo}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);
        if (mounted) {
          setState(() {
            _roundings = data['roundings'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('골프 라운딩 목록 조회 오류: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 💡 관리자 비밀번호 확인 팝업
  void _showAdminPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: primaryNavy),
              SizedBox(width: 8),
              Text('관리자 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('일정을 생성하려면 관리자 비밀번호를 입력하세요.'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호를 입력해주세요.')),
                  );
                  return;
                }

                try {
                  final token = await SecureStorage.getAccessToken();
                  final res = await http.get(
                    Uri.parse('${ApiConf.baseUrl}/phapp/chkrightcircleevent/${widget.circleNo}/$password'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                  );

                  if (res.statusCode == 200) {
                    final data = jsonDecode(utf8.decode(res.bodyBytes));
                    if (data['chkkey'] != null && data['chkkey'] > 0) {
                      Navigator.pop(dialogContext);
                      _showAddRoundingDialog();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호 검증 중 오류가 발생했습니다.')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('네트워크 오류: $e')),
                  );
                }
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 💡 새 라운딩 일정 생성 폼 다이얼로그
  void _showAddRoundingDialog() {
    final titleController = TextEditingController();
    final golfClubController = TextEditingController();
    final courseController = TextEditingController();
    final greenFeeController = TextEditingController();
    final memoController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
            final timeStr = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00";

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.sports_golf, color: primaryNavy),
                  SizedBox(width: 8),
                  Text('새 라운딩 일정 등록', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '라운딩 제목 *',
                        hintText: '예: 5월 정기 월례회 라운딩',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: golfClubController,
                      decoration: const InputDecoration(
                        labelText: '골프장 이름',
                        hintText: '예: 베네스트 GC',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: courseController,
                      decoration: const InputDecoration(
                        labelText: '코스 이름',
                        hintText: '예: IN - OUT',
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 날짜 선택
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: primaryNavy),
                            const SizedBox(width: 8),
                            Text('일자: $dateStr', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 시간 선택
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: primaryNavy),
                            const SizedBox(width: 8),
                            Text('티오프: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: greenFeeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '그린피 (원)',
                        hintText: '예: 200000',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: memoController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '메모 / 안내사항',
                        hintText: '회비, 복장 등 전달사항',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('라운딩 제목을 입력해 주세요.')),
                      );
                      return;
                    }

                    try {
                      final token = await SecureStorage.getAccessToken();
                      final bodyData = jsonEncode({
                        "circleNo": widget.circleNo,
                        "roundingTitle": title,
                        "golfClubName": golfClubController.text.trim(),
                        "courseName": courseController.text.trim(),
                        "roundingDate": dateStr,
                        "roundingTime": timeStr,
                        "greenFee": greenFeeController.text.trim(),
                        "memo": memoController.text.trim(),
                      });

                      final response = await http.post(
                        Uri.parse('${ApiConf.baseUrl}/phapp/insertcirclerounding'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: bodyData,
                      );

                      if (response.statusCode == 200) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('라운딩 일정이 등록되었습니다.')),
                        );
                        _fetchRoundings();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('일정 등록에 실패했습니다.')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류 발생: $e')),
                      );
                    }
                  },
                  child: const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.circleName} 라운딩',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryNavy))
            : RefreshIndicator(
                color: primaryNavy,
                onRefresh: _fetchRoundings,
                child: _roundings.isEmpty
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.7,
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.sports_golf, size: 60, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                '등록된 골프 라운딩 일정이 없습니다.',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _roundings.length,
                        itemBuilder: (context, index) {
                          final item = _roundings[index];
                          final roundingNo = item['roundingNo'] ?? 0;
                          final title = item['roundingTitle'] ?? '라운딩';
                          final golfClub = item['golfClubName'] ?? '';
                          final course = item['courseName'] ?? '';
                          final rDate = item['roundingDate'] ?? '';
                          final rTime = item['roundingTime'] ?? '';
                          final greenFee = item['greenFee'] ?? '';
                          final teamCount = item['teamCount'] ?? 0;
                          final memberCount = item['memberCount'] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GolfRoundingDetailScreen(
                                      roundingNo: roundingNo,
                                      title: title,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: primaryNavy.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.calendar_today, size: 14, color: primaryNavy),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$rDate $rTime',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryNavy,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.chevron_right, color: Colors.grey),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.flag_outlined, size: 16, color: Colors.green),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            course.isNotEmpty ? '$golfClub ($course)' : golfClub,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.groups_outlined, size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$teamCount개 조 ($memberCount명 참석)',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                        ),
                                        if (greenFee != null && greenFee.toString().isNotEmpty) ...[
                                          const SizedBox(width: 12),
                                          const Icon(Icons.monetization_on_outlined, size: 16, color: primaryGold),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$greenFee원',
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAdminPasswordDialog,
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('라운딩 일정 추가', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// =========================================================
// 2. 골프 라운딩 상세 화면 (조 편성 & 성적/시상)
// =========================================================
class GolfRoundingDetailScreen extends StatefulWidget {
  final int roundingNo;
  final String title;

  const GolfRoundingDetailScreen({
    super.key,
    required this.roundingNo,
    required this.title,
  });

  @override
  State<GolfRoundingDetailScreen> createState() => _GolfRoundingDetailScreenState();
}

class _GolfRoundingDetailScreenState extends State<GolfRoundingDetailScreen> {
  Map<String, dynamic>? _roundingInfo;
  List<dynamic> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _isLoading = true);
    try {
      final token = await SecureStorage.getAccessToken();
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/getcircleroundingdetail/${widget.roundingNo}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);
        if (mounted) {
          setState(() {
            _roundingInfo = data['rounding'];
            _teams = data['teams'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('골프 라운딩 상세 조회 오류: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAwardPublished = _roundingInfo?['awardPublished'] == 'Y';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: primaryGold,
            indicatorWeight: 3,
            labelColor: primaryGold,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(text: '🚩 조 편성 및 시간표'),
              Tab(text: '🏆 성적 및 시상 결과'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryNavy))
            : TabBarView(
                children: [
                  _buildTeamsTab(),
                  _buildAwardsTab(isAwardPublished),
                ],
              ),
      ),
    );
  }

  bool _isAdmin = false;

  // 💡 관리자 비밀번호 확인 후 동작 실행
  void _verifyAdminPassword(VoidCallback onAuthorized) {
    if (_isAdmin) {
      onAuthorized();
      return;
    }

    final passwordController = TextEditingController();
    final circleNo = _roundingInfo?['circleNo'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: primaryNavy),
              SizedBox(width: 8),
              Text('관리자 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('조 편성 및 선수를 편집하려면 관리자 비밀번호를 입력하세요.'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호를 입력해주세요.')),
                  );
                  return;
                }

                try {
                  final token = await SecureStorage.getAccessToken();
                  final res = await http.get(
                    Uri.parse('${ApiConf.baseUrl}/phapp/chkrightcircleevent/$circleNo/$password'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $token',
                    },
                  );

                  if (res.statusCode == 200) {
                    final data = jsonDecode(utf8.decode(res.bodyBytes));
                    if (data['chkkey'] != null && data['chkkey'] > 0) {
                      Navigator.pop(dialogContext);
                      setState(() => _isAdmin = true);
                      onAuthorized();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호 검증 오류')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('오류: $e')),
                  );
                }
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 💡 새 조(팀) 추가 다이얼로그
  void _showAddTeamDialog() {
    final teamNameController = TextEditingController(text: '${_teams.length + 1}조');
    final courseController = TextEditingController(text: _roundingInfo?['courseName'] ?? '');
    final memoController = TextEditingController();
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final timeStr = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00";

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.group_add, color: primaryNavy),
                  SizedBox(width: 8),
                  Text('새 조(팀) 추가', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: teamNameController,
                      decoration: const InputDecoration(
                        labelText: '조 명칭 *',
                        hintText: '예: 1조, OUT 1조',
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setDialogState(() => selectedTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 18, color: primaryNavy),
                            const SizedBox(width: 8),
                            Text(
                              '티타임: ${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: courseController,
                      decoration: const InputDecoration(
                        labelText: '코스명',
                        hintText: '예: OUT 코스',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        labelText: '메모',
                        hintText: '예: 카트 1호',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  onPressed: () async {
                    final tName = teamNameController.text.trim();
                    if (tName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('조 명칭을 입력해 주세요.')),
                      );
                      return;
                    }

                    try {
                      final token = await SecureStorage.getAccessToken();
                      final bodyData = jsonEncode({
                        "roundingNo": widget.roundingNo,
                        "teamName": tName,
                        "teeTime": timeStr,
                        "courseName": courseController.text.trim(),
                        "memo": memoController.text.trim(),
                        "teamOrder": _teams.length + 1,
                      });

                      final res = await http.post(
                        Uri.parse('${ApiConf.baseUrl}/phapp/insertcircleroundingteam'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: bodyData,
                      );

                      if (res.statusCode == 200) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('조(팀)가 생성되었습니다.')),
                        );
                        _fetchDetail();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('조 생성에 실패했습니다.')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류: $e')),
                      );
                    }
                  },
                  child: const Text('생성'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💡 선수 추가 다이얼로그 (써클 회원 선택 & 비회원 게스트 직접 입력 지원)
  void _showAddPlayerDialog(int teamNo, String teamName, int existingCount) async {
    final circleNo = _roundingInfo?['circleNo'] ?? 0;
    List<dynamic> circleMembers = [];
    bool isFetchingMembers = true;

    final guestNameController = TextEditingController();
    final guestClubController = TextEditingController(text: '게스트');
    final guestRankController = TextEditingController(text: '초대손님');
    final handicapController = TextEditingController();
    final memoController = TextEditingController();

    Map<String, dynamic>? selectedMember;
    int selectedTab = 0; // 0: 회원 선택, 1: 비회원(게스트) 직접 입력

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isFetchingMembers && circleMembers.isEmpty) {
              SecureStorage.getAccessToken().then((token) {
                http.get(
                  Uri.parse('${ApiConf.baseUrl}/phapp/getcirclemembers/$circleNo'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                ).then((res) {
                  if (res.statusCode == 200) {
                    final data = jsonDecode(utf8.decode(res.bodyBytes));
                    if (dialogContext.mounted) {
                      setDialogState(() {
                        circleMembers = data['cmembers'] ?? [];
                        isFetchingMembers = false;
                      });
                    }
                  } else {
                    if (dialogContext.mounted) {
                      setDialogState(() => isFetchingMembers = false);
                    }
                  }
                }).catchError((_) {
                  if (dialogContext.mounted) {
                    setDialogState(() => isFetchingMembers = false);
                  }
                });
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.person_add, color: primaryNavy),
                  const SizedBox(width: 8),
                  Text('$teamName 선수 추가', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 탭 선택 (회원 vs 게스트)
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('써클 회원'),
                            selected: selectedTab == 0,
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedTab = 0);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('비회원(게스트)'),
                            selected: selectedTab == 1,
                            onSelected: (val) {
                              if (val) setDialogState(() => selectedTab = 1);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (selectedTab == 0) ...[
                      if (isFetchingMembers)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: primaryNavy),
                        )
                      else if (circleMembers.isEmpty)
                        const Text('써클 회원 목록이 없거나 불러올 수 없습니다.')
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          decoration: const InputDecoration(
                            labelText: '회원 선택 *',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedMember,
                          items: circleMembers.map((m) {
                            final mName = m['memberName'] ?? '회원';
                            final cName = m['clubName'] ?? '';
                            final rTitle = m['rankTitle'] ?? '';
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: m,
                              child: Text('$mName ($cName $rTitle)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedMember = val);
                          },
                        ),
                    ] else ...[
                      TextField(
                        controller: guestNameController,
                        decoration: const InputDecoration(
                          labelText: '게스트 성명 *',
                          hintText: '예: 홍길동',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: guestClubController,
                        decoration: const InputDecoration(
                          labelText: '소속 / 클럽명',
                          hintText: '예: 게스트, XX클럽',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: guestRankController,
                        decoration: const InputDecoration(
                          labelText: '직책 / 구분',
                          hintText: '예: 초대손님, 대표',
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    TextField(
                      controller: handicapController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '핸디캡 (HDCP)',
                        hintText: '예: 18',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        labelText: '선수 메모',
                        hintText: '비고 사항',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  onPressed: () async {
                    int memberNo = 0;
                    String memberName = '';
                    String clubName = '';
                    String rankTitle = '';

                    if (selectedTab == 0) {
                      if (selectedMember == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('회원을 선택해 주세요.')),
                        );
                        return;
                      }
                      memberNo = int.tryParse(selectedMember!['memberNo'].toString()) ?? 0;
                      memberName = (selectedMember!['memberName'] ?? '').toString();
                      clubName = (selectedMember!['clubName'] ?? '').toString();
                      rankTitle = (selectedMember!['rankTitle'] ?? '').toString();
                    } else {
                      memberName = guestNameController.text.trim();
                      if (memberName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('게스트 성명을 입력해 주세요.')),
                        );
                        return;
                      }
                      memberNo = 0;
                      clubName = guestClubController.text.trim();
                      rankTitle = guestRankController.text.trim();
                    }

                    try {
                      final token = await SecureStorage.getAccessToken();
                      final bodyData = jsonEncode({
                        "roundingNo": widget.roundingNo,
                        "teamNo": teamNo,
                        "playerOrder": existingCount + 1,
                        "memberNo": memberNo,
                        "memberName": memberName,
                        "clubName": clubName,
                        "rankTitle": rankTitle,
                        "handicap": handicapController.text.trim(),
                        "memo": memoController.text.trim(),
                      });

                      final res = await http.post(
                        Uri.parse('${ApiConf.baseUrl}/phapp/insertcircleroundingplayer'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: bodyData,
                      );

                      if (res.statusCode == 200) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('선수가 추가되었습니다.')),
                        );
                        _fetchDetail();
                      } else {
                        final decodedErr = utf8.decode(res.bodyBytes);
                        print('insertcircleroundingplayer error: $decodedErr');
                        String errMsg = '선수 추가 실패 (${res.statusCode})';
                        try {
                          final errData = jsonDecode(decodedErr);
                          if (errData is Map && errData.containsKey('detail')) {
                            errMsg = errData['detail'].toString();
                          }
                        } catch (_) {}
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errMsg)),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류: $e')),
                      );
                    }
                  },
                  child: const Text('추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💡 조 삭제 처리
  void _deleteTeam(int teamNo, String teamName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('조 삭제'),
        content: Text('‘$teamName’ 및 소속 선수를 모두 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final token = await SecureStorage.getAccessToken();
                final res = await http.post(
                  Uri.parse('${ApiConf.baseUrl}/phapp/deletecircleroundingteam/$teamNo'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                );
                if (res.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('조가 삭제되었습니다.')),
                  );
                  _fetchDetail();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('삭제 오류: $e')),
                );
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 💡 개별 선수 삭제 처리
  void _deletePlayer(int rmId, String memberName) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('선수 삭제'),
        content: Text('‘$memberName’ 선수를 이 조에서 제외하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final token = await SecureStorage.getAccessToken();
                final res = await http.post(
                  Uri.parse('${ApiConf.baseUrl}/phapp/deletecircleroundingplayer/$rmId'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                );
                if (res.statusCode == 200) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('선수가 제외되었습니다.')),
                  );
                  _fetchDetail();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('삭제 오류: $e')),
                );
              }
            },
            child: const Text('제외'),
          ),
        ],
      ),
    );
  }

  // 💡 시상 결과 공개 여부 및 총평 설정 다이얼로그
  void _showPublishAwardDialog() {
    bool isPublished = _roundingInfo?['awardPublished'] == 'Y';
    final memoController = TextEditingController(text: _roundingInfo?['awardMemo'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.campaign, color: primaryNavy),
                  SizedBox(width: 8),
                  Text('시상 공개 & 총평 설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('성적 및 시상 공개', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isPublished ? '회원들에게 성적표 및 시상이 노출됩니다.' : '현재 비공개 상태입니다.'),
                    value: isPublished,
                    activeColor: primaryGold,
                    activeTrackColor: primaryNavy,
                    onChanged: (val) {
                      setDialogState(() => isPublished = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: memoController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '대회 총평 / 안내 메시지',
                      hintText: '예: 제15회 총재배 라운딩이 성공리에 마쳤습니다...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      final token = await SecureStorage.getAccessToken();
                      final bodyData = jsonEncode({
                        "roundingNo": widget.roundingNo,
                        "awardPublished": isPublished ? "Y" : "N",
                        "awardMemo": memoController.text.trim(),
                      });

                      final res = await http.post(
                        Uri.parse('${ApiConf.baseUrl}/phapp/publishcircleroundingaward'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: bodyData,
                      );

                      if (res.statusCode == 200) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('시상 공개 설정이 반영되었습니다.')),
                        );
                        _fetchDetail();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('설정 저장 실패')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류: $e')),
                      );
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💡 개별 선수 성적 및 시상 수정 다이얼로그
  void _showEditScoreAwardDialog(Map<String, dynamic> player) {
    final name = player['memberName'] ?? '선수';
    final grossController = TextEditingController(text: player['grossScore']?.toString() ?? '');
    final netController = TextEditingController(text: player['netScore']?.toString() ?? '');
    final rankController = TextEditingController(text: player['ranking']?.toString() ?? '');
    final awardNameController = TextEditingController(text: player['awardName']?.toString() ?? '');
    final awardPrizeController = TextEditingController(text: player['awardPrize']?.toString() ?? '');
    final memoController = TextEditingController(text: player['scoreMemo']?.toString() ?? '');

    final presetAwards = ['우승', '준우승', '3위', '메달리스트', '롱기스트', '니어리스트', '다버디상', '다파상', '행운상'];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.emoji_events, color: primaryGold),
                  const SizedBox(width: 8),
                  Text('$name 성적/시상 입력', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rankController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '순위', hintText: '예: 1'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: grossController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '그로스(타수) *', hintText: '예: 78'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: netController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'NET 타수', hintText: '예: 70.4'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('시상명 퀵 선택', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: presetAwards.map((a) {
                        return ActionChip(
                          label: Text(a, style: const TextStyle(fontSize: 11)),
                          backgroundColor: awardNameController.text == a ? primaryGold : Colors.grey.shade200,
                          onPressed: () {
                            setDialogState(() => awardNameController.text = a);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: awardNameController,
                      decoration: const InputDecoration(labelText: '시상명 직접 입력', hintText: '예: 메달리스트, 롱기스트'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: awardPrizeController,
                      decoration: const InputDecoration(labelText: '시상 상품 / 부상', hintText: '예: 트레비어 상품권 10만원'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(labelText: '비고 / 메모', hintText: '참고사항'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  onPressed: () async {
                    final gross = int.tryParse(grossController.text.trim());
                    final net = double.tryParse(netController.text.trim());
                    final rank = int.tryParse(rankController.text.trim());

                    try {
                      final token = await SecureStorage.getAccessToken();
                      final bodyData = jsonEncode({
                        "rmId": player['rmId'],
                        "grossScore": gross,
                        "netScore": net,
                        "ranking": rank,
                        "awardName": awardNameController.text.trim(),
                        "awardPrize": awardPrizeController.text.trim(),
                        "scoreMemo": memoController.text.trim(),
                      });

                      final res = await http.post(
                        Uri.parse('${ApiConf.baseUrl}/phapp/updatecircleroundingplayer'),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': 'Bearer $token',
                        },
                        body: bodyData,
                      );

                      if (res.statusCode == 200) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$name 선수 성적/시상이 저장되었습니다.')),
                        );
                        _fetchDetail();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('성적 저장 실패')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('오류: $e')),
                      );
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💡 전체 선수 목록에서 선택하여 성적 입력하는 팝업
  void _showBatchScoreSelectDialog() {
    List<dynamic> allPlayers = [];
    for (var team in _teams) {
      final pList = team['players'] as List<dynamic>?;
      if (pList != null) {
        allPlayers.addAll(pList);
      }
    }

    if (allPlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 선수가 없습니다. 먼저 조 및 선수를 배치해 주세요.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note, color: primaryNavy),
              SizedBox(width: 8),
              Text('선수 선택 (성적/시상 입력)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: allPlayers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = allPlayers[idx];
                final name = p['memberName'] ?? '선수';
                final club = p['clubName'] ?? '';
                final gross = p['grossScore'] != null ? '${p['grossScore']}타' : '타수 미입력';
                final award = p['awardName'] ?? '';

                return ListTile(
                  dense: true,
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$club | $gross ${award.isNotEmpty ? "($award)" : ""}'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _showEditScoreAwardDialog(p);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  // 🚩 1. 조 편성 & 티타임 탭
  Widget _buildTeamsTab() {
    if (_roundingInfo == null) {
      return const Center(child: Text('정보를 불러올 수 없습니다.'));
    }

    final golfClub = _roundingInfo!['golfClubName'] ?? '';
    final course = _roundingInfo!['courseName'] ?? '';
    final rDate = _roundingInfo!['roundingDate'] ?? '';
    final rTime = _roundingInfo!['roundingTime'] ?? '';
    final greenFee = _roundingInfo!['greenFee'] ?? '';
    final memo = _roundingInfo!['memo'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라운딩 대표 정보 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_golf, color: primaryNavy, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        golfClub.isNotEmpty ? '$golfClub ($course)' : '골프장 미정',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text('일시: $rDate $rTime', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  ],
                ),
                if (greenFee != null && greenFee.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: Colors.black54),
                      const SizedBox(width: 6),
                      Text('그린피: $greenFee원', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    ],
                  ),
                ],
                if (memo.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '메모: $memo',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text(
                '조 편성 및 티타임',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _verifyAdminPassword(_showAddTeamDialog),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('조(팀) 추가', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_teams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('등록된 조 정보가 없습니다. 상단 [+ 조(팀) 추가]를 눌러 생성해 주세요.')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _teams.length,
              itemBuilder: (context, tIndex) {
                final team = _teams[tIndex];
                final teamNo = team['teamNo'] ?? 0;
                final teamName = team['teamName'] ?? '${tIndex + 1}조';
                final teeTime = team['teeTime'] ?? '';
                final tCourse = team['courseName'] ?? '';
                final players = (team['players'] as List<dynamic>?) ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      // 조 헤더 (선수 추가 / 조 삭제 버튼 연동)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryNavy.withOpacity(0.06),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              teamName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy),
                            ),
                            if (teeTime.toString().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.access_time, size: 14, color: primaryNavy),
                              const SizedBox(width: 2),
                              Text(
                                teeTime,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryNavy),
                              ),
                            ],
                            if (tCourse.toString().isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                '($tCourse)',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.person_add_alt_1, color: primaryNavy, size: 20),
                              tooltip: '선수 추가',
                              onPressed: () => _verifyAdminPassword(() {
                                _showAddPlayerDialog(teamNo, teamName, players.length);
                              }),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: '조 삭제',
                              onPressed: () => _verifyAdminPassword(() {
                                _deleteTeam(teamNo, teamName);
                              }),
                            ),
                          ],
                        ),
                      ),
                      // 조원 리스트
                      if (players.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              const Text('등록된 선수가 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _verifyAdminPassword(() {
                                  _showAddPlayerDialog(teamNo, teamName, 0);
                                }),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('선수 추가'),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: players.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, pIndex) {
                            final player = players[pIndex];
                            final rmId = player['rmId'] ?? 0;
                            final memberNo = player['memberNo'] ?? 0;
                            final name = player['memberName'] ?? '선수';
                            final club = player['clubName'] ?? '';
                            final rank = player['rankTitle'] ?? '';
                            final hdcp = player['handicap'] ?? '';
                            final pMemo = player['memo'] ?? '';
                            final isGuest = memberNo == 0;

                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: isGuest ? Colors.amber.shade100 : primaryNavy.withOpacity(0.1),
                                child: Text(
                                  '${pIndex + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isGuest ? Colors.amber.shade900 : primaryNavy,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  if (isGuest) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '게스트',
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                                  ],
                                  if (club.isNotEmpty || rank.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '$club $rank',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: pMemo.toString().isNotEmpty
                                  ? Text(pMemo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hdcp.toString().isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Text(
                                        'HDCP $hdcp',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 18),
                                    tooltip: '선수 제외',
                                    onPressed: () => _verifyAdminPassword(() {
                                      _deletePlayer(rmId, name);
                                    }),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // 🏆 2. 성적 & 시상 결과 탭
  Widget _buildAwardsTab(bool isAwardPublished) {
    final awardMemo = _roundingInfo?['awardMemo'] ?? '';

    // 모든 팀의 선수들을 하나의 리스트로 모아 시상 및 성적 정리
    List<dynamic> allPlayers = [];
    for (var team in _teams) {
      final pList = team['players'] as List<dynamic>?;
      if (pList != null) {
        allPlayers.addAll(pList);
      }
    }

    // 시상 내역이 존재하는 선수 목록
    final awardees = allPlayers.where((p) {
      final awardName = (p['awardName'] ?? '').toString().trim();
      return awardName.isNotEmpty;
    }).toList();

    // 타수/순위가 등록된 선수 목록 (순위 기준 정렬)
    final rankedPlayers = allPlayers.where((p) {
      return p['grossScore'] != null || p['netScore'] != null || p['ranking'] != null;
    }).toList();

    rankedPlayers.sort((a, b) {
      int rankA = a['ranking'] ?? 999;
      int rankB = b['ranking'] ?? 999;
      return rankA.compareTo(rankB);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 관리자 작업 헤더
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _verifyAdminPassword(_showPublishAwardDialog),
                  icon: const Icon(Icons.campaign, size: 16),
                  label: Text(
                    isAwardPublished ? '공개 설정 (공개중)' : '공개 설정 (비공개)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAwardPublished ? primaryNavy : Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _verifyAdminPassword(_showBatchScoreSelectDialog),
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: const Text('성적/시상 입력', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGold,
                    foregroundColor: primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!isAwardPublished)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '현재 시상 및 성적이 비공개 상태입니다. 상단 [공개 설정] 버튼을 통해 공개로 전환할 수 있습니다.',
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // 시상 총평/메모 카드
          if (awardMemo.toString().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryGold.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: primaryNavy, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      awardMemo,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryNavy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 🏆 주요 시상자 명단
          const Row(
            children: [
              Icon(Icons.emoji_events, color: primaryGold, size: 22),
              SizedBox(width: 6),
              Text(
                '주요 시상 내역',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (awardees.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('등록된 시상 내역이 없습니다.')),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: awardees.length,
              itemBuilder: (context, index) {
                final player = awardees[index];
                final awardName = player['awardName'] ?? '시상';
                final prize = player['awardPrize'] ?? '';
                final name = player['memberName'] ?? '선수';
                final club = player['clubName'] ?? '';
                final gross = player['grossScore'];
                final net = player['netScore'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _verifyAdminPassword(() {
                      _showEditScoreAwardDialog(player);
                    }),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryGold.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.wine_bar, color: primaryNavy, size: 20),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryNavy,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              awardName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (club.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($club)',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                      subtitle: prize.toString().isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '부상: $prize',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                              ),
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (gross != null || net != null)
                            Text(
                              net != null ? '$gross 타 (Net $net)' : '$gross 타',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 13),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // 📊 전체 성적표
          const Row(
            children: [
              Icon(Icons.format_list_numbered, color: primaryNavy, size: 22),
              SizedBox(width: 6),
              Text(
                '전체 성적표',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (rankedPlayers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('등록된 성적 데이터가 없습니다.')),
              ),
            )
          else
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rankedPlayers.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final player = rankedPlayers[index];
                    final rank = player['ranking'] != null ? '${player['ranking']}위' : '-';
                    final name = player['memberName'] ?? '';
                    final club = player['clubName'] ?? '';
                    final gross = player['grossScore'] != null ? '${player['grossScore']}타' : '-';
                    final net = player['netScore'] != null ? '${player['netScore']}' : '-';
                    final award = player['awardName'] ?? '';

                    return InkWell(
                      onTap: () => _verifyAdminPassword(() {
                        _showEditScoreAwardDialog(player);
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                rank,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: index < 3 ? primaryGold : Colors.black87,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (club.isNotEmpty)
                                    Text(
                                      club,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                            ),
                            if (award.toString().isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primaryGold.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  award,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryNavy),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  gross,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryNavy),
                                ),
                                if (net != '-')
                                  Text(
                                    'NET $net',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
