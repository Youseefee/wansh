import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';

void main() {
  group('Domain enums SQL mapping', () {
    test('AppRole maps exact SQL values', () {
      expect(AppRole.values.map((e) => e.value), [
        'customer',
        'driver',
        'admin',
      ]);
      for (final role in AppRole.values) {
        expect(AppRole.fromJson(role.value), role);
        expect(AppRole.tryFromJson(role.value), role);
        expect(role.toJson(), role.value);
      }
      expect(AppRole.tryFromJson('unknown'), isNull);
      expect(() => AppRole.fromJson('unknown'), throwsArgumentError);
    });

    test('DriverApprovalStatus maps exact SQL values', () {
      expect(DriverApprovalStatus.values.map((e) => e.value), [
        'pending',
        'under_review',
        'approved',
        'rejected',
        'suspended',
      ]);
      for (final status in DriverApprovalStatus.values) {
        expect(DriverApprovalStatus.fromJson(status.value), status);
      }
      expect(DriverApprovalStatus.approved.isApproved, isTrue);
      expect(DriverApprovalStatus.pending.isApproved, isFalse);
      expect(DriverApprovalStatus.rejected.canEditDocuments, isTrue);
      expect(DriverApprovalStatus.suspended.canEditDocuments, isFalse);
    });

    test('DocumentType maps all 8 KYC document types', () {
      expect(DocumentType.values.map((e) => e.value), [
        'national_id_front',
        'national_id_back',
        'driver_license_front',
        'driver_license_back',
        'winch_license_front',
        'winch_license_back',
        'criminal_record',
        'selfie_with_id',
      ]);
      for (final doc in DocumentType.values) {
        expect(DocumentType.fromJson(doc.value), doc);
      }
    });

    test('DocumentReviewStatus maps exact SQL values', () {
      expect(DocumentReviewStatus.values.map((e) => e.value), [
        'pending',
        'approved',
        'rejected',
      ]);
      for (final status in DocumentReviewStatus.values) {
        expect(DocumentReviewStatus.fromJson(status.value), status);
      }
    });

    test('VehicleCategory maps exact SQL values', () {
      expect(VehicleCategory.values.map((e) => e.value), [
        'sedan',
        'hatchback',
        'suv',
        'pickup',
        'van',
        'luxury_low_clearance',
        'motorcycle',
        'light_truck',
      ]);
      for (final category in VehicleCategory.values) {
        expect(VehicleCategory.fromJson(category.value), category);
      }
    });

    test('TripStatus maps exact SQL values and state machine helpers', () {
      expect(TripStatus.values.map((e) => e.value), [
        'searching',
        'driver_assigned',
        'en_route_to_pickup',
        'arrived_at_pickup',
        'vehicle_loaded',
        'en_route_to_dropoff',
        'delivered',
        'cancelled',
        'expired',
      ]);

      for (final status in TripStatus.values) {
        expect(TripStatus.fromJson(status.value), status);
      }

      expect(TripStatus.activeTimelineSteps, const [
        TripStatus.driverAssigned,
        TripStatus.enRouteToPickup,
        TripStatus.arrivedAtPickup,
        TripStatus.vehicleLoaded,
        TripStatus.enRouteToDropoff,
        TripStatus.delivered,
      ]);

      expect(TripStatus.searching.isTerminal, isFalse);
      expect(TripStatus.delivered.isTerminal, isTrue);
      expect(TripStatus.cancelled.isTerminal, isTrue);
      expect(TripStatus.expired.isTerminal, isTrue);

      expect(TripStatus.searching.isCancellable, isTrue);
      expect(TripStatus.arrivedAtPickup.isCancellable, isTrue);
      expect(TripStatus.vehicleLoaded.isCancellable, isFalse);
      expect(TripStatus.delivered.isCancellable, isFalse);

      expect(
        TripStatus.driverAssigned.nextDriverStage,
        TripStatus.enRouteToPickup,
      );
      expect(
        TripStatus.enRouteToPickup.nextDriverStage,
        TripStatus.arrivedAtPickup,
      );
      expect(
        TripStatus.arrivedAtPickup.nextDriverStage,
        TripStatus.vehicleLoaded,
      );
      expect(
        TripStatus.vehicleLoaded.nextDriverStage,
        TripStatus.enRouteToDropoff,
      );
      expect(TripStatus.enRouteToDropoff.nextDriverStage, TripStatus.delivered);
      expect(TripStatus.delivered.nextDriverStage, isNull);
    });

    test('OfferStatus, PaymentMethod, PaymentStatus, Complaint enums match SQL', () {
      expect(OfferStatus.values.map((e) => e.value), [
        'pending',
        'accepted',
        'rejected',
        'expired',
        'cancelled',
      ]);
      expect(PaymentMethod.values.map((e) => e.value), [
        'cash',
        'card',
        'wallet',
      ]);
      expect(PaymentStatus.values.map((e) => e.value), [
        'pending',
        'paid',
        'refunded',
        'failed',
      ]);
      expect(ComplaintCategory.values.map((e) => e.value), [
        'pricing',
        'driver_behavior',
        'customer_behavior',
        'vehicle_damage',
        'delay',
        'app_issue',
        'other',
      ]);
      expect(ComplaintStatus.values.map((e) => e.value), [
        'open',
        'in_progress',
        'resolved',
        'dismissed',
      ]);

      for (final e in OfferStatus.values) {
        expect(OfferStatus.fromJson(e.value), e);
      }
      for (final e in PaymentMethod.values) {
        expect(PaymentMethod.fromJson(e.value), e);
      }
      for (final e in PaymentStatus.values) {
        expect(PaymentStatus.fromJson(e.value), e);
      }
      for (final e in ComplaintCategory.values) {
        expect(ComplaintCategory.fromJson(e.value), e);
      }
      for (final e in ComplaintStatus.values) {
        expect(ComplaintStatus.fromJson(e.value), e);
      }
    });
  });
}
