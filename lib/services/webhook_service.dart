import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebhookService {
  static const String _webhookUrl =
      'https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/updateCallStatus';

  Future<bool> updateCallStatus({
    required String callId,
    required String status,
  }) async {
    final isPlaceholder =
        _webhookUrl.contains('YOUR_REGION') ||
        _webhookUrl.contains('YOUR_PROJECT') ||
        _webhookUrl.isEmpty;

    if (isPlaceholder) {
      debugPrint(
        '!! [WebhookService] Incomplete URL detected (${_webhookUrl}). Entering MOCK MODE !!',
      );
      try {
        await Future.delayed(const Duration(milliseconds: 500));

        await FirebaseFirestore.instance.collection('calls').doc(callId).update(
          {'status': status},
        );

        debugPrint(
          '!! [WebhookService] Mock status update successful: $callId -> $status !!',
        );
        return true;
      } catch (e) {
        debugPrint('!! [WebhookService] Mock update failed for $callId: $e !!');
        return false;
      }
    }

    try {
      debugPrint(
        'Calling Cloud Function to update call status: $callId -> $status',
      );

      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'callId': callId, 'status': status}),
      );

      if (response.statusCode == 200) {
        debugPrint('Cloud Function update successful');
        return true;
      } else {
        debugPrint('Cloud Function failed with status: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error calling Cloud Function: $e');
      return false;
    }
  }

  Future<void> triggerCallEvent({
    required String callId,
    required String event,
    Map<String, dynamic>? data,
  }) async {
    debugPrint('Webhook event triggered: $event for $callId');
  }
}
