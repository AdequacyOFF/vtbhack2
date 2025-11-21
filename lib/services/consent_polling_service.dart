import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Service to automatically poll consent statuses for pending consents
/// This solves the issue where banks require manual approval and we need to detect when they're approved
class ConsentPollingService {
  final AuthService authService;
  Timer? _pollingTimer;
  bool _isPolling = false;
  int _pollCount = 0;
  static const int maxPollAttempts = 120; // 120 * 10s = 20 minutes max
  static const Duration pollInterval = Duration(seconds: 10);

  // Callbacks for status changes
  final List<Function(String bankCode)> _onConsentApprovedCallbacks = [];
  final List<Function(List<String> pendingBanks)> _onPendingBanksChangedCallbacks = [];

  ConsentPollingService(this.authService);

  /// Register callback when a consent is approved
  void onConsentApproved(Function(String bankCode) callback) {
    _onConsentApprovedCallbacks.add(callback);
  }

  /// Register callback when pending banks list changes
  void onPendingBanksChanged(Function(List<String> pendingBanks) callback) {
    _onPendingBanksChangedCallbacks.add(callback);
  }

  /// Start polling for pending consent approvals
  void startPolling() {
    if (_isPolling) {
      debugPrint('[ConsentPolling] Already polling, skipping start');
      return;
    }

    final pendingBanks = authService.banksWithPendingConsents;
    if (pendingBanks.isEmpty) {
      debugPrint('[ConsentPolling] No pending consents, not starting polling');
      return;
    }

    debugPrint('[ConsentPolling] Starting polling for banks: $pendingBanks');
    _isPolling = true;
    _pollCount = 0;

    // Do initial check immediately
    _pollConsentStatuses();

    // Then poll periodically
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(pollInterval, (_) {
      _pollConsentStatuses();
    });
  }

  /// Stop polling
  void stopPolling() {
    if (!_isPolling) return;

    debugPrint('[ConsentPolling] Stopping polling');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _pollCount = 0;
  }

  /// Manually trigger a poll
  Future<void> pollNow() async {
    await _pollConsentStatuses();
  }

  Future<void> _pollConsentStatuses() async {
    if (!_isPolling) return;

    _pollCount++;
    debugPrint('[ConsentPolling] Poll attempt $_pollCount/$maxPollAttempts');

    try {
      // Get current pending banks before refresh
      final oldPendingBanks = Set<String>.from(authService.banksWithPendingConsents);

      if (oldPendingBanks.isEmpty) {
        debugPrint('[ConsentPolling] No pending banks, stopping polling');
        stopPolling();
        return;
      }

      // Refresh consent statuses for all pending banks (all three types)
      for (final bankCode in oldPendingBanks) {
        try {
          // Refresh account consent
          await authService.refreshAccountConsentStatus(bankCode);
        } catch (e) {
          debugPrint('[ConsentPolling] Error refreshing account consent for $bankCode: $e');
        }

        try {
          // Refresh payment consent
          await authService.refreshPaymentConsentStatus(bankCode);
        } catch (e) {
          debugPrint('[ConsentPolling] Error refreshing payment consent for $bankCode: $e');
        }

        try {
          // Refresh product consent
          await authService.refreshProductConsentStatus(bankCode);
        } catch (e) {
          debugPrint('[ConsentPolling] Error refreshing product consent for $bankCode: $e');
        }
      }

      // Check which consents were newly approved
      final newPendingBanks = Set<String>.from(authService.banksWithPendingConsents);
      final newlyApprovedBanks = oldPendingBanks.difference(newPendingBanks);

      // Notify about newly approved consents
      for (final bankCode in newlyApprovedBanks) {
        debugPrint('[ConsentPolling] ✓ Consent approved for $bankCode');
        for (final callback in _onConsentApprovedCallbacks) {
          callback(bankCode);
        }
      }

      // Notify if pending banks list changed
      if (newPendingBanks.length != oldPendingBanks.length) {
        for (final callback in _onPendingBanksChangedCallbacks) {
          callback(newPendingBanks.toList());
        }
      }

      // Stop if no more pending consents
      if (newPendingBanks.isEmpty) {
        debugPrint('[ConsentPolling] All consents approved! Stopping polling.');
        stopPolling();
        return;
      }

      // Stop if max attempts reached
      if (_pollCount >= maxPollAttempts) {
        debugPrint('[ConsentPolling] Max poll attempts reached. Stopping polling.');
        debugPrint('[ConsentPolling] Still pending: ${newPendingBanks.toList()}');
        stopPolling();
        return;
      }

      debugPrint('[ConsentPolling] Still pending: ${newPendingBanks.toList()}');
    } catch (e) {
      debugPrint('[ConsentPolling] Error during polling: $e');
      // Don't stop polling on error, just continue
    }
  }

  /// Check if currently polling
  bool get isPolling => _isPolling;

  /// Get current poll count
  int get pollCount => _pollCount;

  /// Dispose and cleanup
  void dispose() {
    stopPolling();
    _onConsentApprovedCallbacks.clear();
    _onPendingBanksChangedCallbacks.clear();
  }
}
