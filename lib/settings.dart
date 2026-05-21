import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

const String kAutoLoginEnabled = 'autoLoginEnabled';
const String kAutoLoginPhone = 'autoLoginPhone';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});
  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  int _securityLevel = 0; // 0: 전체공개, 1: 1단계 비공개, 2: 2단계 비공개, 3: 전체 비공개
  int _operationMode = 0; // 0: 지역수첩, 1: 클럽수첩, 2: 모입수첩
  bool _isLoading = true;

  String? memberNo;
  String? mfuncNo; // 💡 권한 확인용 변수 추가

  final List<String> _securityCodes = ['N', 'S', 'T', 'Y'];
  final List<String> _securityLabels = ['전체공개', '1단계 비공개', '2단계 비공개', '전체비공개'];
  final List<String> _securityDescriptions = [
    '전체공개: 지역회원들이 내정보를 모두 볼 수 있습니다.',
    '1단계 비공개: 지역회원들에게 내정보중 주소와 생년월일을 비공개합니다.',
    '2단계 비공개: 지역회원들에게 내정보중 이름,소속, 직책, 전화번호, 추가 기재 사항만을 공개합니다.',
    '전체비공개: 지역회원들에게 내정보중 이름, 소속, 직책을 제외한 모든 정보를 비공개 합니다.',
  ];
  bool _autoLoginEnabled = false;
  final TextEditingController _autoLoginPhoneController = TextEditingController();

  @override
  void dispose() {
    _autoLoginPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAutoLoginPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoLoginEnabled = prefs.getBool(kAutoLoginEnabled) ?? false;
      _autoLoginPhoneController.text = prefs.getString(kAutoLoginPhone) ?? '';
    });
  }

  Future<void> _setAutoLoginEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    if (!enabled) {
      await prefs.setBool(kAutoLoginEnabled, false);
      await prefs.remove(kAutoLoginPhone);
      setState(() {
        _autoLoginEnabled = false;
        _autoLoginPhoneController.text = '';
      });
      return;
    }

    final phone = _autoLoginPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자동로그인을 켜려면 전화번호를 입력하세요.')),
      );
      return;
    }

    await prefs.setBool(kAutoLoginEnabled, true);
    await prefs.setString(kAutoLoginPhone, phone);
    setState(() => _autoLoginEnabled = true);
  }

  Future<void> _saveAutoLoginPhone() async {
    final phone = _autoLoginPhoneController.text.trim();
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(kAutoLoginPhone, phone);

    if (_autoLoginEnabled) {
      if (phone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전화번호가 비어있으면 자동로그인을 사용할 수 없습니다.')),
        );
        await prefs.setBool(kAutoLoginEnabled, false);
        setState(() => _autoLoginEnabled = false);
      } else {
        await prefs.setBool(kAutoLoginEnabled, true);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      if (mfuncNo == null && args.containsKey('mfuncNo')) {
        mfuncNo = args['mfuncNo'].toString();
        setState(() {
          _operationMode = int.tryParse(mfuncNo!) ?? 0;
        });
      }

      if (memberNo == null) {
        memberNo = args['memberNo'];
        _loadAutoLoginPrefs();

        if (memberNo != null) {
          // 💡 게스트(4)일 경우 서버에 설정 정보를 요청하지 않고 로딩 종료
          if (mfuncNo == '4') {
            setState(() => _isLoading = false);
          } else {
            _fetchSecurityLevel(memberNo!);
          }
        } else {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _fetchSecurityLevel(String memberNo) async {
    setState(() => _isLoading = true);
    final url = '${ApiConf.baseUrl}/phapp/getmask/$memberNo';
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

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
          SnackBar(content: Text('설정 정보 로드 실패!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}')),
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 변경 실패!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}')),
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token') ?? '';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('운영설정 변경 실패!\n상태 코드: ${response.statusCode}\n응답 내용: ${response.body}')),
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
            // 💡 게스트(4)가 아닐 때만 개인정보 공개 수준 및 운영설정 표시
            if (mfuncNo != '4') ...[
              // 개인정보 공개 수준
              const Text(
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
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 20),

              // 운영설정
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '운영설정',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          double buttonWidth = (constraints.maxWidth / 3) - 4;

                          return ToggleButtons(
                            isSelected: [
                              _operationMode == 0,
                              _operationMode == 1,
                              _operationMode == 2,
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
                            children: const [
                              Text('지역수첩', style: TextStyle(fontSize: 16)),
                              Text('클럽수첩', style: TextStyle(fontSize: 16)),
                              Text('모임수첩', style: TextStyle(fontSize: 16)),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],

            // 💡 자동로그인 설정 (게스트 포함 모두에게 표시)
            const Text(
              '자동로그인',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('자동로그인 사용'),
              value: _autoLoginEnabled,
              onChanged: (v) async {
                await _setAutoLoginEnabled(v);
              },
            ),

            TextField(
              controller: _autoLoginPhoneController,
              decoration: const InputDecoration(
                labelText: '자동로그인 전화번호',
                hintText: '숫자만 입력',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) async => _saveAutoLoginPhone(),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: () async {
                  await _saveAutoLoginPhone();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('자동로그인 설정이 저장되었습니다.')),
                  );
                },
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
