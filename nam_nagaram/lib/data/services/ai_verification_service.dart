import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AiVerificationService {
  // Defaults to a localhost URL but will automatically update from Firestore
  final String _baseUrl = 'https://municipal-assets.onrender.com';

  AiVerificationService() {
    // _initializeDynamicUrl();
  }

  /*
  Future<void> _initializeDynamicUrl() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('backend_config').get();
      if (doc.exists && doc.data() != null && doc.data()!['url'] != null) {
        _baseUrl = doc.data()!['url'];
        debugPrint('Dynamically set AI Backend URL to: $_baseUrl');
      }
    } catch (e) {
      debugPrint('Failed to fetch dynamic backend URL, using fallback: $_baseUrl');
    }
  }
  */

  Future<Map<String, dynamic>> verifyAssetImage(File imageFile, String asset, String problem, {String? latitude, String? longitude, String? address}) async {
    try {
      var uri = Uri.parse('$_baseUrl/verify-image');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Bypass-Tunnel-Reminder'] = 'true';
      
      request.fields['asset'] = asset;
      request.fields['problem'] = problem;
      if (latitude != null) request.fields['latitude'] = latitude;
      if (longitude != null) request.fields['longitude'] = longitude;
      if (address != null) request.fields['address'] = address;
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        return {
          'valid': false,
          'message': 'Failed to connect to AI Verification Service (Status Code: ${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'valid': false,
        'message': 'Error connecting to AI Verification Service: $e',
      };
    }
  }

  Future<Map<String, dynamic>> verifyResolutionImage(File imageFile, String asset, {String? latitude, String? longitude, String? address}) async {
    try {
      var uri = Uri.parse('$_baseUrl/verify-resolution');
      var request = http.MultipartRequest('POST', uri);
      
      request.fields['asset'] = asset;
      if (latitude != null) request.fields['latitude'] = latitude;
      if (longitude != null) request.fields['longitude'] = longitude;
      if (address != null) request.fields['address'] = address;
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        return {
          'valid': false,
          'message': 'Failed to connect to AI Verification Service (Status Code: ${response.statusCode})',
        };
      }
    } catch (e) {
      return {
        'valid': false,
        'message': 'Error connecting to AI Verification Service: $e',
      };
    }
  }
}

// Global instance for simple access
final aiVerificationService = AiVerificationService();
