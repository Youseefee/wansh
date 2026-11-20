import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';

void main() {
  group('Config, StorageBuckets, and RealtimeTopics', () {
    test('Storage bucket constants & path builders match RLS policies', () {
      expect(StorageBuckets.driverDocuments, 'driver-documents');
      expect(StorageBuckets.winchPhotos, 'winch-photos');
      expect(StorageBuckets.breakdownPhotos, 'breakdown-photos');
      expect(StorageBuckets.complaintEvidence, 'complaint-evidence');

      expect(
        StorageBuckets.driverDocumentPath(
          driverId: 'drv-1',
          documentType: DocumentType.nationalIdFront,
          fileName: 'id.jpg',
        ),
        'drv-1/national_id_front/id.jpg',
      );
      expect(
        StorageBuckets.winchPhotoPath(driverId: 'drv-1', fileName: 'truck.jpg'),
        'drv-1/truck.jpg',
      );
      expect(
        StorageBuckets.breakdownPhotoPath(
          customerId: 'cust-1',
          requestId: 'req-1',
          fileName: 'car.jpg',
        ),
        'cust-1/req-1/car.jpg',
      );
      expect(
        StorageBuckets.complaintEvidencePath(
          reporterId: 'usr-1',
          fileName: 'proof.pdf',
        ),
        'usr-1/proof.pdf',
      );
    });

    test('Realtime topic builders and private config match Migration 003', () {
      expect(RealtimeTopics.trip('abc-123'), 'trip:abc-123');
      expect(RealtimeTopics.driver('drv-456'), 'driver:drv-456');
      expect(RealtimeTopics.fleetOnline, 'fleet:online');
      expect(RealtimeTopics.privateChannelConfig.private, isTrue);
    });

    test('SQL table and RPC constants match Migrations 002 & 004', () {
      expect(WenshyTables.rescueRequests, 'rescue_requests');
      expect(WenshyTables.dispatchOffers, 'dispatch_offers');
      expect(WenshyTables.driverWinches, 'driver_winches');
      expect(WenshyTables.deviceTokens, 'device_tokens');
      expect(WenshyTables.notifications, 'notifications');
      expect(WenshyRpcs.calculateWinchQuote, 'calculate_winch_quote');
      expect(WenshyRpcs.createRescueRequest, 'create_rescue_request');
      expect(WenshyRpcs.acceptRescueOffer, 'accept_rescue_offer');
      expect(WenshyRpcs.driverUpdateTripStage, 'driver_update_trip_stage');
      expect(WenshyRpcs.driverUpdateLocation, 'driver_update_location');
      expect(WenshyRpcs.deleteMyAccount, 'delete_my_account');
    });

    test('SupabaseConfig throws StateError if unconfigured at runtime', () {
      expect(
        () => SupabaseConfig.initialize(urlOverride: '', anonKeyOverride: ''),
        throwsStateError,
      );
    });
  });

  group('WenshyLabels Arabic & English coverage', () {
    test('provides non-empty Arabic and English labels for every enum value', () {
      for (final v in AppRole.values) {
        expect(WenshyLabels.appRole(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.appRole(v, locale: 'en'), isNotEmpty);
      }
      for (final v in DriverApprovalStatus.values) {
        expect(WenshyLabels.driverApprovalStatus(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.driverApprovalStatus(v, locale: 'en'), isNotEmpty);
        expect(
          WenshyLabels.driverApprovalDescription(v, locale: 'ar'),
          isNotEmpty,
        );
        expect(
          WenshyLabels.driverApprovalDescription(v, locale: 'en'),
          isNotEmpty,
        );
      }
      for (final v in TripStatus.values) {
        expect(WenshyLabels.tripStatus(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.tripStatus(v, locale: 'en'), isNotEmpty);
        expect(WenshyLabels.tripStatusShort(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.tripStatusShort(v, locale: 'en'), isNotEmpty);
        expect(WenshyLabels.tripStageAction(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.tripStageAction(v, locale: 'en'), isNotEmpty);
      }
      for (final v in OfferStatus.values) {
        expect(WenshyLabels.offerStatus(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.offerStatus(v, locale: 'en'), isNotEmpty);
      }
      for (final v in DocumentType.values) {
        expect(WenshyLabels.documentType(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.documentType(v, locale: 'en'), isNotEmpty);
      }
      for (final v in DocumentReviewStatus.values) {
        expect(WenshyLabels.documentReviewStatus(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.documentReviewStatus(v, locale: 'en'), isNotEmpty);
      }
      for (final v in VehicleCategory.values) {
        expect(WenshyLabels.vehicleCategory(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.vehicleCategory(v, locale: 'en'), isNotEmpty);
      }
      for (final v in PaymentMethod.values) {
        expect(WenshyLabels.paymentMethod(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.paymentMethod(v, locale: 'en'), isNotEmpty);
      }
      for (final v in PaymentStatus.values) {
        expect(WenshyLabels.paymentStatus(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.paymentStatus(v, locale: 'en'), isNotEmpty);
      }
      for (final v in ComplaintCategory.values) {
        expect(WenshyLabels.complaintCategory(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.complaintCategory(v, locale: 'en'), isNotEmpty);
      }
      for (final v in ComplaintStatus.values) {
        expect(WenshyLabels.complaintStatus(v, locale: 'ar'), isNotEmpty);
        expect(WenshyLabels.complaintStatus(v, locale: 'en'), isNotEmpty);
      }
    });

    test('formatting helpers format price, distance, and ETA', () {
      expect(WenshyLabels.formatPrice(1250.5, locale: 'ar'), '1,250.5 ج.م');
      expect(WenshyLabels.formatPrice(1250.5, locale: 'en'), '1,250.5 EGP');
      expect(WenshyLabels.formatDistanceKm(14.25, locale: 'ar'), '14.25 كم');
      expect(WenshyLabels.formatDistanceKm(14.25, locale: 'en'), '14.25 km');
      expect(WenshyLabels.formatDistanceMeters(850, locale: 'ar'), '850 م');
      expect(WenshyLabels.formatDistanceMeters(1500, locale: 'en'), '1.5 km');
      expect(WenshyLabels.formatEtaMinutes(12, locale: 'ar'), '12 دقيقة');
      expect(WenshyLabels.formatEtaMinutes(12, locale: 'en'), '12 min');
      expect(WenshyLabels.appName(locale: 'ar'), 'ونشي');
      expect(WenshyLabels.appName(locale: 'en'), 'Wenshy');
      expect(WenshyLabels.appTagline(locale: 'ar'), isNotEmpty);
      expect(WenshyLabels.appTagline(locale: 'en'), isNotEmpty);

      final now = DateTime.utc(2026, 11, 20, 15, 0);
      expect(
        WenshyLabels.formatRelativeTime(
          DateTime.utc(2026, 11, 20, 14, 59, 45),
          now: now,
          locale: 'ar',
        ),
        'الآن',
      );
      expect(
        WenshyLabels.formatRelativeTime(
          DateTime.utc(2026, 11, 20, 14, 55),
          now: now,
          locale: 'en',
        ),
        '5m ago',
      );
      expect(
        WenshyLabels.formatRelativeTime(
          DateTime.utc(2026, 11, 20, 12, 0),
          now: now,
          locale: 'ar',
        ),
        'منذ 3 ساعة',
      );
    });
  });
}
