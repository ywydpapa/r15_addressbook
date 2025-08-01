import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clublist.dart';
import 'searchresult.dart';
import 'rankmember.dart';
import 'clubdocs.dart';
import 'docviewer.dart';
import 'settings.dart';
import 'request.dart';
import 'notice.dart';
import 'clubmemberlist.dart';
import 'noticeviewer.dart';
import 'config/api_config.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // 추가
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase 초기화 실패: $e');
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  HttpOverrides.global = MyHttpOverrides(); //테스트용 우회 설정
  NotificationSettings settings = await messaging.requestPermission();

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Android 및 iOS 초기화 설정 추가
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(); // iOS용 설정 추가

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS, // 반드시 추가!
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(MyApp());
}

void subscribeToTopics(String regionNo, String clubNo) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  SharedPreferences prefs = await SharedPreferences.getInstance();

  final regionTopic = 'region_$regionNo';
  final clubTopic = 'club_$clubNo';

  // 이전 클럽 토픽 구독 해제
  String? prevClubNo = prefs.getString('prevClubNo');
  if (prevClubNo != null && prevClubNo != clubNo) {
    await messaging.unsubscribeFromTopic('club_$prevClubNo');
    print('Unsubscribed from club_$prevClubNo');
  }

  // 새 클럽 토픽 구독
  await messaging.subscribeToTopic(clubTopic);
  await messaging.subscribeToTopic(regionTopic);

  // 새 클럽 토픽 저장
  await prefs.setString('prevClubNo', clubNo);

  print('Subscribed to $regionTopic and $clubTopic');
}

void unsubscribeAllTopics() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? prevClubNo = prefs.getString('prevClubNo');
  String? prevRegionNo = prefs.getString('prevRegionNo');
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (prevClubNo != null) {
    await messaging.unsubscribeFromTopic('club_$prevClubNo');
  }
  if (prevRegionNo != null) {
    await messaging.unsubscribeFromTopic('region_$prevRegionNo');
  }
  // 저장값 초기화
  await prefs.remove('prevClubNo');
  await prefs.remove('prevRegionNo');
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
        '/cmList': (context) => ClubMemberListScreen(),
      }
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
  String _funcNo = '';
  String _clubName = '';

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
        Uri.parse('${ApiConf.baseUrl}/phapp/xlogin/$phoneno'),
      );
      final decodedBody = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final data = jsonDecode(decodedBody);

        if (data.containsKey('clubno')) {
          setState(() {
            _clubNo = data['clubno'].toString();
            _memberNo = data['memberno'].toString();
            _mregionNo = data['regionno'].toString();
            _funcNo = data['funcno'].toString();
            _clubName = data['clubname'].toString();
            _errorMessage = '';
          });

          //메세지 토픽호출
          subscribeToTopics(_mregionNo, _clubNo);

          Navigator.pushReplacementNamed(
            context,
            '/',
            arguments: {
              'clubNo': _clubNo,
              'memberNo': _memberNo,
              'regionNo': _mregionNo,
              'funcNo': _funcNo,
              'clubName': _clubName,
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // 포그라운드에서 메시지 수신 시 알림 띄우기
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'fcm_default_channel', // 반드시 AndroidManifest.xml에도 등록되어야 함
              '알림',
              channelDescription: '앱 알림',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? mclubNo = args?['clubNo'];
    final String? memberNo = args?['memberNo'];
    final String? mregionNo = args?['regionNo'];
    final String? mfuncNo = args?['funcNo'];
    final String? clubName = args?['clubName'] ?? args?['clubname'];
    final imageUrl = '${ApiConf.baseUrl}/thumbnails/homeImage$mregionNo.jpg';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: Text(
          (mfuncNo == '1')
              ? ((mclubNo != null && mclubNo.isNotEmpty)
              ? '$clubName 주소록'
              : '$clubName 주소록 로그인 만료')
              : ((mregionNo != null && mregionNo.isNotEmpty)
              ? '$mregionNo 지역 회원 주소록'
              : '지역주소록 로그인 만료'),
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
      body: SafeArea(
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
                  children: _buildButtons(context, mfuncNo, mclubNo, mregionNo, memberNo, clubName),
                ),
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
  List<Widget> _buildButtons(BuildContext context, String? mfuncNo, String? mclubNo, String? mregionNo, String? memberNo, String? clubName) {
    if (mfuncNo == '1') {
      return [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/cmList',
                    arguments: {
                      'mregionNo': mregionNo,
                      'mclubNo': mclubNo,
                      'clubNo': mclubNo,
                      'clubName': clubName,
                    },
                  );
                },
                child: Text('$clubName 회원목록', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    _showSessionExpired(context);
                  }
                },
                child: Text('클럽문서목록', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                  Navigator.pushNamed(
                    context,
                    '/notice',
                    arguments: {
                      'mregionNo': mregionNo,
                      'mclubNo': mclubNo,
                      'mfuncNo': mfuncNo,
                    },
                  );
                },
                child: Text('$clubName 공지사항', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/setting',
                    arguments: {
                      'clubNo': mclubNo,
                      'memberNo': memberNo,
                      'mfuncNo': mfuncNo,
                    },
                  );
                },
                child: Text('설정', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ];
    } else {
      // 기본: 기존 8개 버튼(2x4)
      return [
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
                    _showSessionExpired(context);
                  }
                },
                child: Text('클럽별 회원 목록', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    _showSessionExpired(context);
                  }
                },
                child: Text('직책별 회원 목록', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    _showSessionExpired(context);
                  }
                },
                child: Text('키워드 회원 검색', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    _showSessionExpired(context);
                  }
                },
                child: Text('클럽 문서 목록', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    _showSessionExpired(context);
                  }
                },
                child: Text('공지사항', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        'mfuncNo': mfuncNo,
                      },
                    );
                  } else {
                    _showSessionExpired(context);
                  }
                },
                child: Text('설정', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ];
    }
  }

  void _showSessionExpired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
    );
    unsubscribeAllTopics();//알림 받기 해제
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }
}
