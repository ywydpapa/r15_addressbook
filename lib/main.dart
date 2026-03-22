import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clublist.dart';
import 'searchresult.dart';
import 'clubsearchresult.dart';
import 'rankmember.dart';
import 'clubdocs.dart';
import 'docviewer.dart';
import 'settings.dart';
import 'request.dart';
import 'circlelist.dart';
import 'notice.dart';
import 'clubmemberlist.dart';
import 'noticeviewer.dart';
import 'config/api_config.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_update/in_app_update.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<List<dynamic>> fetchCircleList(String memberNo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';

    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/getmycircle/$memberNo'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final decodedBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(decodedBody);
      if (data is Map && data.containsKey('circles')) {
        final circles = data['circles'];
        if (circles is List) {
          return circles;
        }
      }
    } else if (response.statusCode == 401) {
      print('인증 오류: 토큰이 만료되었거나 유효하지 않습니다.');
    }
  } catch (e) {
    print('써클 리스트 조회 오류: $e');
  }
  return [];
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// 🎨 앱 전체에서 사용할 주요 색상 정의 (라이온스클럽 테마: 네이비 & 골드)
const Color primaryNavy = Color(0xFF003366);
const Color primaryGold = Color(0xFFFFC107);
const Color bgColor = Color(0xFFF8F9FA);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print(e);
  }
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS =
  const DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

void subscribeToTopics(String regionNo, String clubNo, String memberNo) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  SharedPreferences prefs = await SharedPreferences.getInstance();

  final regionTopic = 'region_$regionNo';
  final clubTopic = 'club_$clubNo';
  final memberTopic = 'member_$memberNo';

  String? prevClubNo = prefs.getString('prevClubNo');
  String? prevRegionNo = prefs.getString('prevRegionNo');
  String? prevMemberNo = prefs.getString('prevMemberNo');

  if (prevClubNo != null && prevClubNo != clubNo) {
    await messaging.unsubscribeFromTopic('club_$prevClubNo');
  }
  if (prevRegionNo != null && prevRegionNo != regionNo) {
    await messaging.unsubscribeFromTopic('region_$prevRegionNo');
  }
  if (prevMemberNo != null && prevMemberNo != memberNo) {
    await messaging.unsubscribeFromTopic('member_$prevMemberNo');
  }

  await messaging.subscribeToTopic(clubTopic);
  await messaging.subscribeToTopic(regionTopic);
  await messaging.subscribeToTopic(memberTopic);

  await prefs.setString('prevClubNo', clubNo);
  await prefs.setString('prevRegionNo', regionNo);
  await prefs.setString('prevMemberNo', memberNo);
}

void unsubscribeAllTopics() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? prevClubNo = prefs.getString('prevClubNo');
  String? prevRegionNo = prefs.getString('prevRegionNo');
  String? prevMemberNo = prefs.getString('prevMemberNo');
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (prevClubNo != null) {
    await messaging.unsubscribeFromTopic('club_$prevClubNo');
  }
  if (prevRegionNo != null) {
    await messaging.unsubscribeFromTopic('region_$prevRegionNo');
  }
  if (prevMemberNo != null) {
    await messaging.unsubscribeFromTopic('member_$prevMemberNo');
  }

  await prefs.remove('prevClubNo');
  await prefs.remove('prevRegionNo');
  await prefs.remove('prevMemberNo');
  await prefs.remove('access_token');
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => false;
  }
}

