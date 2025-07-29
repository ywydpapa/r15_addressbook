import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'clublogo.dart';
import 'config/api_config.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ClubListScreen(),
      useInheritedMediaQuery: true, // Edge-to-Edge 대응 옵션 (Flutter 3.13+)
    );
  }
}

class Club {
  final int clubNo;
  final String clubName;
  final int regionNo;

  Club({required this.clubNo, required this.clubName, required this.regionNo});

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      clubNo: json['clubNo'],
      clubName: json['clubName'],
      regionNo: json['regionNo'],
    );
  }
}

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  _ClubListScreenState createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  Future<List<Club>>? _clubList;
  int? mregionNo;
  String? mclubNo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final regionArg = args['mregionNo'];
      if (regionArg is int) {
        mregionNo = regionArg;
      } else if (regionArg is String) {
        mregionNo = int.tryParse(regionArg);
      }
      mclubNo = args['mclubNo']?.toString();
      if (_clubList == null && mregionNo != null) {
        _clubList = fetchClubList(mregionNo!);
      }
    }
  }

  Future<List<Club>> fetchClubList(int mregionNo) async {
    final response = await http.get(
      Uri.parse('${ApiConf.baseUrl}/phapp/clubList/$mregionNo'),
    );
    if (response.statusCode == 200) {
      final decodedResponse = utf8.decode(response.bodyBytes);
      Map<String, dynamic> data = json.decode(decodedResponse);
      List<dynamic> clubs = data['clubs'];
      return clubs.map((json) => Club.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load club list');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('ClubListScreen - mclubNo: $mclubNo  mregionNo: $mregionNo');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow,
        title: const Text('클럽 리스트'),
      ),
      backgroundColor: Colors.yellow,
      body: SafeArea(
        child: _clubList == null
            ? const Center(child: Text('No region selected'))
            : FutureBuilder<List<Club>>(
          future: _clubList,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No clubs found'));
            } else {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final club = snapshot.data![index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(club.clubNo.toString())),
                      title: Text(club.clubName),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoadingScreen(
                              clubNo: club.clubNo,
                              clubName: club.clubName,
                              mclubNo: mclubNo,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}
