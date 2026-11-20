import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Repository for saved customer vehicles (`public.customer_vehicles`).
abstract class VehicleRepository {
  Future<List<CustomerVehicle>> fetchVehicles(String customerId);

  Future<CustomerVehicle> createVehicle({
    required String customerId,
    required String make,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
    required VehicleCategory category,
    String? notes,
    bool isDefault = false,
  });

  Future<CustomerVehicle> updateVehicle({
    required String vehicleId,
    required String customerId,
    required String make,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
    required VehicleCategory category,
    String? notes,
    bool isDefault = false,
  });

  Future<void> setDefaultVehicle({
    required String customerId,
    required String vehicleId,
  });

  Future<void> deleteVehicle(String vehicleId);
}

/// Supabase implementation of [VehicleRepository].
class SupabaseVehicleRepository implements VehicleRepository {
  SupabaseVehicleRepository({this._client});

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  Future<List<CustomerVehicle>> fetchVehicles(String customerId) async {
    final rows = await _supabase
        .from(WenshyTables.customerVehicles)
        .select()
        .eq('customer_id', customerId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) =>
              CustomerVehicle.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<void> _clearOtherDefaults(String customerId, {String? exceptId}) async {
    var query = _supabase
        .from(WenshyTables.customerVehicles)
        .update(<String, dynamic>{'is_default': false})
        .eq('customer_id', customerId)
        .eq('is_default', true);

    if (exceptId != null) {
      query = query.neq('id', exceptId);
    }

    await query;
  }

  @override
  Future<CustomerVehicle> createVehicle({
    required String customerId,
    required String make,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
    required VehicleCategory category,
    String? notes,
    bool isDefault = false,
  }) async {
    // Respect unique partial index `customer_vehicles_one_default_idx`.
    if (isDefault) {
      await _clearOtherDefaults(customerId);
    }

    final now = DateTime.now().toUtc();
    final draft = CustomerVehicle(
      id: '',
      customerId: customerId,
      make: make.trim(),
      model: model.trim(),
      year: year,
      color: color?.trim().isEmpty == true ? null : color?.trim(),
      plateNumber: plateNumber.trim(),
      vehicleCategory: category,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      isDefault: isDefault,
      createdAt: now,
      updatedAt: now,
    );

    final row = await _supabase
        .from(WenshyTables.customerVehicles)
        .insert(draft.toInsertJson())
        .select()
        .single();

    return CustomerVehicle.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<CustomerVehicle> updateVehicle({
    required String vehicleId,
    required String customerId,
    required String make,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
    required VehicleCategory category,
    String? notes,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      await _clearOtherDefaults(customerId, exceptId: vehicleId);
    }

    final payload = <String, dynamic>{
      'make': make.trim(),
      'model': model.trim(),
      'year': year,
      'color': color?.trim().isEmpty == true ? null : color?.trim(),
      'plate_number': plateNumber.trim(),
      'vehicle_category': category.toJson(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'is_default': isDefault,
    };

    final row = await _supabase
        .from(WenshyTables.customerVehicles)
        .update(payload)
        .eq('id', vehicleId)
        .eq('customer_id', customerId)
        .select()
        .single();

    return CustomerVehicle.fromJson(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> setDefaultVehicle({
    required String customerId,
    required String vehicleId,
  }) async {
    await _clearOtherDefaults(customerId, exceptId: vehicleId);
    await _supabase
        .from(WenshyTables.customerVehicles)
        .update(<String, dynamic>{'is_default': true})
        .eq('id', vehicleId)
        .eq('customer_id', customerId);
  }

  @override
  Future<void> deleteVehicle(String vehicleId) async {
    await _supabase
        .from(WenshyTables.customerVehicles)
        .delete()
        .eq('id', vehicleId);
  }
}
