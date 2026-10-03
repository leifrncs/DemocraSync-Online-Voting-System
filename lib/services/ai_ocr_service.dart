import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class OCRScanResult {
  final bool isCOR;
  final bool isOfficialCOR;
  final bool hasNemsuHeader;
  final bool hasScheduleTable;
  final bool hasCertification;
  final bool hasRegistrarSignature;
  final String detectedStudentId;
  final String detectedFullName;
  final String detectedDepartment;
  final String detectedCourse;
  final String academicYear;
  final String semester;
  final double confidence;
  final bool idMatched;
  final bool nameMatched;
  final bool termMatched;
  final bool isOutdated;
  final String verdict; // 'Verified', 'Pending Verification', 'Rejected'
  final String reason;
  final Map<String, dynamic> rawData;

  OCRScanResult({
    required this.isCOR,
    this.isOfficialCOR = true,
    this.hasNemsuHeader = true,
    this.hasScheduleTable = true,
    this.hasCertification = true,
    this.hasRegistrarSignature = true,
    required this.detectedStudentId,
    required this.detectedFullName,
    required this.detectedDepartment,
    required this.detectedCourse,
    required this.academicYear,
    required this.semester,
    required this.confidence,
    required this.idMatched,
    required this.nameMatched,
    this.termMatched = true,
    this.isOutdated = false,
    required this.verdict,
    required this.reason,
    required this.rawData,
  });

  factory OCRScanResult.fromMap(Map<String, dynamic> map) {
    String rawVerdict = map['verdict']?.toString().toUpperCase() ?? 'PENDING';
    String normalizedVerdict = 'Pending Verification';
    if (rawVerdict == 'VERIFIED' || rawVerdict == 'VERIFY') {
      normalizedVerdict = 'Verified';
    } else if (rawVerdict == 'REJECTED' || rawVerdict == 'REJECT') {
      normalizedVerdict = 'Rejected';
    }

    bool isOfficialCOR = map['isOfficialCOR'] == true ||
        (map['isCOR'] == true &&
            map['hasNemsuHeader'] != false &&
            map['hasScheduleTable'] != false);
    bool hasNemsuHeader = map['hasNemsuHeader'] == true || (map['hasNemsuHeader'] == null && isOfficialCOR);
    bool hasScheduleTable = map['hasScheduleTable'] == true || (map['hasScheduleTable'] == null && isOfficialCOR);
    bool hasCertification = map['hasCertification'] == true || (map['hasCertification'] == null && isOfficialCOR);
    bool hasRegistrarSignature = map['hasRegistrarSignature'] == true || (map['hasRegistrarSignature'] == null && isOfficialCOR);

    bool isOutdated = map['isOutdated'] == true ||
        (map['termMatched'] == false && map['isCOR'] == true);
    bool termMatched = map['termMatched'] == true ||
        (map['termMatched'] == null && !isOutdated);

    return OCRScanResult(
      isCOR: map['isCOR'] == true,
      isOfficialCOR: isOfficialCOR,
      hasNemsuHeader: hasNemsuHeader,
      hasScheduleTable: hasScheduleTable,
      hasCertification: hasCertification,
      hasRegistrarSignature: hasRegistrarSignature,
      detectedStudentId: map['detectedStudentId']?.toString() ?? 'N/A',
      detectedFullName: map['detectedFullName']?.toString() ?? 'N/A',
      detectedDepartment: map['detectedDepartment']?.toString() ?? 'N/A',
      detectedCourse: map['detectedCourse']?.toString() ?? 'N/A',
      academicYear: map['academicYear']?.toString() ?? 'N/A',
      semester: map['semester']?.toString() ?? 'N/A',
      confidence: (map['confidence'] is num)
          ? (map['confidence'] as num).toDouble()
          : 0.85,
      idMatched: map['idMatched'] == true,
      nameMatched: map['nameMatched'] == true,
      termMatched: termMatched,
      isOutdated: isOutdated,
      verdict: normalizedVerdict,
      reason: map['reason']?.toString() ?? 'Verification processed.',
      rawData: map,
    );
  }

  factory OCRScanResult.fallbackPending({required String reason}) {
    return OCRScanResult(
      isCOR: true,
      isOfficialCOR: false,
      hasNemsuHeader: false,
      hasScheduleTable: false,
      hasCertification: false,
      hasRegistrarSignature: false,
      detectedStudentId: 'Manual Inspection Required',
      detectedFullName: 'Manual Inspection Required',
      detectedDepartment: 'N/A',
      detectedCourse: 'N/A',
      academicYear: 'N/A',
      semester: 'N/A',
      confidence: 0.5,
      idMatched: false,
      nameMatched: false,
      termMatched: false,
      isOutdated: false,
      verdict: 'Pending Verification',
      reason: reason,
      rawData: {'fallback': true, 'reason': reason},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isCOR': isCOR,
      'isOfficialCOR': isOfficialCOR,
      'hasNemsuHeader': hasNemsuHeader,
      'hasScheduleTable': hasScheduleTable,
      'hasCertification': hasCertification,
      'hasRegistrarSignature': hasRegistrarSignature,
      'detectedStudentId': detectedStudentId,
      'detectedFullName': detectedFullName,
      'detectedDepartment': detectedDepartment,
      'detectedCourse': detectedCourse,
      'academicYear': academicYear,
      'semester': semester,
      'confidence': confidence,
      'idMatched': idMatched,
      'nameMatched': nameMatched,
      'termMatched': termMatched,
      'isOutdated': isOutdated,
      'verdict': verdict,
      'reason': reason,
      'scannedAt': FieldValue.serverTimestamp(),
    };
  }
}

