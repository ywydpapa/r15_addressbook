import 'dart:io';

class ApiConf {
  // ---------------------------------------------------------
  // 1. 테스트 환경에 맞게 아래 주석을 해제해서 사용하세요.
  // ---------------------------------------------------------

  // [iOS 시뮬레이터 / 웹 / 데스크톱 테스트용]
  //static String baseUrl = 'http://127.0.0.1:8000';

  // [안드로이드 에뮬레이터 테스트용]
  //static String baseUrl = 'http://10.0.2.2:8000';

  // [실제 스마트폰 기기 테스트용 (PC의 내부 IP 입력)]
  //static String baseUrl = 'https://192.168.11.3';

  // [운영 서버용 (배포 시 주석 해제)]
  static String baseUrl = 'https://lionsaddr.biz-core.co.kr';

  static Future<void> init() async {
    // 로컬 테스트용 주소일 경우 DNS Lookup(운영서버 IP 찾기)을 생략합니다.
    if (baseUrl.contains('127.0.0.1') ||
        baseUrl.contains('10.0.2.2') ||
        baseUrl.contains('192.168.')) {
      return;
    }

    try {
      final addresses = await InternetAddress.lookup('lionsaddr.biz-core.co.kr');
      if (addresses.isNotEmpty) {
        baseUrl = 'https://${addresses.first.address}';
      }
    } catch (e) {
      // lookup 실패 시 기존 도메인 사용
      baseUrl = 'https://125.184.193.192';
    }
  }
}