class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    // 상수에 맞게 수정 필요 (예: 'autoLoginEnabled', 'autoLoginPhone' 등)
    final enabled = prefs.getBool('autoLoginEnabled') ?? false;
    final phone = (prefs.getString('autoLoginPhone') ?? '').trim();

    if (enabled && phone.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse('${ApiConf.baseUrl}/phapp/xlogin/$phone'),
        );

        final decodedBody = utf8.decode(res.bodyBytes);

        if (res.statusCode == 200) {
          final data = jsonDecode(decodedBody);

          if (data is Map && data.containsKey('clubno') && data.containsKey('access_token')) {
            await prefs.setString('access_token', data['access_token']);

            final clubNo = data['clubno'].toString();
            final memberNo = data['memberno'].toString();
            final regionNo = data['regionno'].toString();
            final funcNo = data['funcno'].toString();
            final clubName = data['clubname'].toString();

            subscribeToTopics(regionNo, clubNo, memberNo);

            if (!mounted) return;
            Navigator.pushReplacementNamed(
              context,
              '/home',
              arguments: {
                'clubNo': clubNo,
                'memberNo': memberNo,
                'regionNo': regionNo,
                'funcNo': funcNo,
                'clubName': clubName,
              },
            );
            return;
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryNavy, // 🎨 로딩 화면 색상 변경
      body: Center(
        child: CircularProgressIndicator(color: primaryGold),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '국제라이온스협회 355-A지구',
      theme: ThemeData(
        primaryColor: primaryNavy,
        scaffoldBackgroundColor: bgColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: primaryNavy,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: primaryNavy),
        ),
      ),
      home: const LaunchGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/clubList': (context) => const ClubListScreen(),
        '/circleList': (context) => const CircleListScreen(),
        '/csearch': (context) => const CMemberSearchScreen(),
        '/search': (context) => const MemberSearchScreen(),
        '/rankMembers': (context) => const RankMemberScreen(),
        '/clubDocs': (context) => const ClubDocsScreen(),
        '/docViewer': (context) => const DocViewerScreen(),
        '/noticeViewer': (context) => const NoticeViewerScreen(),
        '/request': (context) => const RequestScreen(),
        '/setting': (context) => const SettingScreen(),
        '/notice': (context) => const NoticeScreen(),
        '/cmList': (context) => const ClubMemberListScreen(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String _errorMessage = '';

  Future<void> _login() async {
    final phoneno = _usernameController.text.trim();
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

        if (data.containsKey('clubno') && data.containsKey('access_token')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', data['access_token']);

          final clubNo = data['clubno'].toString();
          final memberNo = data['memberno'].toString();
          final mregionNo = data['regionno'].toString();
          final funcNo = data['funcno'].toString();
          final clubName = data['clubname'].toString();

          subscribeToTopics(mregionNo, clubNo, memberNo);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/home',
            arguments: {
              'clubNo': clubNo,
              'memberNo': memberNo,
              'regionNo': mregionNo,
              'funcNo': funcNo,
              'clubName': clubName,
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
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white, // 🎨 배경색 변경
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🎨 로고 영역
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade50,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/loginlogo.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '국제라이온스협회 355-A지구',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '지역주소록 로그인',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 🎨 텍스트 필드 디자인
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '전화번호',
                      hintText: '숫자만 입력해주세요',
                      prefixIcon: const Icon(Icons.phone_iphone, color: primaryNavy),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryNavy, width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage.isNotEmpty)
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  const SizedBox(height: 24),

                  // 🎨 로그인 버튼 디자인
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: const Text(
                        '로그인',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
  List<dynamic> _circleList = [];
  bool _circleLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fcm_default_channel',
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final String? memberNo = args?['memberNo'];
      if (memberNo != null && memberNo.isNotEmpty) {
        final list = await fetchCircleList(memberNo);
        if (mounted) {
          setState(() {
            _circleList = list;
            _circleLoaded = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _circleLoaded = true;
          });
        }
      }
    });
  }

  Future<void> _checkForUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      print('인앱 업데이트 오류: $e');
    }
  }

  // 🎨 대시보드 스타일의 메뉴 버튼 빌더
  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 140, // 👈 1. 모든 버튼이 동일한 크기를 가지도록 고정 높이 추가
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, // 👈 2. 내부 콘텐츠를 수직 중앙 정렬
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryNavy.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: primaryNavy),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.2, // 텍스트 줄간격 조정
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? mclubNo = args?['clubNo'];
    final String? clubNo = args?['clubNo'];
    final String? memberNo = args?['memberNo'];
    final String? mregionNo = args?['regionNo'];
    final String? mfuncNo = args?['funcNo'];
    final String? clubName = args?['clubName'] ?? args?['clubname'];
    final imageUrl = '${ApiConf.baseUrl}/thumbnails/homeImage$mregionNo.jpg';

    String appBarTitle = '주소록';
    if (mfuncNo == '1') {
      appBarTitle = (mclubNo != null && mclubNo.isNotEmpty) ? '$clubName 주소록' : '로그아웃됨';
    } else if (mfuncNo == '2'){
      appBarTitle = (mclubNo != null && mclubNo.isNotEmpty) ? '소속 모임 주소록' : '로그아웃됨';
    } else {
      appBarTitle = (mregionNo != null && mregionNo.isNotEmpty) ? '$mregionNo 지역 회원 주소록' : '로그아웃됨';
    }

    return Scaffold(
      backgroundColor: bgColor, // 🎨 배경색 변경
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'request') {
                if (mclubNo != null) {
                  Navigator.pushNamed(context, '/request', arguments: memberNo);
                } else {
                  _showSessionExpired(context);
                }
              } else if (value == 'setting') {
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
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'request',
                child: Row(
                  children: [
                    Icon(Icons.edit_document, color: primaryNavy, size: 20),
                    SizedBox(width: 12),
                    Text('데이터수정 요청하기'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'setting',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: primaryNavy, size: 20),
                    SizedBox(width: 12),
                    Text('설정변경'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎨 상단 메인 이미지 배너
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: (mregionNo != null && mregionNo.isNotEmpty)
                        ? Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFallbackImage();
                      },
                    )
                        : _buildFallbackImage(),
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  '메뉴',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryNavy,
                  ),
                ),
              ),

              // 🎨 대시보드 형태의 버튼 리스트
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: _buildButtons(
                    context,
                    mfuncNo,
                    mclubNo,
                    clubNo,
                    mregionNo,
                    memberNo,
                    clubName,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      color: Colors.grey.shade100,
      width: double.infinity,
      height: 250,
      child: Center(
        child: Image.asset(
          'assets/loginlogo.png',
          width: 150,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  List<Widget> _buildButtons(
      BuildContext context,
      String? mfuncNo,
      String? mclubNo,
      String? clubNo,
      String? mregionNo,
      String? memberNo,
      String? clubName,
      ) {
    List<Widget> widgets = [];

    // 🌟 1. 써클 모드 (mfuncNo == '2')
    if (mfuncNo == '2') {
      widgets.addAll([
        Row(
          children: [
            _buildMenuCard(
              title: '써클 목록',
              icon: Icons.stars,
              onTap: () {
                Navigator.pushNamed(context, '/circleList', arguments: {'memberNo': memberNo});
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 💡 써클 문서함을 제외하고 공지사항만 남겨두면 Expanded 속성에 의해 가로 전체를 차지하게 됩니다.
            _buildMenuCard(
              title: '써클 공지사항',
              icon: Icons.campaign,
              onTap: () {
                // 💡 기존에 만들어둔 공지사항 화면으로 연결 (써클 공지 탭만 뜨도록 처리됨)
                Navigator.pushNamed(context, '/notice', arguments: {
                  'mregionNo': mregionNo,
                  'mclubNo': mclubNo,
                  'clubNo': clubNo,
                  'mfuncNo': mfuncNo,
                  'memberNo': memberNo,
                  'clubName': clubName,
                });
              },
            ),
          ],
        ),
      ]);
    }
    // 🌟 2. 기존 클럽 모드
    else if (mfuncNo == '1') {
      widgets.addAll([
        Row(
          children: [
            _buildMenuCard(
              title: '$clubName\n회원목록',
              icon: Icons.groups,
              onTap: () {
                Navigator.pushNamed(context, '/cmList', arguments: {
                  'mregionNo': mregionNo,
                  'mclubNo': mclubNo,
                  'clubNo': clubNo,
                  'clubName': clubName,
                });
              },
            ),
            const SizedBox(width: 12),
            _buildMenuCard(
              title: '$clubName\n클럽회원검색',
              icon: Icons.person_search,
              onTap: () {
                Navigator.pushNamed(context, '/csearch', arguments: {
                  'mregionNo': mregionNo,
                  'mclubNo': mclubNo,
                  'clubNo': clubNo,
                  'mfuncNo': mfuncNo,
                  'memberNo': memberNo,
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMenuCard(
              title: '$clubName\n공지사항',
              icon: Icons.campaign,
              onTap: () {
                Navigator.pushNamed(context, '/notice', arguments: {
                  'mregionNo': mregionNo,
                  'mclubNo': mclubNo,
                  'clubNo': clubNo,
                  'mfuncNo': mfuncNo,
                  'memberNo': memberNo,
                });
              },
            ),
            const SizedBox(width: 12),
            _buildMenuCard(
              title: '클럽 문서 목록',
              icon: Icons.folder_shared,
              onTap: () {
                if (mclubNo != null) {
                  Navigator.pushNamed(context, '/clubDocs', arguments: mclubNo);
                } else {
                  _showSessionExpired(context);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_circleList.isNotEmpty)
          Row(
            children: [
              _buildMenuCard(
                title: '써클 목록',
                icon: Icons.stars,
                onTap: () {
                  Navigator.pushNamed(context, '/circleList', arguments: {'memberNo': memberNo});
                },
              ),
              const SizedBox(width: 12),
              Expanded(child: Container()), // 빈 공간 채우기
            ],
          ),
      ]);
    }
    // 🌟 3. 기존 지역/지구 모드
    else {
      widgets.addAll([
        Row(
          children: [
            _buildMenuCard(
              title: '클럽별 회원 목록',
              icon: Icons.list_alt,
              onTap: () {
                if (mclubNo != null) {
                  Navigator.pushNamed(context, '/clubList', arguments: {
                    'mregionNo': mregionNo,
                    'mclubNo': mclubNo,
                    'clubNo': clubNo,
                  });
                } else {
                  _showSessionExpired(context);
                }
              },
            ),
            const SizedBox(width: 12),
            _buildMenuCard(
              title: '직책별 회원 목록',
              icon: Icons.badge,
              onTap: () {
                if (mclubNo != null) {
                  Navigator.pushNamed(context, '/rankMembers', arguments: {
                    'mregionNo': mregionNo,
                    'mclubNo': mclubNo,
                    'clubNo': clubNo,
                  });
                } else {
                  _showSessionExpired(context);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMenuCard(
              title: '키워드 회원 검색',
              icon: Icons.search,
              onTap: () {
                if (mclubNo != null) {
                  Navigator.pushNamed(context, '/search', arguments: {
                    'mregionNo': mregionNo,
                    'mclubNo': mclubNo,
                    'clubNo': clubNo,
                  });
                } else {
                  _showSessionExpired(context);
                }
              },
            ),
            const SizedBox(width: 12),
            _buildMenuCard(
              title: '클럽 문서 목록',
              icon: Icons.folder_shared,
              onTap: () {
                if (mclubNo != null) {
                  Navigator.pushNamed(context, '/clubDocs', arguments: mclubNo);
                } else {
                  _showSessionExpired(context);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMenuCard(
              title: '공지사항',
              icon: Icons.campaign,
              onTap: () {
                if (mclubNo != null) {
                  Navigator.pushNamed(context, '/notice', arguments: {
                    'mregionNo': mregionNo,
                    'mclubNo': mclubNo,
                    'clubNo': clubNo,
                    'memberNo': memberNo,
                    'mfuncNo': mfuncNo,
                    'clubName': clubName,
                  });
                } else {
                  _showSessionExpired(context);
                }
              },
            ),
            const SizedBox(width: 12),
            if (_circleList.isNotEmpty)
              _buildMenuCard(
                title: '써클 목록',
                icon: Icons.stars,
                onTap: () {
                  Navigator.pushNamed(context, '/circleList', arguments: {'memberNo': memberNo});
                },
              )
            else
              Expanded(child: Container()), // 빈 공간 채우기
          ],
        ),
      ]);
    }
    return widgets;
  }


  void _showSessionExpired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인세션이 만료되었습니다. 다시 로그인해야 합니다.')),
    );
    unsubscribeAllTopics();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }
}
