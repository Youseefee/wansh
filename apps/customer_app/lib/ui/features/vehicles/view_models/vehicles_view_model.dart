import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/vehicle_repository.dart';
import '../../../core/error_formatter.dart';

/// ViewModel for CRUD management of saved customer vehicles
/// (`public.customer_vehicles`).
class VehiclesViewModel extends ChangeNotifier {
  VehiclesViewModel({required this._repository});

  final VehicleRepository _repository;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<CustomerVehicle> _vehicles = const <CustomerVehicle>[];

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<CustomerVehicle> get vehicles => _vehicles;

  Future<void> loadVehicles(String customerId, {String locale = 'ar'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehicles = await _repository.fetchVehicles(customerId);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveVehicle({
    String? editingId,
    required String customerId,
    required String make,
    required String model,
    int? year,
    String? color,
    required String plateNumber,
    required VehicleCategory category,
    String? notes,
    bool isDefault = false,
    String locale = 'ar',
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (editingId == null) {
        await _repository.createVehicle(
          customerId: customerId,
          make: make,
          model: model,
          year: year,
          color: color,
          plateNumber: plateNumber,
          category: category,
          notes: notes,
          isDefault: isDefault,
        );
      } else {
        await _repository.updateVehicle(
          vehicleId: editingId,
          customerId: customerId,
          make: make,
          model: model,
          year: year,
          color: color,
          plateNumber: plateNumber,
          category: category,
          notes: notes,
          isDefault: isDefault,
        );
      }
      _vehicles = await _repository.fetchVehicles(customerId);
      return true;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> setDefault({
    required String customerId,
    required String vehicleId,
    String locale = 'ar',
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.setDefaultVehicle(
        customerId: customerId,
        vehicleId: vehicleId,
      );
      _vehicles = await _repository.fetchVehicles(customerId);
      return true;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteVehicle({
    required String customerId,
    required String vehicleId,
    String locale = 'ar',
  }) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteVehicle(vehicleId);
      _vehicles = await _repository.fetchVehicles(customerId);
      return true;
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
