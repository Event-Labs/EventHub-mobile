import 'package:intl/intl.dart';

enum WaitingRoomStatus {
  loading,
  waiting,
  nearTurn,
  admitted,
  soldOut,
  expired,
  paused,
  connectionLost,
  directAccess,
}

class WaitingRoomModel {
  final bool enabled;
  final String rawStatus;
  final String? sessionId;
  final String? bookingToken;
  final int position;
  final int totalWaiting;
  final bool isNearTurn;
  final int estimatedWaitSeconds;
  final int pollIntervalMs;
  final int remainingSeconds;
  final DateTime? expiresAt;
  final String? message;
  final String? eventTitle;
  final String? eventBannerUrl;
  final String? eventThumbnailUrl;

  WaitingRoomModel({
    required this.enabled,
    required this.rawStatus,
    this.sessionId,
    this.bookingToken,
    this.position = 0,
    this.totalWaiting = 0,
    this.isNearTurn = false,
    this.estimatedWaitSeconds = 0,
    this.pollIntervalMs = 3000,
    this.remainingSeconds = 600,
    this.expiresAt,
    this.message,
    this.eventTitle,
    this.eventBannerUrl,
    this.eventThumbnailUrl,
  });

  bool get isAdmitted => rawStatus == 'ACTIVE' || rawStatus == 'ADMITTED';
  bool get isWaiting => rawStatus == 'WAITING' || rawStatus == 'QUEUED';
  bool get isSoldOut => rawStatus == 'SOLD_OUT';
  bool get isExpired => rawStatus == 'EXPIRED';
  bool get isPaused => rawStatus == 'PAUSED';
  bool get isDirectAccess => !enabled || rawStatus == 'DIRECT_ACCESS';

  WaitingRoomStatus get status {
    if (isDirectAccess) return WaitingRoomStatus.directAccess;
    if (isAdmitted) return WaitingRoomStatus.admitted;
    if (isSoldOut) return WaitingRoomStatus.soldOut;
    if (isExpired) return WaitingRoomStatus.expired;
    if (isPaused) return WaitingRoomStatus.paused;
    if (isWaiting) {
      return (isNearTurn || position <= 5)
          ? WaitingRoomStatus.nearTurn
          : WaitingRoomStatus.waiting;
    }
    return WaitingRoomStatus.waiting;
  }

  String get formattedPosition {
    return NumberFormat.decimalPattern('vi_VN').format(position);
  }

  String get formattedTotalWaiting {
    return NumberFormat.decimalPattern('vi_VN').format(totalWaiting);
  }

  int get estimatedWaitMinutes {
    if (estimatedWaitSeconds <= 0) {
      return ((position + 1) * 3 / 60).ceil();
    }
    return (estimatedWaitSeconds / 60).ceil();
  }

  static String formatCountdown(int totalSeconds) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = s ~/ 60;
    final seconds = s % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory WaitingRoomModel.fromJson(Map<String, dynamic> json) {
    // Backend may return response inside { "data": { ... } } or directly
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? Map<String, dynamic>.from(json['data'] as Map)
            : json;

    final rawStatus = data['status']?.toString().toUpperCase() ?? 'WAITING';
    final enabled = data['enabled'] != false && rawStatus != 'DIRECT_ACCESS';

    DateTime? parsedExpires;
    if (data['expires_at'] != null) {
      parsedExpires = DateTime.tryParse(data['expires_at'].toString())?.toLocal();
    }

    final eventData = (data['event'] is Map) ? Map<String, dynamic>.from(data['event'] as Map) : null;

    final pos = data['position'] != null
        ? int.tryParse(data['position'].toString()) ?? 0
        : 0;

    final total = data['total_waiting'] != null
        ? int.tryParse(data['total_waiting'].toString()) ?? (pos + 1)
        : (pos + 1);

    final nearTurn = data['is_near_turn'] == true || pos <= 5;

    return WaitingRoomModel(
      enabled: enabled,
      rawStatus: rawStatus,
      sessionId: data['session_id']?.toString() ?? data['sessionId']?.toString(),
      bookingToken: data['booking_token']?.toString() ?? data['bookingToken']?.toString(),
      position: pos,
      totalWaiting: total,
      isNearTurn: nearTurn,
      estimatedWaitSeconds: data['estimated_wait_seconds'] != null
          ? int.tryParse(data['estimated_wait_seconds'].toString()) ?? ((pos + 1) * 3)
          : ((pos + 1) * 3),
      pollIntervalMs: data['poll_interval_ms'] != null
          ? int.tryParse(data['poll_interval_ms'].toString()) ?? 3000
          : 3000,
      remainingSeconds: data['remaining_seconds'] != null
          ? int.tryParse(data['remaining_seconds'].toString()) ?? 600
          : 600,
      expiresAt: parsedExpires,
      message: data['message']?.toString(),
      eventTitle: eventData?['title']?.toString(),
      eventBannerUrl: eventData?['banner_url']?.toString(),
      eventThumbnailUrl: eventData?['thumbnail_url']?.toString(),
    );
  }

  WaitingRoomModel copyWith({
    bool? enabled,
    String? rawStatus,
    String? sessionId,
    String? bookingToken,
    int? position,
    int? totalWaiting,
    bool? isNearTurn,
    int? estimatedWaitSeconds,
    int? pollIntervalMs,
    int? remainingSeconds,
    DateTime? expiresAt,
    String? message,
    String? eventTitle,
    String? eventBannerUrl,
    String? eventThumbnailUrl,
  }) {
    return WaitingRoomModel(
      enabled: enabled ?? this.enabled,
      rawStatus: rawStatus ?? this.rawStatus,
      sessionId: sessionId ?? this.sessionId,
      bookingToken: bookingToken ?? this.bookingToken,
      position: position ?? this.position,
      totalWaiting: totalWaiting ?? this.totalWaiting,
      isNearTurn: isNearTurn ?? this.isNearTurn,
      estimatedWaitSeconds: estimatedWaitSeconds ?? this.estimatedWaitSeconds,
      pollIntervalMs: pollIntervalMs ?? this.pollIntervalMs,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      expiresAt: expiresAt ?? this.expiresAt,
      message: message ?? this.message,
      eventTitle: eventTitle ?? this.eventTitle,
      eventBannerUrl: eventBannerUrl ?? this.eventBannerUrl,
      eventThumbnailUrl: eventThumbnailUrl ?? this.eventThumbnailUrl,
    );
  }
}

