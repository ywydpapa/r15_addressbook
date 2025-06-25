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
  bool _isProfilePublic = false;
  bool _isNotificationOn = false;
  bool _isLoading = true;

  String? memberNo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // arguments는 build에서만 안전히 접근 가능 → didChangeDependencies에서 처리
    if (memberNo == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      memberNo = args?['memberNo'];
      if (memberNo != null) {
        _fetchMaskYN(memberNo!);
      }
    }
  }

  Future<void> _fetchMaskYN(String memberNo) async {
    setState(() {
      _isLoading = true;
    });
    final url = '${ApiConf.baseUrl}/phapp/getmask/$memberNo';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // maskYN이 'N'이면 공개(ON), 'Y'면 비공개(OFF)
        setState(() {
          _isProfilePublic = (data['maskYN'] == 'N');
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 정보를 불러오지 못했습니다.')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // memberNo는 이미 didChangeDependencies에서 저장됨
    return Scaffold(
      appBar: AppBar(
        title: Text('설정관리'),
        backgroundColor: Colors.yellow,
      ),
      backgroundColor: Colors.yellow,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text('개인정보 공개'),
              value: _isProfilePublic,
              onChanged: (value) async {
                setState(() {
                  _isProfilePublic = value;
                });
                if (memberNo != null) {
                  final maskYN = value ? 'N' : 'Y'; // 공개: N, 비공개: Y
                  final url = '${ApiConf.baseUrl}/phapp/maskYN/$memberNo/$maskYN';
                  try {
                    final response = await http.post(Uri.parse(url));
                    if (response.statusCode == 200) {
                      // 성공 처리
                    } else {
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
              },
            ),
            SwitchListTile(
              title: Text('알림 받음'),
              value: _isNotificationOn,
              onChanged: (value) {
                setState(() {
                  _isNotificationOn = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
