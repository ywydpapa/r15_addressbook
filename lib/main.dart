import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clubList.dart';
import 'searchresult.dart';
import 'rankMember.dart';
import 'clubDocs.dart';
import 'docViewer.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Navigation Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String _errorMessage = '';
  String _clubNo = ''; // 반환받은 clubno를 저장할 변수

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
      final response = await http.get(Uri.parse('http://192.168.11.2:8000/phapp/mlogin/$phoneno'));

      // 상태 코드 확인
      if (response.statusCode == 200) {
        // JSON 파싱
        final data = json.decode(response.body);

        // 반환된 데이터 처리
        if (data.containsKey('clubno')) {
          setState(() {
            _clubNo = data['clubno'].toString();
            _errorMessage = ''; // 에러 메시지 초기화
          });

          // 메인 화면으로 이동
          Navigator.pushReplacementNamed(context, '/', arguments: _clubNo);
        } else if (data.containsKey('error')) {
          setState(() {
            _errorMessage = data['error'];
          });
        } else {
          setState(() {
            _errorMessage = '알 수 없는 응답 형식입니다.';
          });
        }
      } else {
        setState(() {
          _errorMessage = '서버 오류 (${response.statusCode})';
        });
      }
    } catch (e) {
      // 네트워크 오류 처리
      setState(() {
        _errorMessage = '네트워크 오류: $e';
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('로그인'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '전화번호',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone, // 전화번호 입력을 위한 키보드 설정
            ),
            SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
              ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _login,
              child: Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String? clubNo = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text('15지역 회원 주소록'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/clubList');
              },
              child: Text('클럽별 회원 리스트'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/rankMembers');
              },
              child: Text('직책별 회원 리스트'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/search');
              },
              child: Text('키워드 회원 검색'),
            ),
            ElevatedButton(
              onPressed: () {
                if (clubNo != null) {
                  Navigator.pushNamed(
                    context,
                    '/clubDocs',
                    arguments: clubNo, // 클럽 번호 전달
                  );
                } else {
                  // 클럽 번호가 없을 경우 경고 메시지와 로그인 화면으로 리다이렉트
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                  );

                  // 2초 후 로그인 화면으로 이동
                  Future.delayed(Duration(seconds: 2), () {
                    Navigator.pushReplacementNamed(context, '/login');
                  });
                }
              },
              child: Text('클럽 문서 목록'),
            ),
          ],
        ),
      ),
    );
  }
}
