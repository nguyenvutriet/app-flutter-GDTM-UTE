class VoteId {
  String? userId;
  String? requestId;

  VoteId({
    this.userId,
    this.requestId,
  });

  factory VoteId.fromJson(Map<String, dynamic> json) {
    return VoteId(
      userId: json['userId'],
      requestId: json['requestId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'requestId': requestId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VoteId &&
        other.userId == userId &&
        other.requestId == requestId;
  }

  @override
  int get hashCode => Object.hash(userId, requestId);
}