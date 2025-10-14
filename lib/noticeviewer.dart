import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'config/api_config.dart';

class NoticeViewerScreen extends StatefulWidget {
  const NoticeViewerScreen({super.key});

  @override
  State<NoticeViewerScreen> createState() => _NoticeViewerScreenState();
}

class _NoticeViewerScreenState extends State<NoticeViewerScreen> {
  String htmlData = "";
  String htmlTitle = "";
  String answerType = ""; // 'ATTYN', 'AGREE' 또는 ''

  int noticeNo = 0;
  int memberNo = 0;
  String noticeType = "";

  bool isLoading = true;
  bool _argsLoaded = false;

  final double _minScale = 0.8; // 필요에 따라 1.0으로 시작해도 됩니다.
  final double _maxScale = 3.0;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      _parseArgsAndFetch();
      _argsLoaded = true;
    }
  }

  void _parseArgsAndFetch() {
    final args = ModalRoute.of(context)?.settings.arguments;
    dynamic argNoticeNo;
    String? argNoticeType;
    int? argMemberNo;
    String? argMfuncNo;

    if (args is Map<String, dynamic>) {
      argNoticeNo = args['noticeNo'];
      argNoticeType = args['noticeType']?.toString();
      argMemberNo = args['memberNo'];
      argMfuncNo = args['mfuncNo']?.toString();
    } else {
      argNoticeNo = args;
    }

    noticeNo = argNoticeNo is int ? argNoticeNo : int.tryParse(argNoticeNo.toString()) ?? 0;
    noticeType = argNoticeType ?? "";
    memberNo = argMemberNo is int ? argMemberNo : int.tryParse(argMemberNo.toString()) ?? 0;

    final isClub = (argMfuncNo == '1');
    _fetchHtmlData(isClub: isClub);
  }

  Future<void> _fetchHtmlData({required bool isClub}) async {
    final url = isClub
        ? "${ApiConf.baseUrl}/phapp/clubnoticeViewer/$noticeNo"
        : "${ApiConf.baseUrl}/phapp/noticeViewer/$noticeNo";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        throw Exception("HTTP ${res.statusCode}");
      }
      final jsonMap = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final docs = jsonMap['docs'] as List<dynamic>?;

      if (!mounted) return;

      if (docs != null && docs.isNotEmpty) {
        final first = docs.first as Map<String, dynamic>;
        setState(() {
          noticeNo = first['noticeNo'] ?? noticeNo;
          htmlTitle = first['noticeTitle'] ?? '제목 없음';
          htmlData = first['noticeCont'] ?? '<p>내용 없음</p>';
          answerType = first['answerType'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() {
          htmlTitle = "데이터 없음";
          htmlData = "<p>표시할 데이터가 없습니다.</p>";
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        htmlTitle = "Error";
        htmlData = "<p>Error: ${e.toString()}</p>";
        isLoading = false;
      });
    }
  }

  Future<void> _postNoticeAttend({required String attend}) async {
    final url =
        '${ApiConf.baseUrl}/phapp/noticeAttend/$memberNo/$noticeNo/$noticeType/$attend';
    final response = await http.post(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('전송 실패(${response.statusCode})');
    }
  }

  Future<void> _handleAttendSubmit(String attend, String label) async {
    try {
      await _postNoticeAttend(attend: attend);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label 처리 완료')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('오류: $e')));
    }
  }

  /// 상단 버튼: 각 35%, 좌/중앙/우 간격 10%씩
  Widget _buildTopButtons() {
    if (answerType != 'ATTYN' && answerType != 'AGREE') {
      return const SizedBox.shrink();
    }
    final isAttend = answerType == 'ATTYN';
    final pos = isAttend ? '참석' : '동의';
    final neg = isAttend ? '불참' : '부동의';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double w = constraints.maxWidth;

          // 너무 작은 폭에서 비율 강제 시 overflow 위험 → fallback
          if (w < 360) {
            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAttendSubmit('Y', pos),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(pos),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleAttendSubmit('N', neg),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(neg),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // 퍼센트 계산
          final double sideGap = w * 0.10;
          final double middleGap = w * 0.10;
          final double btnWidth = w * 0.35;
          final double btnHeight = 48;

          return SizedBox(
            width: w,
            child: Row(
              children: [
                SizedBox(width: sideGap),
                SizedBox(
                  width: btnWidth,
                  height: btnHeight,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleAttendSubmit('Y', pos),
                    icon: const Icon(Icons.check, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        pos,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                SizedBox(width: middleGap),
                SizedBox(
                  width: btnWidth,
                  height: btnHeight,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleAttendSubmit('N', neg),
                    icon: const Icon(Icons.close, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        neg,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                SizedBox(width: sideGap),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHtmlContent() {
    return Html(
      data: htmlData,
      style: {
        "table": Style(
          backgroundColor: const Color.fromARGB(0x20, 0xee, 0xee, 0xee),
        ),
        "th": Style(
          padding: HtmlPaddings.all(6),
          backgroundColor: Colors.grey.shade400,
          fontWeight: FontWeight.bold,
        ),
        "td": Style(
          padding: HtmlPaddings.all(6),
          border: const Border(
            bottom: BorderSide(color: Colors.grey),
          ),
        ),
      },
      onLinkTap: (url, _, __) {
        debugPrint("open: $url");
      },
    );
  }

  // 2) 핀치 줌 전용 HTML 빌더
  Widget _buildHtmlContentZoomOnly() {
    return InteractiveViewer(
      minScale: _minScale,
      maxScale: _maxScale,
      panEnabled: false,   // 팬(드래그 이동) 비활성화
      scaleEnabled: true,  // 핀치 줌만 허용
      child: _buildHtmlContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          htmlTitle,
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.yellow,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // 상단 버튼 영역 유지(필요 없다면 제거 가능)
                if (answerType == 'ATTYN' || answerType == 'AGREE')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: _buildTopButtons(),
                  ),
                // 아래 남은 전체 영역을 뷰어로 사용
                Expanded(
                  child: Container(
                    color: Colors.white, // 필요시 배경색
                    child: InteractiveViewer(
                      minScale: 1.0,      // 확대만 원하면 1.0으로 설정 권장
                      maxScale: 3.0,
                      panEnabled: true,   // 확대 후 드래그 이동
                      scaleEnabled: true, // 핀치 줌
                      clipBehavior: Clip.none,
                      boundaryMargin: const EdgeInsets.all(48),
                      child: Align(
                        // 확대 기준 자연스럽게(좌상단/중앙 등 필요에 따라 조정)
                        alignment: Alignment.topLeft,
                        // 콘텐츠가 제약을 명확히 알도록 너비를 화면에 맞춤
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                            maxWidth: constraints.maxWidth,
                          ),
                          child: _buildHtmlContent(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