class ApiTestResult {
  final bool isValid;
  final String message;
  final int? statusCode;
  final String? errorCode;
  final String? troubleshootingTip;
  final String? detectedModelName;
  final List<String>? availableModels;

  ApiTestResult({
    required this.isValid,
    required this.message,
    this.statusCode,
    this.errorCode,
    this.troubleshootingTip,
    this.detectedModelName,
    this.availableModels,
  });

  factory ApiTestResult.success({
    String? detectedModelName,
    List<String>? availableModels,
    String? message,
  }) =>
      ApiTestResult(
        isValid: true,
        message: message ??
            (detectedModelName != null
                ? 'Gemini API connected successfully using $detectedModelName!'
                : 'Gemini API Key verified and connected successfully!'),
        detectedModelName: detectedModelName,
        availableModels: availableModels,
      );

  factory ApiTestResult.failure({
    required String message,
    int? statusCode,
    String? errorCode,
    String? tip,
    List<String>? availableModels,
  }) =>
      ApiTestResult(
        isValid: false,
        message: message,
        statusCode: statusCode,
        errorCode: errorCode,
        troubleshootingTip: tip,
        availableModels: availableModels,
      );
}

const List<String> presetVisionModels = [
  'gemini-flash-lite-latest',
  'gemini-2.5-flash',
  'gemini-1.5-flash-8b',
  'gemini-1.5-flash',
  'gemini-2.0-flash',
  'gemini-3.8-flash',
];

class AiOcrService {
  static final AiOcrService _instance = AiOcrService._internal();
  factory AiOcrService() => _instance;
  AiOcrService._internal();

