abstract class FeedbackStatusState {
  bool canChangeTo(String newStatus);
}

// ============================================================
// PENDING
// ============================================================

class PendingState implements FeedbackStatusState {
  @override
  bool canChangeTo(String newStatus) {
    return newStatus == 'APPROVED' ||
        newStatus == 'RESOLVED' ||
        newStatus == 'REJECTED';
  }
}

// ============================================================
// APPROVED
// ============================================================

class ApprovedState implements FeedbackStatusState {
  @override
  bool canChangeTo(String newStatus) {
    return newStatus == 'RESOLVED' ||
        newStatus == 'REJECTED' ||
        newStatus == 'FORWARDING';
  }
}

// ============================================================
// FINAL
// ============================================================

class FinalState implements FeedbackStatusState {
  @override
  bool canChangeTo(String newStatus) {
    return false;
  }
}

// ============================================================
// CONTEXT
// ============================================================

class FeedbackStatusContext {
  FeedbackStatusState getState(
    String? currentStatus,
  ) {
    switch (currentStatus) {
      case 'PENDING':
        return PendingState();

      case 'APPROVED':
        return ApprovedState();

      case 'RESOLVED':
      case 'REJECTED':
        return FinalState();

      default:
        return FinalState();
    }
  }

  bool canChange(
    String? currentStatus,
    String newStatus,
  ) {
    return getState(currentStatus)
        .canChangeTo(newStatus);
  }
}