import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clubList.dart';
import 'searchresult.dart';
import 'rankMember.dart';
import 'clubDocs.dart';
import 'docViewer.dart';
import 'settings.dart';
import 'request.dart';
import 'notice.dart';
import 'noticeViewer.dart';
import 'config/api_config.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // 추가

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides(); //테스트용 우회 설정

  // 시스템 바를 투명하게 만들고 아이콘 색상을 지정 (edge-to-edge 대응)
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(MyApp());
}

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
      title: 'Lions Club AddressBook for 355-A Regions',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(),
        '/': (context) => HomeScreen(),
        '/clubList': (context) => ClubListScreen(),
        '/search': (context) => MemberSearchScreen(),
        '/rankMembers': (context) => RankMemberScreen(),
        '/clubDocs': (context) => ClubDocsScreen(),
        '/docViewer': (context) => DocViewerScreen(),
        '/noticeViewer': (context) => NoticeViewerScreen(),
        '/request': (context) => RequestScreen(),
        '/setting': (context) => SettingScreen(),
        '/notice': (context) => NoticeScreen(),
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
  String _memberNo = '';
  String _mregionNo = '';

  Future<void> _login() async {
    final phoneno = _usernameController.text;

    if (phoneno.isEmpty) {
      setState(() {
        _errorMessage = '전화번호를 입력하세요.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConf.baseUrl}/phapp/zlogin/$phoneno'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data.containsKey('clubno')) {
          setState(() {
            _clubNo = data['clubno'].toString();
            _memberNo = data['memberno'].toString();
            _mregionNo = data['regionno'].toString();
            _errorMessage = '';
          });

          Navigator.pushReplacementNamed(
            context,
            '/',
            arguments: {
              'clubNo': _clubNo,
              'memberNo': _memberNo,
              'regionNo': _mregionNo,
            },
          );
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
        title: Text('국제라이온스협회 355-A지구 지역주소록'),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea( // <-- SafeArea로 감싸기
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/loginlogo.png',
                width: 300,
                height: 300,
              ),
              SizedBox(height: 8),
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
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? mclubNo = args?['clubNo'];
    final String? memberNo = args?['memberNo'];
    final String? mregionNo = args?['regionNo'];
    final imageUrl = '${ApiConf.baseUrl}/thumbnails/homeImage$mregionNo.jpg';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text(
          (mregionNo != null && mregionNo.isNotEmpty)
              ? '$mregionNo 지역 회원 주소록'
              : '지역주소록 로그인 만료',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.assignment_add),
            onPressed: () {
              if (mclubNo != null) {
                Navigator.pushNamed(
                  context,
                  '/request',
                  arguments: memberNo,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                );
                Future.delayed(Duration(seconds: 2), () {
                  Navigator.pushReplacementNamed(context, '/login');
                });
              }
            },
          ),
        ],
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea( // <-- SafeArea로 감싸기
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha((0.5 * 255).toInt()),
                        blurRadius: 5,
                        spreadRadius: 2,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: (mregionNo != null && mregionNo.isNotEmpty)
                        ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/loginlogo.png',
                          width: double.infinity,
                          height: 400,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                        : Image.asset(
                      'assets/loginlogo.png',
                      width: double.infinity,
                      height: 400,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (mclubNo != null){
                                Navigator.pushNamed(
                                  context,
                                  '/clubList',
                                  arguments: {
                                    'mregionNo': mregionNo,
                                    'mclubNo': mclubNo,
                                  },
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                                );
                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                });
                              }
                            },
                            child: Text('클럽별 회원 목록', maxLines:1,overflow: TextOverflow.ellipsis,),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (mclubNo != null){
                                Navigator.pushNamed(
                                  context,
                                  '/rankMembers',
                                  arguments: {
                                    'mregionNo': mregionNo,
                                    'mclubNo': mclubNo,
                                  },
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                                );
                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                });
                              }
                            },
                            child: Text('직책별 회원 목록',maxLines:1,overflow: TextOverflow.ellipsis,),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (mclubNo != null){
                                Navigator.pushNamed(
                                  context,
                                  '/search',
                                  arguments: {
                                    'mregionNo': mregionNo,
                                    'mclubNo': mclubNo,
                                  },
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                                );
                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                });
                              }
                            },
                            child: Text('키워드 회원 검색',maxLines:1,overflow: TextOverflow.ellipsis,),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (mclubNo != null) {
                                Navigator.pushNamed(
                                  context,
                                  '/clubDocs',
                                  arguments: mclubNo,
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                                );
                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                });
                              }
                            },
                            child: Text('클럽 문서 목록', maxLines:1,overflow: TextOverflow.ellipsis,),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (mclubNo!= null){
                                Navigator.pushNamed(
                                  context,
                                  '/notice',
                                  arguments: {
                                    'mregionNo': mregionNo,
                                    'mclubNo': mclubNo,
                                  },
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                                );
                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                });
                              }
                            },
                            child: Text('공지사항', maxLines:1,overflow: TextOverflow.ellipsis,),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (mclubNo != null) {
                                Navigator.pushNamed(
                                  context,
                                  '/setting',
                                  arguments: {
                                    'clubNo': mclubNo,
                                    'memberNo': memberNo,
                                  },
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
                                );
                                Future.delayed(Duration(seconds: 2), () {
                                  Navigator.pushReplacementNamed(context, '/login');
                                });
                              }
                            },
                            child: Text('설정',maxLines:1,overflow: TextOverflow.ellipsis,),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10,),
            ],
          ),
        ),
      ),
    );
  }
}