  /// Retrieves the active Gemini API key from Firestore settings or constants fallback.
  Future<String> getActiveApiKey() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('system_settings')
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;
        String? key = data['geminiApiKey']?.toString().trim();
        if (key != null && key.isNotEmpty) {
          return key;
        }
      }
    } catch (_) {
      // Ignore Firestore read error, fall back
    }
    return defaultGeminiApiKey.trim();
  }

  /// Retrieves the active Gemini model name from Firestore settings or constants fallback.
  Future<String> getActiveModelName() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('system_settings')
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;
        String? model = data['geminiModelName']?.toString().trim();
        if (model != null && model.isNotEmpty) {
          return model;
        }
      }
    } catch (_) {
      // Ignore Firestore read error, fall back
    }
    return geminiModelName.trim();
  }

  /// Retrieves the active Academic Year, Semester, and verification enforcement settings.
  Future<Map<String, dynamic>> getActiveAcademicPeriod() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('election_settings')
          .get();

      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'academicYear':
              data['academicYear']?.toString().trim() ?? '2026-2027',
          'semester': data['semester']?.toString().trim() ?? '1st Semester',
          'enforceTermVerification': data['enforceTermVerification'] != false,
        };
      }
    } catch (_) {}
    return {
      'academicYear': '2026-2027',
      'semester': '1st Semester',
      'enforceTermVerification': true,
    };
  }

  /// Saves or updates the Gemini API key and model in Firestore system settings.
  Future<void> saveApiKey(String apiKey, {String? modelName}) async {
    final Map<String, dynamic> data = {
      'geminiApiKey': apiKey.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (modelName != null && modelName.trim().isNotEmpty) {
      data['geminiModelName'] = modelName.trim();
    }
    await FirebaseFirestore.instance
        .collection('config')
        .doc('system_settings')
        .set(data, SetOptions(merge: true));
  }

  /// Discovers available multimodal vision models for the given API key via Google's ListModels API.
  Future<List<String>> listAvailableModels(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) return [];

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$cleanKey');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? modelsList = data['models'] as List<dynamic>?;
        if (modelsList != null) {
          final List<String> supportedModels = [];
          for (var item in modelsList) {
            if (item is Map<String, dynamic>) {
              String name = item['name']?.toString() ?? '';
              if (name.startsWith('models/')) {
                name = name.substring(7);
              }
              final lower = name.toLowerCase();
              // Exclude text-only, audio, embeddings, and Gemma models
              if (lower.startsWith('gemma') ||
                  lower.contains('embedding') ||
                  lower.contains('aqa') ||
                  lower.contains('imagen') ||
                  lower.contains('whisper') ||
                  lower.contains('tts') ||
                  lower.contains('bison')) {
                continue;
              }

              List<dynamic> methods =
                  item['supportedGenerationMethods'] as List<dynamic>? ?? [];
              if (methods.contains('generateContent')) {
                supportedModels.add(name);
              }
            }
          }
          return supportedModels;
        }
      }
    } catch (_) {}
    return [];
  }
  /// Picks the optimal multimodal vision / flash model from a list of available models.
  String selectBestModel(List<String> availableModels) {
    const priorityList = [
      'gemini-flash-lite-latest',
      'gemini-2.5-flash',
      'gemini-1.5-flash-8b',
      'gemini-2.0-flash-lite',
      'gemini-1.5-flash',
      'gemini-2.0-flash',
      'gemini-3.8-flash',
      'gemini-3.5-flash',
      'gemini-3-flash',
      'gemini-2.5-pro',
      'gemini-1.5-pro',
    ];

    for (var candidate in priorityList) {
      if (availableModels.contains(candidate)) {
        return candidate;
      }
    }

    // Look for any gemini model containing 'flash'
    for (var m in availableModels) {
      final lower = m.toLowerCase();
      if (lower.contains('gemini') && lower.contains('flash')) {
        return m;
      }
    }

    // Look for any other gemini model
    for (var m in availableModels) {
      final lower = m.toLowerCase();
      if (lower.contains('gemini')) {
        return m;
      }
    }

    if (availableModels.isNotEmpty) {
      return availableModels.first;
    }
    return geminiModelName;
  }

  /// Tests a Gemini API Key to verify connectivity and validity with dynamic vision model auto-detection.
  Future<ApiTestResult> testApiKey(String apiKey, {String? preferredModel}) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      return ApiTestResult.failure(
        message: 'API Key cannot be empty.',
        tip: 'Please enter a valid Google Gemini API Key from Google AI Studio.',
      );
    }

    try {
      // 1. Query ListModels to find which vision models are provisioned for this key
      List<String> availableModels = await listAvailableModels(cleanKey);

      // 2. Determine target models to test (preferred model first, discovered models, then priority candidates)
      List<String> modelsToTry = [];
      if (preferredModel != null && preferredModel.trim().isNotEmpty) {
        modelsToTry.add(preferredModel.trim());
      }
      if (availableModels.isNotEmpty) {
        String best = selectBestModel(availableModels);
        if (!modelsToTry.contains(best)) modelsToTry.add(best);
        for (var m in availableModels) {
          if (!modelsToTry.contains(m)) modelsToTry.add(m);
        }
      } else {
        for (var m in presetVisionModels) {
          if (!modelsToTry.contains(m)) modelsToTry.add(m);
        }
      }

      http.Response? lastResponse;
      String? successfulModel;

      for (String model in modelsToTry) {
        try {
          final pingUrl = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey');

          final response = await http.post(
            pingUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': 'Ping'}
                  ]
                }
              ]
            }),
          ).timeout(const Duration(seconds: 8));

          lastResponse = response;

          if (response.statusCode == 200) {
            successfulModel = model;
            break;
          }
        } catch (_) {
          // Try next candidate model
        }
      }

      if (successfulModel != null) {
        return ApiTestResult.success(
          detectedModelName: successfulModel,
          availableModels: availableModels.isNotEmpty ? availableModels : presetVisionModels,
          message: 'Connection verified! Active model: $successfulModel',
        );
      }

      // If all models failed, parse last error response
      int statusCode = lastResponse?.statusCode ?? 500;
      String errorMessage = 'Request failed with HTTP status $statusCode';
      String? errorCode;
      String? tip;

      if (lastResponse != null) {
        try {
          final errorJson = jsonDecode(lastResponse.body);
          if (errorJson is Map<String, dynamic> &&
              errorJson.containsKey('error')) {
            final err = errorJson['error'];
            if (err is Map<String, dynamic>) {
              errorMessage = err['message']?.toString() ?? errorMessage;
              errorCode = err['status']?.toString();
            }
          }
        } catch (_) {}
      }

      if (statusCode == 400 || errorCode == 'INVALID_ARGUMENT') {
        tip =
            'The API key appears invalid or malformed. Verify you copied the complete key (starts with AIzaSy...) without extra spaces.';
      } else if (statusCode == 403 || errorCode == 'PERMISSION_DENIED') {
        tip =
            'Permission denied. Ensure the "Generative Language API" is enabled in your Google Cloud Console and check API key restrictions.';
      } else if (statusCode == 404 || errorCode == 'NOT_FOUND') {
        tip =
            'Models not found for your API key. Please check if your Google AI Studio project has access to Gemini vision models in your region.';
      } else if (statusCode == 429 || errorCode == 'RESOURCE_EXHAUSTED') {
        tip =
            'Rate limit or high demand reached on this model. Try selecting another model (e.g. gemini-1.5-flash-8b or gemini-2.5-flash).';
      } else if (statusCode >= 500) {
        tip =
            'Google AI service is currently experiencing high demand. Automatic fallback to alternative vision models will engage during scanning.';
      }

      return ApiTestResult.failure(
        message: errorMessage,
        statusCode: statusCode,
        errorCode: errorCode,
        tip: tip,
        availableModels: availableModels.isNotEmpty ? availableModels : presetVisionModels,
      );
    } catch (e) {
      String tip = 'Check your network connection, Wi-Fi, or firewall settings.';
      if (e.toString().contains('TimeoutException')) {
        tip =
            'Connection timed out after 10 seconds. Check if generativelanguage.googleapis.com is reachable.';
      }
      return ApiTestResult.failure(
        message: 'Network / Connection error: $e',
        tip: tip,
      );
    }
  }

  /// Analyzes a Certificate of Registration (COR) image with term validation & seamless multi-model fallback.
  Future<OCRScanResult> analyzeCOR({
    required Uint8List imageBytes,
    required String studentId,
    required String fullName,
    required String department,
    required String course,
    String? expectedAcademicYear,
    String? expectedSemester,
    String? mimeType,
  }) async {
    final apiKey = await getActiveApiKey();
    final activeModel = await getActiveModelName();
    final periodInfo = await getActiveAcademicPeriod();

    final targetAcademicYear =
        expectedAcademicYear ?? periodInfo['academicYear'] ?? '2026-2027';
    final targetSemester =
        expectedSemester ?? periodInfo['semester'] ?? '1st Semester';
    final bool enforceTerm = periodInfo['enforceTermVerification'] != false;

    if (apiKey.isEmpty) {
      return OCRScanResult.fallbackPending(
        reason: 'AI OCR API Key not configured. Document queued for manual Admin review.',
      );
    }

    try {
      String base64Image = base64Encode(imageBytes);
      String effectiveMimeType = mimeType ?? _detectMimeType(imageBytes);

      final prompt = '''
You are the official Document Verification & Anti-Spoofing AI for NEMSU (North Eastern Mindanao State University) DemocraSync election system.
Carefully analyze this uploaded document image to verify whether it is a genuine, official NEMSU Certificate of Registration (COR) and validate the student's enrollment credentials.

Expected Student Registration Details:
- Student ID Number: "$studentId"
- Full Name: "$fullName"
- Department: "$department"
- Degree Program / Course: "$course"
- Active Election Academic Year: "$targetAcademicYear"
- Active Election Semester: "$targetSemester"

Document Structural & Authenticity Verification Criteria:
An authentic NEMSU Certificate of Registration has specific visual, institutional, and tabular layout markers:
1. Institutional Header & Branding (hasNemsuHeader):
   - Institutional Name: "NORTH EASTERN MINDANAO STATE UNIVERSITY" (or legacy/campus name "Formerly Surigao del Sur State University" / "SDSSU" across any official NEMSU campus).
   - University seal/logo and/or campus photo banner.
   - Prominent blue banner title: "CERTIFICATE OF REGISTRATION".
2. Enrollment & Student Details Block:
   - Structured metadata fields including: Enrollment No., Student No./ID, Enrollment Date, Curriculum, School Year, Year Level, Student Type, Student Name, Course, Department, Scholarship/Grant.
3. Class Schedule Table (hasScheduleTable):
   - Dedicated table with header "CLASS SCHEDULE".
   - Standard columns: SCHEDULE, SUBJECT NAME, SUBJECT DESCRIPTION, SECTION, UNITS, ROOM, DAYS, TIME, PAY UNITS.
   - Table summary row showing TOTAL units.
4. Official Certification Statement (hasCertification):
   - Explicit institutional enrollment certification text: "This is to certify that the student whose name appears on this document is officially enrolled this term with subject load listed above."
5. Official Signatures (hasRegistrarSignature):
   - Underlined signature sections for "STUDENT SIGNATURE" and "REGISTRAR" (with Registrar name/office title).
6. Notice & Metadata:
   - "Notice to all Students :" / "Present this certificate of registration..." and bottom print timestamp metadata.

Verification & Verdict Rules:
- "isOfficialCOR": Set to true ONLY if the image possesses the layout and structural components of an authentic NEMSU COR. Set to false if it is arbitrary text, a blank canvas with typed letters, an ID card, a diploma, a syllabus, a screenshot of a form, or a fabricated mock document.
- Student ID & Name Matching:
  * Extract printed Student ID and Full Name using case-insensitive comparison, allowing minor whitespace or middle initial differences.
- Academic Term Matching & Outdated COR Detection:
  * Extract the printed School Year (e.g. "2025-2026 / 2ND SEMESTER", "2026-2027 1ST SEM") and normalize semester ("1st Sem", "1st Semester", "First Semester", "Sem 1" -> "1st Semester").
  * If the document is from an older academic year or a different semester than $targetAcademicYear $targetSemester:
    - Set "termMatched": false and "isOutdated": true.
- Final Verdict & Reason:
  * If "isOfficialCOR" is FALSE (e.g. mock/fake image, arbitrary text, non-COR image):
    - "verdict": "REJECTED"
    - "reason": "Rejected: Uploaded image is not an official NEMSU Certificate of Registration."
  * If "isOfficialCOR" is TRUE, but "isOutdated" is TRUE ${enforceTerm ? '(and term enforcement is active)' : ''}:
    - "verdict": "REJECTED"
    - "reason": "Rejected: The uploaded Certificate of Registration is outdated."
  * If "isOfficialCOR" is TRUE, Student ID matches, Full Name matches, and the document is for the active term ($targetAcademicYear $targetSemester):
    - "verdict": "VERIFIED"
    - "reason": "Official NEMSU COR verified. Student ID and Name match registered information."
  * If "isOfficialCOR" is TRUE, but the image is blurry, low-resolution, or cropped such that text cannot be confidently verified:
    - "verdict": "PENDING"
    - "reason": "Document requires manual verification by COMSELEC admin."
  * If "isOfficialCOR" is TRUE, but the Student ID or Name clearly does not match the registered user:
    - "verdict": "REJECTED"
    - "reason": "Rejected: Student information on COR does not match registration details."

Respond ONLY with a valid JSON object matching the exact schema below, without markdown blocks or extra text:
{
  "isCOR": true,
  "isOfficialCOR": true,
  "hasNemsuHeader": true,
  "hasScheduleTable": true,
  "hasCertification": true,
  "hasRegistrarSignature": true,
  "detectedStudentId": "string",
  "detectedFullName": "string",
  "detectedDepartment": "string",
  "detectedCourse": "string",
  "academicYear": "string",
  "semester": "string",
  "confidence": 0.95,
  "idMatched": true,
  "nameMatched": true,
  "termMatched": true,
  "isOutdated": false,
  "verdict": "VERIFIED",
  "reason": "Official NEMSU COR verified. Student ID and Name match registered information."
}
''';

      final requestBody = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': effectiveMimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      });

      List<String> candidateModels = [
        activeModel,
        'gemini-flash-lite-latest',
        'gemini-2.5-flash',
        'gemini-1.5-flash-8b',
        'gemini-2.0-flash-lite',
        'gemini-1.5-flash',
        'gemini-2.0-flash',
        'gemini-3.8-flash',
        'gemini-2.5-pro',
        'gemini-1.5-pro',
      ];
      // Remove duplicates while preserving priority
      candidateModels = candidateModels.toSet().toList();

      String lastServerError = '';

      for (String currentModel in candidateModels) {
        try {
          final url = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$currentModel:generateContent?key=$apiKey');

          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          ).timeout(const Duration(seconds: 25));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                String rawText = parts[0]['text'] ?? '{}';

                // Clean markdown fences if present
                rawText = rawText.replaceAll(
                    RegExp(r'^```json\s*', multiLine: true), '');
                rawText =
                    rawText.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
                rawText = rawText.trim();

                final jsonResult = jsonDecode(rawText) as Map<String, dynamic>;

                // Auto-save working model if different from previous
                if (currentModel != activeModel) {
                  saveApiKey(apiKey, modelName: currentModel).ignore();
                }

                return OCRScanResult.fromMap(jsonResult);
              }
            }
          }

          // Check if retryable error (high demand, overload, quota, not found, or bad request)
          bool isRetryable = response.statusCode == 404 ||
              response.statusCode == 400 ||
              response.statusCode == 429 ||
              response.statusCode == 503 ||
              response.statusCode == 500;

          String serverErrorMsg =
              'AI Server returned status ${response.statusCode}.';
          try {
            final errJson = jsonDecode(response.body);
            if (errJson is Map<String, dynamic> &&
                errJson['error'] is Map<String, dynamic>) {
              serverErrorMsg = errJson['error']['message'] ?? serverErrorMsg;
              final lower = serverErrorMsg.toLowerCase();
              if (lower.contains('demand') ||
                  lower.contains('overload') ||
                  lower.contains('quota') ||
                  lower.contains('exhausted') ||
                  lower.contains('unavailable')) {
                isRetryable = true;
              }
            }
          } catch (_) {}

          if (isRetryable) {
            lastServerError = 'Model $currentModel: $serverErrorMsg';
            continue; // Seamlessly try next candidate model!
          }

          return OCRScanResult.fallbackPending(
            reason: '$serverErrorMsg Document queued for Admin review.',
          );
        } catch (e) {
          lastServerError = '$e';
          // Continue to next candidate
        }
      }

      return OCRScanResult.fallbackPending(
        reason:
            'AI OCR scan could not reach a supported model ($lastServerError). Document queued for Admin review.',
      );
    } catch (e) {
      return OCRScanResult.fallbackPending(
        reason:
            'AI OCR scan encountered a connection notice ($e). Document queued for Admin manual review.',
      );
    }
  }

  String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        return 'application/pdf';
      }
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        return 'image/png';
      }
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return 'image/jpeg';
      }
    }
    return 'image/jpeg';
  }
}
