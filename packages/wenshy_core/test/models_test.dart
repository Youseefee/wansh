import 'package:flutter_test/flutter_test.dart';
import 'package:wenshy_core/wenshy_core.dart';

void main() {
  const timestamp = '2026-11-12T18:00:00.000Z';

  group('Core models JSON serialization', () {
    test('UserProfile round-trip', () {
      final json = <String, dynamic>{
        'id': '11111111-1111-1111-1111-111111111111',
        'role': 'customer',
        'full_name': 'أحمد محمد',
        'phone': '+201001234567',
        'email': 'ahmed@example.com',
        'avatar_url': null,
        'is_active': true,
        'fcm_token': 'fcm-123',
        'locale': 'ar',
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final profile = UserProfile.fromJson(json);
      expect(profile.role, AppRole.customer);
      expect(profile.isArabic, isTrue);
      expect(UserProfile.fromJson(profile.toJson()), profile);
    });

    test('CustomerVehicle round-trip and insert payload', () {
      final json = <String, dynamic>{
        'id': '22222222-2222-2222-2222-222222222222',
        'customer_id': '11111111-1111-1111-1111-111111111111',
        'make': 'Hyundai',
        'model': 'Elantra',
        'year': 2021,
        'color': 'Silver',
        'plate_number': 'س ص ع 1234',
        'vehicle_category': 'luxury_low_clearance',
        'notes': 'Front bumper is low',
        'is_default': true,
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final vehicle = CustomerVehicle.fromJson(json);
      expect(vehicle.vehicleCategory, VehicleCategory.luxuryLowClearance);
      expect(vehicle.displayLabel, 'Hyundai Elantra (2021)');
      expect(CustomerVehicle.fromJson(vehicle.toJson()), vehicle);

      final insert = vehicle.toInsertJson();
      expect(insert.containsKey('id'), isFalse);
      expect(insert['vehicle_category'], 'luxury_low_clearance');
    });

    test('WinchType handles numeric strings and localized names', () {
      final json = <String, dynamic>{
        'id': '33333333-3333-3333-3333-333333333333',
        'code': 'flatbed',
        'name_ar': 'ونش سطحة',
        'name_en': 'Flatbed Tow Truck',
        'description_ar': 'سطحة مسطحة كاملة',
        'description_en': 'Full flatbed carrier',
        'base_fare': '300.00',
        'price_per_km': 22,
        'minimum_fare': 450.0,
        'road_factor': '1.25',
        'surge_multiplier': '1.00',
        'max_weight_tons': '4.50',
        'icon_name': 'tow_flatbed',
        'sort_order': 1,
        'is_active': true,
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final winchType = WinchType.fromJson(json);
      expect(winchType.baseFare, 300.0);
      expect(winchType.pricePerKm, 22.0);
      expect(winchType.maxWeightTons, 4.5);
      expect(winchType.localizedName('ar'), 'ونش سطحة');
      expect(winchType.localizedName('en'), 'Flatbed Tow Truck');
      expect(WinchType.fromJson(winchType.toJson()), winchType);
    });

    test('WinchQuote parses calculate_winch_quote RPC JSONB', () {
      final json = <String, dynamic>{
        'winch_type_id': '33333333-3333-3333-3333-333333333333',
        'winch_code': 'hydraulic',
        'winch_name_ar': 'ونش هيدروليك (منزلق)',
        'winch_name_en': 'Hydraulic Slide-Bed',
        'geodesic_distance_km': 10.4,
        'estimated_distance_km': 13.0,
        'estimated_duration_min': 23,
        'base_fare': 400.0,
        'price_per_km': 28.0,
        'minimum_fare': 600.0,
        'surge_multiplier': 1.0,
        'estimated_price': 764.0,
        'min_price_range': 725.8,
        'max_price_range': 840.4,
        'currency': 'EGP',
      };
      final quote = WinchQuote.fromJson(json);
      expect(quote.estimatedPrice, 764.0);
      expect(quote.estimatedDurationMin, 23);
      expect(WinchQuote.fromJson(quote.toJson()), quote);
    });

    test('NearbyDriver parses find_nearest_drivers RPC row', () {
      final json = <String, dynamic>{
        'driver_id': '44444444-4444-4444-4444-444444444444',
        'winch_id': '55555555-5555-5555-5555-555555555555',
        'full_name': 'خالد علي',
        'avatar_url': null,
        'avg_rating': '4.85',
        'total_trips': 42,
        'winch_brand': 'Isuzu',
        'winch_model': 'NPR',
        'plate_number': 'أ ب ج 999',
        'current_lat': 30.0444,
        'current_lng': 31.2357,
        'distance_meters': 1250,
        'eta_minutes': 4,
      };
      final driver = NearbyDriver.fromJson(json);
      expect(driver.avgRating, 4.85);
      expect(driver.distanceMeters, 1250);
      expect(NearbyDriver.fromJson(driver.toJson()), driver);
    });

    test('DriverProfile, DriverWinch, and DriverDocument round-trip', () {
      final driverJson = <String, dynamic>{
        'id': '44444444-4444-4444-4444-444444444444',
        'national_id_number': '29001011234567',
        'license_number': 'DL-9988',
        'license_expiry': '2028-05-01',
        'approval_status': 'under_review',
        'rejection_reason': null,
        'reviewed_by': null,
        'reviewed_at': null,
        'is_online': false,
        'is_available': true,
        'current_lat': 30.05,
        'current_lng': 31.24,
        'current_heading': 180.5,
        'current_speed_kmh': 0.0,
        'last_location_at': timestamp,
        'avg_rating': '4.90',
        'total_ratings': 15,
        'total_trips': 20,
        'total_earnings': '12500.50',
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final driver = DriverProfile.fromJson(driverJson);
      expect(driver.approvalStatus, DriverApprovalStatus.underReview);
      expect(driver.totalEarnings, 12500.5);
      expect(DriverProfile.fromJson(driver.toJson()), driver);

      final winchJson = <String, dynamic>{
        'id': '55555555-5555-5555-5555-555555555555',
        'driver_id': '44444444-4444-4444-4444-444444444444',
        'winch_type_id': '33333333-3333-3333-3333-333333333333',
        'plate_number': 'أ ب ج 999',
        'brand': 'Isuzu',
        'model': 'NPR',
        'year': 2020,
        'color': 'White',
        'max_capacity_tons': 5.0,
        'winch_license_number': 'WL-112',
        'winch_license_expiry': '2027-06-30',
        'photo_paths': ['44444444-4444-4444-4444-444444444444/front.jpg'],
        'is_verified': true,
        'is_active': true,
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final winch = DriverWinch.fromJson(winchJson);
      expect(winch.photoPaths, hasLength(1));
      expect(DriverWinch.fromJson(winch.toJson()), winch);

      final docJson = <String, dynamic>{
        'id': '66666666-6666-6666-6666-666666666666',
        'driver_id': '44444444-4444-4444-4444-444444444444',
        'winch_id': '55555555-5555-5555-5555-555555555555',
        'document_type': 'criminal_record',
        'storage_path':
            '44444444-4444-4444-4444-444444444444/criminal_record/doc.pdf',
        'review_status': 'approved',
        'rejection_reason': null,
        'reviewed_by': '99999999-9999-9999-9999-999999999999',
        'reviewed_at': timestamp,
        'expires_at': '2027-01-01',
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final doc = DriverDocument.fromJson(docJson);
      expect(doc.documentType, DocumentType.criminalRecord);
      expect(doc.reviewStatus, DocumentReviewStatus.approved);
      expect(DriverDocument.fromJson(doc.toJson()), doc);
    });

    test('RescueRequest, DispatchOffer, TripStatusLog, TripRating, Complaint round-trip', () {
      final requestJson = <String, dynamic>{
        'id': '77777777-7777-7777-7777-777777777777',
        'request_code': 'WN-100001',
        'customer_id': '11111111-1111-1111-1111-111111111111',
        'driver_id': '44444444-4444-4444-4444-444444444444',
        'winch_type_id': '33333333-3333-3333-3333-333333333333',
        'winch_id': '55555555-5555-5555-5555-555555555555',
        'customer_vehicle_id': '22222222-2222-2222-2222-222222222222',
        'vehicle_make': 'Hyundai',
        'vehicle_model': 'Elantra',
        'vehicle_year': 2021,
        'vehicle_color': 'Silver',
        'vehicle_plate': 'س ص ع 1234',
        'vehicle_category': 'sedan',
        'breakdown_reason': 'Engine stall',
        'breakdown_notes': 'Beside Cairo Ring Road exit',
        'breakdown_photo_paths': ['1111/7777/photo1.jpg'],
        'pickup_lat': 30.0444,
        'pickup_lng': 31.2357,
        'pickup_address': 'وسط البلد، القاهرة',
        'dropoff_lat': 30.0875,
        'dropoff_lng': 31.3292,
        'dropoff_address': 'مصر الجديدة، القاهرة',
        'geodesic_distance_km': 10.2,
        'estimated_distance_km': 12.75,
        'estimated_duration_min': 22,
        'base_fare_snapshot': 300.0,
        'price_per_km_snapshot': 22.0,
        'estimated_price': 580.5,
        'final_price': null,
        'currency': 'EGP',
        'payment_method': 'cash',
        'payment_status': 'pending',
        'status': 'en_route_to_pickup',
        'current_wave': 1,
        'cancellation_reason': null,
        'cancelled_by': null,
        'accepted_at': timestamp,
        'en_route_at': timestamp,
        'arrived_at': null,
        'loaded_at': null,
        'dropoff_started_at': null,
        'completed_at': null,
        'cancelled_at': null,
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final request = RescueRequest.fromJson(requestJson);
      expect(request.status, TripStatus.enRouteToPickup);
      expect(request.displayPrice, 580.5);
      expect(request.vehicleSummary, 'Hyundai Elantra (2021)');
      expect(RescueRequest.fromJson(request.toJson()), request);

      final offerJson = <String, dynamic>{
        'id': '88888888-8888-8888-8888-888888888888',
        'request_id': request.id,
        'driver_id': '44444444-4444-4444-4444-444444444444',
        'winch_id': '55555555-5555-5555-5555-555555555555',
        'distance_meters': 950,
        'eta_minutes': 3,
        'wave_number': 1,
        'status': 'pending',
        'rejection_reason': null,
        'expires_at': '2026-11-12T18:00:45.000Z',
        'responded_at': null,
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final offer = DispatchOffer.fromJson(offerJson);
      expect(
        offer.remainingTime(DateTime.utc(2026, 11, 12, 18, 0, 15)),
        const Duration(seconds: 30),
      );
      expect(
        offer.isExpiredAt(DateTime.utc(2026, 11, 12, 18, 1, 0)),
        isTrue,
      );
      expect(DispatchOffer.fromJson(offer.toJson()), offer);

      final logJson = <String, dynamic>{
        'id': 42,
        'request_id': request.id,
        'from_status': 'driver_assigned',
        'to_status': 'en_route_to_pickup',
        'changed_by': '44444444-4444-4444-4444-444444444444',
        'lat': 30.045,
        'lng': 31.236,
        'notes': 'Started moving',
        'created_at': timestamp,
      };
      final log = TripStatusLog.fromJson(logJson);
      expect(log.fromStatus, TripStatus.driverAssigned);
      expect(log.toStatus, TripStatus.enRouteToPickup);
      expect(TripStatusLog.fromJson(log.toJson()), log);

      final ratingJson = <String, dynamic>{
        'id': '99999999-9999-9999-9999-999999999999',
        'request_id': request.id,
        'customer_id': request.customerId,
        'driver_id': request.driverId,
        'score': 5,
        'comment': 'سريع ومحترم',
        'tags': ['fast', 'polite'],
        'created_at': timestamp,
      };
      final rating = TripRating.fromJson(ratingJson);
      expect(rating.score, 5);
      expect(TripRating.fromJson(rating.toJson()), rating);

      final complaintJson = <String, dynamic>{
        'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'complaint_code': 'CMP-100001',
        'request_id': request.id,
        'reporter_id': request.customerId,
        'reported_user_id': request.driverId,
        'category': 'delay',
        'subject': 'تأخر الوصول',
        'description': 'تأخر السائق 25 دقيقة عن الوقت المحدد',
        'evidence_paths': ['1111/evidence.png'],
        'status': 'in_progress',
        'admin_notes': 'Checking timeline',
        'resolved_by': null,
        'resolved_at': null,
        'created_at': timestamp,
        'updated_at': timestamp,
      };
      final complaint = Complaint.fromJson(complaintJson);
      expect(complaint.category, ComplaintCategory.delay);
      expect(complaint.status, ComplaintStatus.inProgress);
      expect(Complaint.fromJson(complaint.toJson()), complaint);
    });

    test('CreateRescueRequestResult & TripLocationPoint parse cleanly', () {
      final composite = CreateRescueRequestResult.fromJson(<String, dynamic>{
        'request': <String, dynamic>{
          'id': '77777777-7777-7777-7777-777777777777',
          'request_code': 'WN-100002',
          'customer_id': '11111111-1111-1111-1111-111111111111',
          'winch_type_id': '33333333-3333-3333-3333-333333333333',
          'pickup_lat': 30.0,
          'pickup_lng': 31.2,
          'pickup_address': 'Pickup',
          'dropoff_lat': 30.1,
          'dropoff_lng': 31.3,
          'dropoff_address': 'Dropoff',
          'geodesic_distance_km': 14.5,
          'estimated_distance_km': 18.1,
          'base_fare_snapshot': 300,
          'price_per_km_snapshot': 22,
          'estimated_price': 698.2,
          'created_at': timestamp,
          'updated_at': timestamp,
        },
        'quote': <String, dynamic>{
          'winch_type_id': '33333333-3333-3333-3333-333333333333',
          'winch_code': 'flatbed',
          'winch_name_ar': 'ونش سطحة',
          'winch_name_en': 'Flatbed Tow Truck',
          'geodesic_distance_km': 14.5,
          'estimated_distance_km': 18.1,
          'estimated_duration_min': 31,
          'base_fare': 300,
          'price_per_km': 22,
          'minimum_fare': 450,
          'surge_multiplier': 1.0,
          'estimated_price': 698.2,
          'min_price_range': 663.29,
          'max_price_range': 768.02,
          'currency': 'EGP',
        },
        'dispatch': <String, dynamic>{
          'request_id': '77777777-7777-7777-7777-777777777777',
          'wave_number': 1,
          'radius_meters': 15000,
          'dispatched_count': 3,
          'expires_at': '2026-11-12T18:00:45.000Z',
        },
      });
      expect(composite.request.requestCode, 'WN-100002');
      expect(composite.quote.estimatedPrice, 698.2);
      expect(composite.dispatch.dispatchedCount, 3);

      final point = TripLocationPoint.fromJson(const <String, dynamic>{
        'lat': 30.0444,
        'lng': 31.2357,
        'heading': 90,
        'speed': 42.5,
      });
      expect(point.speedKmh, 42.5);
      expect(point.toBroadcastJson()['speed_kmh'], 42.5);
    });
  });
}
