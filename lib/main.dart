import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clubList.dart';
import 'searchresult.dart';
import 'rankMember.dart';
import 'clubDocs.dart';
import 'docViewer.dart';
import 'config/api_config.dart';
import 'dart:io';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides(); //테스트용 우회 설정
  runApp(MyApp());
}

// 테스트용 우회설정 클래스
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lions Club AddressBook for 355-A R15',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login', // 초기 화면을 로그인 화면으로 설정
      routes: {
        '/login': (context) => LoginScreen(),
        '/': (context) => HomeScreen(),
        '/clubList': (context) => ClubListScreen(),
        '/search': (context) => MemberSearchScreen(),
        '/rankMembers': (context) => RankMemberScreen(),
        '/clubDocs': (context) => ClubDocsScreen(),
        '/docViewer': (context) => DocViewerScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String _errorMessage = '';
  String _clubNo = '';

  Future<void> _login() async {
    final phoneno = _usernameController.text;

    if (phoneno.isEmpty) {
      setState(() {
        _errorMessage = '전화번호를 입력하세요.';
      });
      return;
    }

    try {
      // 서버 요청
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/mlogin/$phoneno'),
      );

      // 상태 코드 확인
      if (response.statusCode == 200) {
        // JSON 파싱
        final data = json.decode(response.body);

        // 반환된 데이터 처리
        if (data.containsKey('clubno')) {
          setState(() {
            _clubNo = data['clubno'].toString();
            _errorMessage = '';
          });

          // 메인 화면으로 이동
          Navigator.pushReplacementNamed(context, '/', arguments: _clubNo);
        } else if (data.containsKey('error')) {
          setState(() {
            _errorMessage = data['error'];
          });
        } else {
          setState(() {
            _errorMessage = '자신의 전화번호로 로그인해 주세요. 숫자로만 입력해 주세요.';
          });
        }
      } else {
        setState(() {
          _errorMessage = '서버 오류 (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '네트워크 오류: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('국제라이온스협회 355-A지구 15지역'),
      ),
      backgroundColor: Colors.yellow,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/loginlogo.png',
              width: 300, // 로고 너비 설정
              height: 300, // 로고 높이 설정
            ),
            SizedBox(height: 8), // 로고와 입력창 사이 간격
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '전화번호',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 8),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: TextStyle(color: Colors.red)),
            SizedBox(height: 8),
            ElevatedButton(onPressed: _login, child: Text('로그인')),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? mclubNo =
    ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text('15지역 회원 주소록'),
      ),
      backgroundColor: Colors.yellow,
      body: Column(
        children: [
          // 상단 이미지 배치 (액자 스타일)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), // 좌우 간격 추가
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, // 배경색 (액자 배경)
                border: Border.all(color: Colors.black, width: 2), // 테두리 설정
                borderRadius: BorderRadius.circular(8), // 테두리에 둥글기 추가
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withAlpha((0.5 * 255).toInt()),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3), // 그림자 위치
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0), // 이미지와 테두리 사이 패딩
                child: Image.asset(
                  'assets/homeImage.png', // 이미지 파일 이름
                  width: double.infinity,
                  height: 400, // 이미지 높이 설정
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Spacer(),
          // 버튼 배치
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/clubList', arguments: mclubNo);
                        },
                        child: Text('클럽별 회원 목록'),
                      ),
                    ),
                    SizedBox(width: 8), // 버튼 사이 간격
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/rankMembers', arguments: mclubNo);
                        },
                        child: Text('직책별 회원 목록'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16), // 버튼 사이 간격
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/search', arguments: mclubNo);
                        },
                        child: Text('키워드 회원 검색'),
                      ),
                    ),
                    SizedBox(width: 8), // 버튼 사이 간격
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (mclubNo != null) {
                            Navigator.pushNamed(context, '/clubDocs', arguments: mclubNo);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                            );
                            Future.delayed(Duration(seconds: 2), () {
                              Navigator.pushReplacementNamed(context, '/login');
                            });
                          }
                        },
                        child: Text('클럽 문서 목록'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Spacer(),
        ],
      ),
    );
  }
}
