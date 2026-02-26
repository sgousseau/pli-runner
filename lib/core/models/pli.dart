import 'package:flutter/foundation.dart';

enum PliStatus { pending, pickedUp, delivered, failed }

@immutable
class Pli {
  final String id;
  final String clientNumber;
  final String address;
  final double? latitude;
  final double? longitude;
  final PliStatus status;
  final DateTime createdAt;
  final int? telegramMessageId;
  final String? photoPath;

  const Pli({
    required this.id,
    required this.clientNumber,
    required this.address,
    this.latitude,
    this.longitude,
    this.status = PliStatus.pending,
    required this.createdAt,
    this.telegramMessageId,
    this.photoPath,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  Pli copyWith({
    String? clientNumber,
    String? address,
    double? latitude,
    double? longitude,
    PliStatus? status,
    int? telegramMessageId,
    String? photoPath,
  }) {
    return Pli(
      id: id,
      clientNumber: clientNumber ?? this.clientNumber,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      createdAt: createdAt,
      telegramMessageId: telegramMessageId ?? this.telegramMessageId,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientNumber': clientNumber,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'telegramMessageId': telegramMessageId,
        'photoPath': photoPath,
      };

  factory Pli.fromJson(Map<String, dynamic> json) => Pli(
        id: json['id'] as String,
        clientNumber: json['clientNumber'] as String,
        address: json['address'] as String,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        status: PliStatus.values.byName(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        telegramMessageId: json['telegramMessageId'] as int?,
        photoPath: json['photoPath'] as String?,
      );
}
