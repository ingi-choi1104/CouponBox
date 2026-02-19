import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScanResult {
  final String barcodeValue;
  final String barcodeType;
  final String? storeName;
  final String? itemName;
  final int? amount;
  final DateTime? expiryDate;

  const ScanResult({
    required this.barcodeValue,
    required this.barcodeType,
    this.storeName,
    this.itemName,
    this.amount,
    this.expiryDate,
  });
}

class BarcodeScanService {
  static final BarcodeScanService instance = BarcodeScanService._();
  BarcodeScanService._();

  final _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.korean);

  Future<ScanResult?> scanImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      // 바코드 감지
      final barcodes = await _barcodeScanner.processImage(inputImage);
      if (barcodes.isEmpty) return null;

      final barcode = barcodes.first;
      final barcodeValue = barcode.rawValue ?? '';
      if (barcodeValue.isEmpty) return null;

      final barcodeType = _getBarcodeTypeName(barcode.format);

      // OCR로 쿠폰 정보 추출
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final parsedInfo = _parseCouponText(
        recognizedText.text,
        recognizedText.blocks,
      );

      return ScanResult(
        barcodeValue: barcodeValue,
        barcodeType: barcodeType,
        storeName: parsedInfo['storeName'] as String?,
        itemName: parsedInfo['itemName'] as String?,
        amount: parsedInfo['amount'] as int?,
        expiryDate: parsedInfo['expiryDate'] as DateTime?,
      );
    } catch (e) {
      return null;
    }
  }

  String _getBarcodeTypeName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode:
        return 'QR코드';
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.dataMatrix:
        return 'DataMatrix';
      case BarcodeFormat.aztec:
        return 'Aztec';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      default:
        return '바코드';
    }
  }

  Map<String, dynamic> _parseCouponText(
    String text,
    List<TextBlock> blocks,
  ) {
    return {
      'expiryDate': _parseExpiryDate(text),
      'amount': _parseAmount(text),
      ..._parseNames(text, blocks),
    };
  }

  DateTime? _parseExpiryDate(String text) {
    // 한국 쿠폰에서 자주 쓰이는 유효기간 형식들
    final patterns = [
      // 명시적 키워드 포함 형식
      RegExp(r'(?:유효기간|사용기한|이용기한|유효일자)[:\s]*(\d{4})[년./]\s*(\d{1,2})[월./]\s*(\d{1,2})'),
      RegExp(r'(?:~|까지)[:\s]*(\d{4})[./]\s*(\d{1,2})[./]\s*(\d{1,2})'),
      RegExp(r'(\d{4})[년./]\s*(\d{1,2})[월./]\s*(\d{1,2})\s*(?:일?\s*까지|만료)'),
      // 2자리 연도
      RegExp(r'~\s*(\d{2})[./]\s*(\d{2})[./]\s*(\d{2})'),
      // 일반 날짜 형식
      RegExp(r'(\d{4})[년./]\s*(\d{1,2})[월./]\s*(\d{1,2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          int year = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final day = int.parse(match.group(3)!);
          if (year < 100) year += 2000;
          if (month < 1 || month > 12 || day < 1 || day > 31) continue;
          final date = DateTime(year, month, day, 23, 59, 59);
          if (date.isAfter(DateTime(2000)) && date.isBefore(DateTime(2100))) {
            return date;
          }
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  int? _parseAmount(String text) {
    final patterns = [
      RegExp(r'([\d,]+)\s*원권'),
      RegExp(r'([\d,]+)\s*원\s*상품권'),
      RegExp(r'금액[:\s]*([\d,]+)\s*원'),
      RegExp(r'([\d,]+)\s*원'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final amountStr = match.group(1)!.replaceAll(',', '');
          final amount = int.parse(amountStr);
          // 합리적인 쿠폰 금액 범위: 100원 ~ 500만원
          if (amount >= 100 && amount <= 5000000) return amount;
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  Map<String, String?> _parseNames(String text, List<TextBlock> blocks) {
    if (blocks.isEmpty) return {'storeName': null, 'itemName': null};

    // 블록을 위에서 아래 순으로 정렬
    final sortedBlocks = List<TextBlock>.from(blocks)
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    // 알려진 브랜드/매장 목록
    final knownStores = [
      'CU', 'GS25', '세븐일레븐', '이마트24', '미니스톱',
      '스타벅스', 'Starbucks', '투썸플레이스', '이디야', '빽다방', '메가커피',
      '맥도날드', '버거킹', 'KFC', '롯데리아', '서브웨이',
      '이마트', '홈플러스', '롯데마트', '코스트코',
      'CGV', '메가박스', '롯데시네마',
      'SSG', '쿠팡', '카카오', '네이버',
      '배스킨라빈스', '던킨', '파리바게뜨', '뚜레쥬르',
      '올리브영', '다이소', 'GS샵',
    ];

    String? storeName;
    String? itemName;

    // 알려진 브랜드 검색
    for (final store in knownStores) {
      if (text.contains(store)) {
        storeName = store;
        break;
      }
    }

    // 첫 번째 블록에서 매장명 추출
    if (storeName == null && sortedBlocks.isNotEmpty) {
      final firstText = sortedBlocks.first.text.trim();
      if (firstText.length >= 2 && firstText.length <= 20) {
        storeName = firstText;
      }
    }

    // 두 번째 블록에서 품목명 추출
    for (int i = 1; i < sortedBlocks.length && i < 4; i++) {
      final blockText = sortedBlocks[i].text.trim();
      if (blockText.length >= 2 &&
          blockText.length <= 40 &&
          blockText != storeName &&
          !blockText.contains(RegExp(r'\d{4}')) && // 날짜 블록 제외
          !blockText.contains('원')) {
        // 금액 블록 제외
        itemName = blockText;
        break;
      }
    }

    return {'storeName': storeName, 'itemName': itemName};
  }

  Future<void> dispose() async {
    await _barcodeScanner.close();
    await _textRecognizer.close();
  }
}
