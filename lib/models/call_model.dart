import 'package:cloud_firestore/cloud_firestore.dart';

enum CallStatus { dialling, ringing, accepted, rejected, ended }

class CallModel {
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final String channelName;
  final String callType;
  final String status;
  final String? agoraToken;
  final DateTime timestamp;

  CallModel({
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.channelName,
    required this.callType,
    required this.status,
    this.agoraToken,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'channelName': channelName,
      'callType': callType,
      'status': status,
      'agoraToken': agoraToken,
      'timestamp': timestamp,
    };
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        return DateTime.now();
      }
    }

    return CallModel(
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      channelName: map['channelName'] ?? '',
      callType: map['callType'] ?? 'audio',
      status: map['status'] ?? '',
      agoraToken: map['agoraToken'],
      timestamp: parseDateTime(map['timestamp']),
    );
  }

  CallModel copyWith({
    String? callerId,
    String? callerName,
    String? receiverId,
    String? receiverName,
    String? channelName,
    String? callType,
    String? status,
    String? agoraToken,
    DateTime? timestamp,
  }) {
    return CallModel(
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      channelName: channelName ?? this.channelName,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      agoraToken: agoraToken ?? this.agoraToken,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
