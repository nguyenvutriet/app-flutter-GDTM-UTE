class VoteCommentId {
  String? userId;
  String? commentId;

  VoteCommentId({
    this.userId,
    this.commentId,
  });

  factory VoteCommentId.fromJson(Map<String, dynamic> json) {
    return VoteCommentId(
      userId: json['userId'],
      commentId: json['commentId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'commentId': commentId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VoteCommentId &&
        other.userId == userId &&
        other.commentId == commentId;
  }

  @override
  int get hashCode => Object.hash(userId, commentId);
}