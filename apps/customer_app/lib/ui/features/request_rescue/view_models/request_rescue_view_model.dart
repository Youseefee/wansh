import 'package:flutter/foundation.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../../data/repositories/map_and_quote_repository.dart';
import '../../../../data/repositories/models.dart';
import '../../../../data/repositories/rescue_request_repository.dart';
import '../../../../data/repositories/vehicle_repository.dart';
import '../../../core/error_formatter.dart';

/// ViewModel for configuring a rescue request:
/// - Selecting [WinchType]
/// - Choosing a saved [CustomerVehicle] or entering manual vehicle info
/// - Attaching breakdown photos (`breakdown-photos` bucket)
/// - Fetching live server-authoritative pricing via `calculate_winch_quote` RPC
/// - Submitting via `create_rescue_request` RPC
class RequestRescueViewModel extends ChangeNotifier {
  RequestRescueViewModel({
    required this._route,
    required this._mapRepository,
    required this._vehicleRepository,
    required this._rescueRepository,
  });

  final RouteSelection _route;
  final MapAndQuoteRepository _mapRepository;
  final VehicleRepository _vehicleRepository;
  final RescueRequestRepository _rescueRepository;

  RouteSelection get route => _route;

  bool _isInitializing = false;
  bool _isCalculatingQuote = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<WinchType> _winchTypes = const <WinchType>[];
  WinchType? _selectedWinchType;
  List<CustomerVehicle> _savedVehicles = const <CustomerVehicle>[];
  CustomerVehicle? _selectedVehicle;
  bool _useManualVehicle = false;

  // Manual vehicle inputs
  String _manualMake = '';
  String _manualModel = '';
  int? _manualYear;
  String _manualColor = '';
  String _manualPlate = '';
  VehicleCategory _manualCategory = VehicleCategory.sedan;

  // Breakdown context & payment
  String _breakdownReason = '';
  String _breakdownNotes = '';
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final List<SelectedPhotoBytes> _photos = <SelectedPhotoBytes>[];

  WinchQuote? _quote;

  bool get isInitializing => _isInitializing;
  bool get isCalculatingQuote => _isCalculatingQuote;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  List<WinchType> get winchTypes => _winchTypes;
  WinchType? get selectedWinchType => _selectedWinchType;
  List<CustomerVehicle> get savedVehicles => _savedVehicles;
  CustomerVehicle? get selectedVehicle => _selectedVehicle;
  bool get useManualVehicle => _useManualVehicle || _savedVehicles.isEmpty;

  VehicleCategory get manualCategory => _manualCategory;
  PaymentMethod get paymentMethod => _paymentMethod;
  List<SelectedPhotoBytes> get photos => List.unmodifiable(_photos);
  WinchQuote? get quote => _quote;

  bool get hasValidVehicle {
    if (!useManualVehicle && _selectedVehicle != null) return true;
    return _manualMake.trim().isNotEmpty &&
        _manualModel.trim().isNotEmpty &&
        _manualPlate.trim().isNotEmpty;
  }

