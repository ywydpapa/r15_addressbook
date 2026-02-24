import 'package:flutter/material.dart';
import 'membertabsimple.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
      rankTitle: json['rankTitlekor'] ?? '',
      clubName: json['clubName'] ?? '',
    );
  }
}

class CircleMemberListScreen extends StatefulWidget {

  final int circleNo;
  final String circleName;
  const CircleMemberListScreen({
    super.key,
    required this.circleNo,
    required this.circleName,
  });

  @override
  _CircleMemberListScreenState createState() => _CircleMemberListScreenState();
}

class _CircleMemberListScreenState extends State<CircleMemberListScreen> {
  late int circleNo;
  late String circleName;
  late Future<List<Member>> _memberList;
  List<Member> _allMembers = [];
  List<Member> _filteredMembers = [];
  final TextEditingController _searchController = TextEditingController();
  String _kBlue(int memberNo) => 'circle_${circleNo}_member_${memberNo}_green';
  String _kRed(int memberNo)  => 'circle_${circleNo}_member_${memberNo}_red';
  // 체크 상태 저장 (memberNo 기준)
  final Map<int, bool> _blueChecked = {};
  final Map<int, bool> _redChecked = {};

// 3초 홀드 감지용 타이머
  Timer? _holdTimer;
  bool _resetDialogOpen = false;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      circleNo = widget.circleNo;
      circleName = widget.circleName;
      _memberList = fetchCircleMemberList(circleNo);
      _searchController.addListener(_filterMembers);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Member>> fetchCircleMemberList(int circleNo) async {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/getcirclemembers/$circleNo'),
    );
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> members = data['cmembers'];
      List<Member> memberList =
      members.map((json) => Member.fromJson(json)).toList();

      setState(() {
        _allMembers = memberList;
        _filteredMembers = memberList;
        for (final m in memberList) {
          _blueChecked.putIfAbsent(m.memberNo, () => false);
          _redChecked.putIfAbsent(m.memberNo, () => false);
        }
      });
      await _loadChecksFromPrefs(memberList);
      return memberList;
    } else {
      throw Exception('Failed to load member list');
    }
  }

  Future<void> _loadChecksFromPrefs(List<Member> members) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final m in members) {
        _blueChecked[m.memberNo] = prefs.getBool(_kBlue(m.memberNo)) ?? false;
        _redChecked[m.memberNo]  = prefs.getBool(_kRed(m.memberNo)) ?? false;
      }
    });
  }

  Future<void> _saveOneCheck(int memberNo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBlue(memberNo), _blueChecked[memberNo] ?? false);
    await prefs.setBool(_kRed(memberNo), _redChecked[memberNo] ?? false);
  }

  Future<void> _resetAllChecksAndSave() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (final key in _blueChecked.keys) {
        _blueChecked[key] = false;
        _redChecked[key] = false;
      }
    });

    // 저장도 같이 반영
    for (final memberNo in _blueChecked.keys) {
      await prefs.setBool(_kBlue(memberNo), false);
      await prefs.setBool(_kRed(memberNo), false);
    }
  }


  Future<void> _confirmAndResetAllChecks() async {
    if (_resetDialogOpen) return; // 중복 방지
    _resetDialogOpen = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('체크 해제'),
        content: const Text('전체 체크를 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    _resetDialogOpen = false;

    if (ok == true) {
      await _resetAllChecksAndSave();
    }
  }

  void _startHoldToResetTimer() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 3), () async {
      await _confirmAndResetAllChecks();
    });
  }

  void _cancelHoldToResetTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _filterMembers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMembers = _allMembers.where((member) {
        return member.memberName.toLowerCase().contains(query) ||
            member.memberPhone.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('$circleName 회원 목록'),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: Column(
          children: [
            // 검색 입력 필드
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '검색',
                  hintText: '이름 또는 전화번호로 검색',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
            // 멤버 리스트
            Expanded(
              child: FutureBuilder<List<Member>>(
                future: _memberList,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No members found'));
                  } else {
                    return InteractiveViewer(
                      panEnabled: true, // 화면 이동 허용
                      scaleEnabled: true, // 확대/축소 허용
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 초록 체크
                                  GestureDetector(
                                    onTapDown: (_) => _startHoldToResetTimer(),
                                    onTapUp: (_) => _cancelHoldToResetTimer(),
                                    onTapCancel: () => _cancelHoldToResetTimer(),
                                    child: Checkbox(
                                      value: _blueChecked[member.memberNo] ?? false, // (이름은 blue지만 초록 체크로 사용)
                                      onChanged: (v) async {
                                        setState(() => _blueChecked[member.memberNo] = v ?? false);
                                        await _saveOneCheck(member.memberNo);
                                      },
                                      activeColor: Colors.transparent, // 체크 시 배경색(채움) 방지용
                                      fillColor: WidgetStateProperty.all(Colors.transparent), // 항상 투명
                                      checkColor: Colors.green, // ✔ 색
                                      side: BorderSide(color: Colors.black.withOpacity(0.15), width: 1), // 박스 테두리 옅게
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 클릭 영역 과도하게 커지는 것 방지
                                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3), // 크기 조금 줄임(원치 않으면 제거)
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  // 빨간 체크
                                  GestureDetector(
                                    onTapDown: (_) => _startHoldToResetTimer(),
                                    onTapUp: (_) => _cancelHoldToResetTimer(),
                                    onTapCancel: () => _cancelHoldToResetTimer(),
                                    child: Checkbox(
                                      value: _redChecked[member.memberNo] ?? false,
                                      onChanged: (v) async {
                                        setState(() => _redChecked[member.memberNo] = v ?? false);
                                        await _saveOneCheck(member.memberNo);
                                      },
                                      activeColor: Colors.transparent,
                                      fillColor: WidgetStateProperty.all(Colors.transparent),
                                      checkColor: Colors.red, // ✔ 색
                                      side: BorderSide(color: Colors.black.withOpacity(0.15), width: 1),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MemberSimpleDetailScreen(
                                      memberNo: member.memberNo,
                                      memberName: member.memberName,
                                      mclubNo: '42',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}
