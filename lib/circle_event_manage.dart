import 'dart:async'; // 💡 Timer 사용을 위해 필요합니다.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =========================================================
// 1. 써클별 행사 목록 화면
// =========================================================
class CircleEventManageScreen extends StatefulWidget {
  final int circleNo;
  final String circleName;
  final String memberNo;

  const CircleEventManageScreen({
    super.key,
    required this.circleNo,
    required this.circleName,
    required this.memberNo,
  });

  @override
  State<CircleEventManageScreen> createState() => _CircleEventManageScreenState();
}

class _CircleEventManageScreenState extends State<CircleEventManageScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  // 5초 타이머를 저장할 변수
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _fetchEvents(showFullLoading: true); // 처음 진입할 때만 전체 화면 로딩 표시
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  // 💡 [성능 최적화] 상세 화면에서 '실제 변경사항(true)'을 가지고 돌아왔을 때만 새로고침을 수행합니다.
  Future<void> _navigateAndRefresh(BuildContext context, Widget targetScreen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen),
    );

    // 참석 정보 변경 등 데이터 수정이 발생하여 true를 반환받았을 때만 백그라운드 새로고침 실행
    if (result == true && mounted) {
      _fetchEvents(showFullLoading: false); // 화면 깜빡임 없이 조용히 데이터만 갱신
    }
  }

  // 💡 [성능 최적화] showFullLoading 매개변수를 추가하여 불필요한 전체화면 로딩창을 방지합니다.
  Future<void> _fetchEvents({bool showFullLoading = false}) async {
    if (showFullLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/getcircleevents/${widget.circleNo}?memberNo=${widget.memberNo}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5)); // 💡 네트워크 지연 시 무한 대기를 방지하기 위한 타임아웃(5초) 설정

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);

        if (mounted) {
          setState(() {
            if (data is Map && data.containsKey('events')) {
              _events = data['events'] ?? [];
            } else if (data is List) {
              _events = data;
            } else {
              _events = [];
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('써클 행사 목록 조회 실패: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 백엔드에 써클 행사 삭제(소프트 딜리트)를 요청하는 함수
  Future<void> _deleteEvent(int eventNo) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.post(
        Uri.parse('${ApiConf.baseUrl}/phapp/circle/event/delete/$eventNo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('행사가 성공적으로 삭제되었습니다.')),
        );
        _fetchEvents(showFullLoading: true); // 삭제 성공 후에는 전체 새로고침
      } else {
        final decoded = utf8.decode(response.bodyBytes);
        final errData = jsonDecode(decoded);
        String errMsg = errData['detail'] ?? '삭제에 실패했습니다.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg)),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  // 길게 눌렀을 때 띄워줄 삭제 확인 팝업창
  void _showDeleteConfirmDialog(int eventNo, String eventTitle) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('행사 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '[$eventTitle]\n이 행사를 정말로 삭제하시겠습니까?\n삭제된 행사는 목록에서 제외됩니다.',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 취소
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // 팝업 닫기
                _deleteEvent(eventNo);  // 삭제 실행
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventTypeBadge(String? eventType) {
    if (eventType == null || eventType.trim().isEmpty) return const SizedBox.shrink();

    final code = eventType.trim().toUpperCase();
    String label = code;
    Color bgColor = Colors.grey.shade200;
    Color textColor = Colors.grey.shade800;

    switch (code) {
      case 'MONEV':
        label = '정기월례회';
        bgColor = const Color(0xFFE8F0FE);
        textColor = const Color(0xFF1A73E8);
        break;
      case 'SUDEV':
        label = '기타행사';
        bgColor = const Color(0xFFE6F4EA);
        textColor = const Color(0xFF137333);
        break;
      case 'EYEAR':
        label = '송년회';
        bgColor = const Color(0xFFFCE8E6);
        textColor = const Color(0xFFC5221F);
        break;
      default:
        label = code;
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAddEventDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCircleEventBottomSheet(
        circleNo: widget.circleNo,
        onSuccess: () {
          _fetchEvents(showFullLoading: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF003366);
    const Color primaryGold = Color(0xFFFFC107);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.circleName} 행사 목록'),
        backgroundColor: Colors.white,
        foregroundColor: primaryNavy,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryNavy))
          : _events.isEmpty
          ? const Center(child: Text('등록된 행사가 없습니다.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) {
          final event = _events[index];

          final int eventNo = event['eventNo'] ?? 0;
          final String eventTitle = event['eventTitle'] ?? '제목 없음';
          final String eventDateFrom = event['eventDatefrom'] ?? '';
          final String eventDateTo = event['eventDateto'] ?? '';
          final String eventTimeFrom = event['eventTimefrom'] ?? '';
          final String eventPlace = event['eventPlace'] ?? '';
          final String eventMemo = event['eventMemo'] ?? '';
          final String? eventType = event['eventType'];
          final bool isAnswered = event['isAnswered'] ?? false; // 💡 응답 완료 여부

          String timeDisplay = eventTimeFrom;
          if (timeDisplay.length >= 5) {
            timeDisplay = timeDisplay.substring(0, 5);
          }

          String dateDisplay = eventDateFrom;
          if (eventDateTo.isNotEmpty && eventDateFrom != eventDateTo) {
            dateDisplay += ' ~ $eventDateTo';
          }
          if (timeDisplay.isNotEmpty) {
            dateDisplay += ' ($timeDisplay)';
          }

          final Color cardBgColor = !isAnswered ? const Color(0xFFFFF5F5) : Colors.white;
          final BorderSide cardBorder = !isAnswered
              ? const BorderSide(color: Colors.redAccent, width: 1.5)
              : BorderSide.none;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: !isAnswered ? 3 : 1,
            color: cardBgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: cardBorder,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                // 1. 터치가 시작되면 타이머 작동 (5초 후 다이얼로그 호출)
                _longPressTimer = Timer(const Duration(seconds: 5), () {
                  Feedback.forLongPress(context);
                  _showDeleteConfirmDialog(eventNo, eventTitle);
                });
              },
              onTapUp: (_) {
                // 2. 5초가 되기 전에 손을 떼면 타이머 취소 및 일반 클릭(상세화면 이동) 처리
                if (_longPressTimer != null && _longPressTimer!.isActive) {
                  _longPressTimer!.cancel();
                  _navigateAndRefresh(
                    context,
                    CircleEventAttendeeScreen(
                      eventNo: eventNo,
                      eventTitle: eventTitle,
                      memberNo: widget.memberNo,
                    ),
                  );
                }
              },
              onTapCancel: () {
                // 3. 드래그 등으로 터치가 취소되면 타이머 취소
                _longPressTimer?.cancel();
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Icon(
                              Icons.event,
                              color: !isAnswered ? Colors.redAccent : primaryNavy,
                              size: 28
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildEventTypeBadge(eventType),
                                  const SizedBox(width: 8),
                                  if (!isAnswered)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.notification_important, size: 10, color: Colors.white),
                                          SizedBox(width: 2),
                                          Text(
                                            '미응답 신규',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                eventTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  color: !isAnswered ? Colors.red.shade900 : primaryNavy,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      dateDisplay,
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              if (eventPlace.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        eventPlace,
                                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (eventMemo.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    eventMemo,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventDialog,
        backgroundColor: primaryNavy,
        foregroundColor: primaryGold,
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}

// =========================================================
// 2. 써클 행사 추가 BottomSheet 입력 폼 위젯
// =========================================================
class AddCircleEventBottomSheet extends StatefulWidget {
  final int circleNo;
  final VoidCallback onSuccess;

  const AddCircleEventBottomSheet({
    super.key,
    required this.circleNo,
    required this.onSuccess,
  });

  @override
  State<AddCircleEventBottomSheet> createState() => _AddCircleEventBottomSheetState();
}

class _AddCircleEventBottomSheetState extends State<AddCircleEventBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String _eventType = 'MONEV';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);

  bool _isSubmitting = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00";
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final bodyData = {
        'circleNo': widget.circleNo,
        'eventTitle': _titleController.text.trim(),
        'eventType': _eventType,
        'eventDatefrom': _formatDate(_startDate),
        'eventDateto': _formatDate(_endDate),
        'eventTimefrom': _formatTime(_startTime),
        'eventTimeto': _formatTime(_endTime),
        'eventPlace': _placeController.text.trim(),
        'eventMemo': _memoController.text.trim(),
      };

      final response = await http.post(
        Uri.parse('${ApiConf.baseUrl}/phapp/insertcircleEvent'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('써클 행사가 성공적으로 추가되었습니다.')),
        );
        widget.onSuccess();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패 (오류 코드: ${response.statusCode})')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류 발생: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryNavy = Color(0xFF003366);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                '새 써클 행사 등록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryNavy),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '행사명 *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '행사명을 입력해 주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: InputDecoration(
                  labelText: '행사 종류',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'MONEV', child: Text('정기월례회 (MONEV)')),
                  DropdownMenuItem(value: 'SUDEV', child: Text('비정기기타행사 (SUDEV)')),
                  DropdownMenuItem(value: 'EYEAR', child: Text('송년회 (EYEAR)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _eventType = val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('시작일: ${_formatDate(_startDate)}'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(context, true),
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text('시간: ${_formatTime(_startTime).substring(0, 5)}'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, false),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('종료일: ${_formatDate(_endDate)}'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectTime(context, false),
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text('시간: ${_formatTime(_endTime).substring(0, 5)}'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _placeController,
                decoration: InputDecoration(
                  labelText: '행사 장소',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _memoController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '행사 메모',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('등록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// 3. 써클 행사별 참석자 명단 및 상세 응답 관리 화면
// =========================================================
class CircleEventAttendeeScreen extends StatefulWidget {
  final int eventNo;
  final String eventTitle;
  final String memberNo;

  const CircleEventAttendeeScreen({
    super.key,
    required this.eventNo,
    required this.eventTitle,
    required this.memberNo,
  });

  @override
  State<CircleEventAttendeeScreen> createState() => _CircleEventAttendeeScreenState();
}

class _CircleEventAttendeeScreenState extends State<CircleEventAttendeeScreen> {
  List<dynamic> _attendees = [];
  bool _isLoading = true;

  String _myStatus = 'NONE';
  int _myDelayTime = 0;
  String _myMemo = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _fetchMyAttendance();
    await _fetchAttendees();
    setState(() => _isLoading = false);
  }

  // 본인 참석 정보 조회
  Future<void> _fetchMyAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.get(
        Uri.parse(
          '${ApiConf.baseUrl}/phapp/circle/event/my-attend?eventNo=${widget.eventNo}&memberNo=${widget.memberNo}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);

        if (data['status'] == 'success') {
          setState(() {
            _myStatus = data['responseType'] ?? 'NONE';
            _myDelayTime = data['delayTime'] ?? 0;
            _myMemo = data['joinMemo'] ?? '';
          });
        }
      }
    } catch (e) {
      print('본인 써클 참석 정보 개별 조회 실패: $e');
    }
  }

  // 전체 참석자 명단 조회
  Future<void> _fetchAttendees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/circle/event/members/${widget.eventNo}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decoded);
        final list = data['attendees'] ?? [];

        setState(() {
          _attendees = list;
        });
      }
    } catch (e) {
      print('써클 참석자 명단 조회 실패: $e');
    }
  }

  // 참석 여부 저장
  Future<void> _saveAttendance({
    required String status,
    required int delayTime,
    required String memo,
  }) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.post(
        Uri.parse('${ApiConf.baseUrl}/phapp/circle/event/attend'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'eventNo': widget.eventNo,
          'memberNo': int.tryParse(widget.memberNo) ?? 0,
          'responseType': status,
          'delayTime': delayTime,
          'joinMemo': memo,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참석 정보가 성공적으로 저장되었습니다.')),
        );

        setState(() {
          _myStatus = status;
          _myDelayTime = delayTime;
          _myMemo = memo;
        });

        await _fetchAttendees();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('참석 정보 저장에 실패했습니다.')),
        );
      }
    } catch (e) {
      print('써클 참석 정보 저장 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMyAttendanceEditDialog() {
    final TextEditingController delayController =
    TextEditingController(text: _myDelayTime > 0 ? _myDelayTime.toString() : '');
    final TextEditingController memoController = TextEditingController(text: _myMemo);
    String tempStatus = _myStatus == 'NONE' ? 'YES' : _myStatus;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('내 참석 정보 등록/수정', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('참석 여부 선택', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('참석 (YES)')),
                            selected: tempStatus == 'YES',
                            selectedColor: Colors.green.shade100,
                            onSelected: (selected) {
                              if (selected) setDialogState(() => tempStatus = 'YES');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('불참 (NO)')),
                            selected: tempStatus == 'NO',
                            selectedColor: Colors.red.shade100,
                            onSelected: (selected) {
                              if (selected) setDialogState(() => tempStatus = 'NO');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('지각 시간 (선택)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: delayController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '예: 20 (분 단위 입력)',
                        suffixText: '분 지각',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('참석 메모 (선택)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: memoController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: '예: 차량 지원 가능합니다, 조금 늦습니다.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final int delay = int.tryParse(delayController.text.trim()) ?? 0;
                    Navigator.pop(context);
                    _saveAttendance(
                      status: tempStatus,
                      delayTime: delay,
                      memo: memoController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('저장'),
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
    const Color primaryNavy = Color(0xFF003366);

    int attendCount = _attendees.where((a) {
      final s = a['status'] ?? a['responseType'];
      return s == 'YES';
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventTitle),
        backgroundColor: Colors.white,
        foregroundColor: primaryNavy,
        elevation: 1,
        // 💡 뒤로 가기 버튼을 누를 때 무조건 true를 반환하여 부모 목록 화면이 새로고침되도록 강제합니다.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true); // 👈 true를 가지고 이전 화면(목록)으로 돌아감
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryNavy))
          : Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '나의 참석 정보',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryNavy),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showMyAttendanceEditDialog,
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('정보 변경'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryNavy),
                        foregroundColor: primaryNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('참석여부: ', style: TextStyle(fontSize: 14)),
                    Text(
                      _myStatus == 'YES'
                          ? '참석'
                          : _myStatus == 'NO'
                          ? '불참'
                          : '미정',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _myStatus == 'YES'
                            ? Colors.green
                            : _myStatus == 'NO'
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                    if (_myDelayTime > 0) ...[
                      const SizedBox(width: 16),
                      const Text('지각시간: ', style: TextStyle(fontSize: 14)),
                      Text(
                        '$_myDelayTime분',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ]
                  ],
                ),
                if (_myMemo.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('메모: ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          _myMemo,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '응답자 명단 (총 ${_attendees.length}명)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '참석 확정: $attendCount명',
                  style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _attendees.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  '등록된 참석자가 없습니다.\n우측 상단 정보 변경을 통해 첫 참석을 등록해 보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
              ),
            )
                : ListView.builder(
              itemCount: _attendees.length,
              itemBuilder: (context, index) {
                final attendee = _attendees[index];
                final String name = attendee['memberName'] ?? '이름 없음';
                final String status = attendee['status'] ?? attendee['responseType'] ?? 'NONE';
                final int delay = attendee['delayTime'] ?? 0;
                final String memo = attendee['joinMemo'] ?? '';

                Color statusColor = Colors.grey;
                String statusText = '미정';
                IconData statusIcon = Icons.help_outline;

                if (status == 'YES') {
                  statusColor = Colors.green;
                  statusText = '참석';
                  statusIcon = Icons.check_circle_outline;
                } else if (status == 'NO') {
                  statusColor = Colors.red;
                  statusText = '불참';
                  statusIcon = Icons.cancel_outlined;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(statusIcon, color: statusColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      if (delay > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$delay분 지각',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (memo.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 52.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: Text(
                                memo,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
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