import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});
  @override
  State<SettingScreen> createState() => _SettingScreenState();
}
class _SettingScreenState extends State<SettingScreen> {
  int _securityLevel = 0; // 0: 전체공개, 1: 1단계 비공개, 2: 2단계 비공개, 3: 전체 비공개
  int _operationMode = 0; // 0: 지역수첩, 1: 클럽수첩
  bool _isLoading = true;

  String? memberNo;

  final List<String> _securityCodes = ['N', 'S', 'T', 'Y'];
  final List<String> _securityLabels = ['전체공개', '1단계 비공개', '2단계 비공개', '전체비공개'];
  final List<String> _securityDescriptions = [
    '전체공개: 지역회원들이 내정보를 모두 볼 수 있습니다.',
    '1단계 비공개: 지역회원들에게 내정보중 주소와 생년월일을 비공개합니다.',
    '2단계 비공개: 지역회원들에게 내정보중 이름,소속, 직책, 전화번호, 추가 기재 사항만을 공개합니다.',
    '전체비공개: 지역회원들에게 내정보중 이름, 소속, 직책을 제외한 모든 정보를 비공개 합니다.',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (memberNo == null) {
        memberNo = args['memberNo'];
        if (memberNo != null) {
          _fetchSecurityLevel(memberNo!);
        }
      }
      // 여기 추가
      if (args.containsKey('mfuncNo')) {
        final argFuncNo = args['mfuncNo'];
        if (argFuncNo != null) {
          setState(() {
            _operationMode = int.tryParse(argFuncNo.toString()) ?? 0;
          });
        }
      }
    }
  }

  Future<void> _fetchSecurityLevel(String memberNo) async {
    setState(() => _isLoading = true);
    final url = '${ApiConf.baseUrl}/phapp/getmask/$memberNo';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String code = data['maskYN'] ?? 'N';
        int idx = _securityCodes.indexOf(code);
        setState(() {
          _securityLevel = idx == -1 ? 0 : idx;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 정보를 불러오지 못했습니다.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    }
  }

  Future<void> _updateSecurityLevel(int level) async {
    if (memberNo == null) return;
    String code = _securityCodes[level];
    final url = '${ApiConf.baseUrl}/phapp/maskYN/$memberNo/$code';
    try {
      final response = await http.post(Uri.parse(url));
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 변경 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    }
  }

  Future<void> _updateOperationMode(int mode) async {
    if (memberNo == null) return;
    final url = '${ApiConf.baseUrl}/phapp/funcNo/$memberNo/$mode';
    try {
      final response = await http.post(Uri.parse(url));
      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('운영설정 변경 실패: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정관리'),
        backgroundColor: Colors.yellow,
      ),
      backgroundColor: Colors.yellow,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            // 개인정보 공개 수준
            Text(
              '개인정보 공개 수준설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _securityLevel.toDouble(),
              min: 0,
              max: 3,
              divisions: 3,
              label: _securityLabels[_securityLevel],
              onChanged: (double value) async {
                setState(() => _securityLevel = value.round());
                await _updateSecurityLevel(_securityLevel);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_securityLabels.length, (index) {
                return Text(
                  _securityLabels[index],
                  style: TextStyle(
                    fontSize: 12,
                    color: _securityLevel == index ? Colors.red : Colors.black,
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                _securityDescriptions[_securityLevel],
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 20),

            // 운영설정
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '운영설정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double buttonWidth = (constraints.maxWidth / 2) - 4;
                        return ToggleButtons(
                          isSelected: [
                            _operationMode == 0,
                            _operationMode == 1,
                          ],
                          onPressed: (int index) async {
                            await _updateOperationMode(index);
                            setState(() => _operationMode = index);
                          },
                          borderRadius: BorderRadius.circular(8),
                          selectedColor: Colors.white,
                          fillColor: Colors.orange,
                          color: Colors.black,
                          constraints: BoxConstraints(
                            minHeight: 48,
                            minWidth: buttonWidth,
                          ),
                          children: [
                            Text('지역수첩', style: TextStyle(fontSize: 16)),
                            Text('클럽수첩', style: TextStyle(fontSize: 16)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 알림 설정
          ],
        ),
      ),
    );
  }
}