  Future<void> initialize({
    required String customerId,
    String locale = 'ar',
  }) async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _mapRepository.getActiveWinchTypes(),
        _vehicleRepository.fetchVehicles(customerId),
      ]);

      _winchTypes = results[0] as List<WinchType>;
      _savedVehicles = results[1] as List<CustomerVehicle>;

      if (_winchTypes.isNotEmpty) {
        _selectedWinchType = _winchTypes.firstWhere(
          (w) => w.id == _route.initialWinchTypeId,
          orElse: () => _winchTypes.first,
        );
      }

      if (_savedVehicles.isNotEmpty) {
        _selectedVehicle = _savedVehicles.firstWhere(
          (v) => v.isDefault,
          orElse: () => _savedVehicles.first,
        );
        _useManualVehicle = false;
      } else {
        _useManualVehicle = true;
      }

      await refreshQuote(locale: locale);
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> selectWinchType(WinchType type, {String locale = 'ar'}) async {
    if (_selectedWinchType?.id == type.id) return;
    _selectedWinchType = type;
    notifyListeners();
    await refreshQuote(locale: locale);
  }

  void selectSavedVehicle(CustomerVehicle vehicle) {
    _selectedVehicle = vehicle;
    _useManualVehicle = false;
    notifyListeners();
  }

  void enableManualVehicle() {
    _useManualVehicle = true;
    _selectedVehicle = null;
    notifyListeners();
  }

  void updateManualVehicle({
    String? make,
    String? model,
    int? year,
    String? color,
    String? plate,
    VehicleCategory? category,
  }) {
    if (make != null) _manualMake = make;
    if (model != null) _manualModel = model;
    _manualYear = year ?? _manualYear;
    if (color != null) _manualColor = color;
    if (plate != null) _manualPlate = plate;
    if (category != null) {
      _manualCategory = category;
      notifyListeners();
    }
  }

  void setBreakdownReason(String value) => _breakdownReason = value;
  void setBreakdownNotes(String value) => _breakdownNotes = value;

  void setPaymentMethod(PaymentMethod method) {
    if (_paymentMethod == method) return;
    _paymentMethod = method;
    notifyListeners();
  }

  void addPhotos(Iterable<SelectedPhotoBytes> newPhotos) {
    for (final p in newPhotos) {
      if (_photos.length >= 5) break;
      _photos.add(p);
    }
    notifyListeners();
  }

  void removePhotoAt(int index) {
    if (index < 0 || index >= _photos.length) return;
    _photos.removeAt(index);
    notifyListeners();
  }

  Future<void> refreshQuote({String locale = 'ar'}) async {
    final winchType = _selectedWinchType;
    if (winchType == null) return;

    _isCalculatingQuote = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _quote = await _mapRepository.calculateQuote(
        winchTypeId: winchType.id,
        pickupLat: _route.pickupPoint.latitude,
        pickupLng: _route.pickupPoint.longitude,
        dropoffLat: _route.dropoffPoint.latitude,
        dropoffLng: _route.dropoffPoint.longitude,
        routeDistanceKm: _route.routeDistanceKm,
      );
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
    } finally {
      _isCalculatingQuote = false;
      notifyListeners();
    }
  }

  Future<CreateRescueRequestResult?> submitRequest({
    required String customerId,
    String locale = 'ar',
  }) async {
    final winchType = _selectedWinchType;
    if (winchType == null) return null;

    if (!hasValidVehicle) {
      _errorMessage = locale.startsWith('ar')
          ? 'يرجى اختيار سيارة محفوظة أو إدخال الماركة والموديل ورقم اللوحة'
          : 'Please choose a saved vehicle or enter make, model, and plate.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final usingSaved = !useManualVehicle && _selectedVehicle != null;
      final saved = _selectedVehicle;

      final result = await _rescueRepository.createRescueRequest(
        winchTypeId: winchType.id,
        pickupLat: _route.pickupPoint.latitude,
        pickupLng: _route.pickupPoint.longitude,
        pickupAddress: _route.pickupAddress,
        dropoffLat: _route.dropoffPoint.latitude,
        dropoffLng: _route.dropoffPoint.longitude,
        dropoffAddress: _route.dropoffAddress,
        customerVehicleId: usingSaved ? saved!.id : null,
        vehicleMake: usingSaved ? saved!.make : _manualMake.trim(),
        vehicleModel: usingSaved ? saved!.model : _manualModel.trim(),
        vehicleYear: usingSaved ? saved!.year : _manualYear,
        vehicleColor: usingSaved
            ? saved!.color
            : (_manualColor.trim().isEmpty ? null : _manualColor.trim()),
        vehiclePlate: usingSaved ? saved!.plateNumber : _manualPlate.trim(),
        vehicleCategory:
            usingSaved ? saved!.vehicleCategory : _manualCategory,
        breakdownReason: _breakdownReason,
        breakdownNotes: _breakdownNotes,
        paymentMethod: _paymentMethod,
        routeDistanceKm: _route.routeDistanceKm,
      );

      var finalRequest = result.request;
      if (_photos.isNotEmpty) {
        final paths = await _rescueRepository.uploadAndAttachBreakdownPhotos(
          customerId: customerId,
          requestId: result.request.id,
          photos: _photos,
        );
        finalRequest = finalRequest.copyWith(breakdownPhotoPaths: paths);
      }

      return CreateRescueRequestResult(
        request: finalRequest,
        quote: result.quote,
        dispatch: result.dispatch,
      );
    } catch (e) {
      _errorMessage = ErrorFormatter.format(e, locale: locale);
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
