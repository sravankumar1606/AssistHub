import 'dart:async';
import 'package:flutter/material.dart';
import '../data/models/booking_model.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/booking_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/employee_repository.dart';
import 'auth_provider.dart';

class BookingProvider extends ChangeNotifier {
  final BookingRepository _bookingRepository = BookingRepository();
  final NotificationRepository _notificationRepository = NotificationRepository();
  final EmployeeRepository _employeeRepository = EmployeeRepository();

  AuthProvider? _authProvider;
  List<BookingModel> _bookings = [];
  List<BookingModel> _pendingBookings = [];
  List<BookingModel> _activeBookings = [];
  List<BookingModel> _instantBookings = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<BookingModel>>? _bookingsSubscription;
  StreamSubscription<List<BookingModel>>? _pendingSubscription;
  StreamSubscription<List<BookingModel>>? _activeSubscription;
  StreamSubscription<List<BookingModel>>? _instantSubscription;

  List<BookingModel> get bookings => _bookings;
  List<BookingModel> get pendingBookings => _pendingBookings;
  List<BookingModel> get activeBookings => _activeBookings;

  /// Unclaimed instant requests for this employee's category, excluding
  /// any they've personally dismissed.
  List<BookingModel> get instantBookings {
    final selfId = _authProvider?.user?.id;
    if (selfId == null) return _instantBookings;
    return _instantBookings.where((b) => !b.dismissedBy.contains(selfId)).toList();
  }
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (authProvider.user != null) {
      if (authProvider.isCustomer) {
        _subscribeToCustomerBookings(authProvider.user!.id);
      } else if (authProvider.isEmployee) {
        _subscribeToEmployeeBookings(authProvider.user!.id);
      }
    }
  }

  void _subscribeToCustomerBookings(String customerId) {
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _bookingRepository.customerBookingsStream(customerId).listen(
      (bookings) {
        _bookings = bookings;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  void _subscribeToEmployeeBookings(String employeeId) {
    _bookingsSubscription?.cancel();
    _pendingSubscription?.cancel();
    _activeSubscription?.cancel();

    _bookingsSubscription = _bookingRepository.employeeBookingsStream(employeeId).listen(
      (bookings) {
        _bookings = bookings;
        notifyListeners();
      },
    );

    _pendingSubscription = _bookingRepository.pendingBookingsStream(employeeId).listen(
      (bookings) {
        _pendingBookings = bookings;
        notifyListeners();
      },
    );

    _activeSubscription = _bookingRepository.activeBookingsStream(employeeId).listen(
      (bookings) {
        _activeBookings = bookings;
        notifyListeners();
      },
    );
  }

  /// Call this once the employee's own category is known (e.g. right
  /// after EmployeeProvider loads currentEmployee) — typically from the
  /// employee home/bookings screen's initState.
  void subscribeToInstantBookings(String serviceCategory) {
    _instantSubscription?.cancel();
    _instantSubscription =
        _bookingRepository.instantBookingsStream(serviceCategory).listen(
      (bookings) {
        _instantBookings = bookings;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Attempts to claim an instant request. Returns null on success, or a
  /// user-facing message if someone else already claimed it first.
  Future<String?> acceptInstantBooking(String bookingId) async {
    if (_authProvider?.user == null) return 'You must be signed in.';
    final user = _authProvider!.user!;

    try {
      await _bookingRepository.claimInstantBooking(
        bookingId: bookingId,
        employeeId: user.id,
        employeeName: user.name,
        employeePhone: user.phone ?? '',
      );

      final booking = await _bookingRepository.getBooking(bookingId);
      if (booking != null) {
        await _notificationRepository.createNotification(
          NotificationModel(
            id: '',
            userId: booking.customerId,
            title: 'Provider Found',
            body: '${user.name} accepted your instant booking request',
            type: NotificationType.bookingAccepted,
            data: {'bookingId': bookingId},
            createdAt: DateTime.now(),
          ),
        );
      }
      return null;
    } on StateError catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to accept: $e';
    }
  }

  /// Hides this instant request from just this employee's own list —
  /// it stays open for everyone else in the category.
  Future<void> dismissInstantBooking(String bookingId) async {
    if (_authProvider?.user == null) return;
    try {
      await _bookingRepository.dismissInstantBookingForEmployee(
        bookingId,
        _authProvider!.user!.id,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> createBooking({
    required String employeeId,
    required String employeeName,
    required String employeePhone,
    required String serviceCategory,
    required String serviceDetails,
    required DateTime scheduledDate,
    required String scheduledTime,
    required double amount,
    String? customerPhone,
    String? customerAddress,
    double? customerLatitude,
    double? customerLongitude,
    String? notes,
    bool isInstant = false,
  }) async {
    if (_authProvider?.user == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = _authProvider!.user!;
      final now = DateTime.now();

      final booking = BookingModel(
        id: '',
        customerId: user.id,
        customerName: user.name,
        customerPhone: customerPhone?.trim().isNotEmpty == true
            ? customerPhone!.trim()
            : (user.phone ?? ''),
        customerAddress: customerAddress?.trim().isNotEmpty == true
            ? customerAddress!.trim()
            : (user.address ?? ''),
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
        // Instant bookings start unassigned — employeeId empty means
        // "broadcast to everyone in this category," and whoever accepts
        // first gets these fields filled in via claimInstantBooking.
        employeeId: isInstant ? '' : employeeId,
        employeeName: isInstant ? '' : employeeName,
        employeePhone: isInstant ? '' : employeePhone,
        serviceCategory: serviceCategory,
        serviceDetails: serviceDetails,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        amount: amount,
        status: BookingStatus.pending,
        notes: notes,
        isInstant: isInstant,
        createdAt: now,
        updatedAt: now,
      );

      final bookingId = await _bookingRepository.createBooking(booking);

      if (isInstant) {
        // No single employee to notify yet — everyone matching the
        // category sees it live via their instantBookingsStream instead.
        await _notificationRepository.createNotification(
          NotificationModel(
            id: '',
            userId: user.id,
            title: 'Instant Booking Sent',
            body: 'Your urgent $serviceCategory request has been sent to nearby providers.',
            type: NotificationType.bookingRequest,
            data: {'bookingId': bookingId},
            createdAt: now,
          ),
        );
      } else {
        await _notificationRepository.createNotification(
          NotificationModel(
            id: '',
            userId: employeeId,
            title: 'New Booking Request',
            body: '${user.name} has requested a $serviceCategory service',
            type: NotificationType.bookingRequest,
            data: {'bookingId': bookingId},
            createdAt: now,
          ),
        );

        await _notificationRepository.createNotification(
          NotificationModel(
            id: '',
            userId: user.id,
            title: 'Booking Request Sent',
            body: 'Your request to book $employeeName is waiting for confirmation',
            type: NotificationType.bookingRequest,
            data: {'bookingId': bookingId},
            createdAt: now,
          ),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBookingStatus(String bookingId, BookingStatus status) async {
    try {
      final booking = await _bookingRepository.getBooking(bookingId);
      if (booking == null) return true;
      final wasAlreadyCompleted = booking.status == BookingStatus.completed;
      if (wasAlreadyCompleted && status == BookingStatus.completed) return true;

      await _bookingRepository.updateBookingStatus(bookingId, status);

      String notificationTitle;
      String notificationBody;
      NotificationType notificationType;

      switch (status) {
        case BookingStatus.accepted:
          notificationTitle = 'Booking Accepted';
          notificationBody = '${booking.employeeName} has accepted your booking';
          notificationType = NotificationType.bookingAccepted;
          break;
        case BookingStatus.rejected:
          notificationTitle = 'Booking Rejected';
          notificationBody = '${booking.employeeName} has rejected your booking';
          notificationType = NotificationType.bookingRejected;
          break;
        case BookingStatus.onTheWay:
          notificationTitle = 'On the Way';
          notificationBody = '${booking.employeeName} is on the way';
          notificationType = NotificationType.statusUpdate;
          break;
        case BookingStatus.working:
          notificationTitle = 'Work Started';
          notificationBody = '${booking.employeeName} has started working';
          notificationType = NotificationType.statusUpdate;
          break;
        case BookingStatus.completed:
          notificationTitle = 'Service Completed';
          notificationBody =
              'Your service has been completed. Please rate ${booking.employeeName} for the work.';
          notificationType = NotificationType.statusUpdate;
          if (!wasAlreadyCompleted) {
            await _employeeRepository.incrementJobCount(booking.employeeId);
            await _employeeRepository.addEarnings(booking.employeeId, booking.amount);
          }
          break;
        default:
          return true;
      }

      await _notificationRepository.createNotification(
        NotificationModel(
          id: '',
          userId: booking.customerId,
          title: notificationTitle,
          body: notificationBody,
          type: notificationType,
          data: {'bookingId': bookingId},
          createdAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<bool> cancelBooking(String bookingId, String reason) async {
    try {
      final booking = await _bookingRepository.getBooking(bookingId);
      await _bookingRepository.cancelBooking(bookingId, reason);

      if (booking != null) {
        final now = DateTime.now();
        final cancelledByCustomer = _authProvider?.user?.id == booking.customerId;
        final actorName = _authProvider?.user?.name ?? 'A user';

        await _notificationRepository.createNotification(
          NotificationModel(
            id: '',
            userId: booking.customerId,
            title: 'Booking Cancelled',
            body: cancelledByCustomer
                ? 'Your booking with ${booking.employeeName} was cancelled'
                : '$actorName cancelled your booking with ${booking.employeeName}',
            type: NotificationType.bookingCancelled,
            data: {
              'bookingId': bookingId,
              'reason': reason,
            },
            createdAt: now,
          ),
        );

        await _notificationRepository.createNotification(
          NotificationModel(
            id: '',
            userId: booking.employeeId,
            title: 'Booking Cancelled',
            body: cancelledByCustomer
                ? '${booking.customerName} cancelled the ${booking.serviceCategory} booking'
                : 'You cancelled the booking with ${booking.customerName}',
            type: NotificationType.bookingCancelled,
            data: {
              'bookingId': bookingId,
              'reason': reason,
            },
            createdAt: now,
          ),
        );
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Stream<BookingModel?> bookingStream(String bookingId) {
    return _bookingRepository.bookingStream(bookingId);
  }

  Future<List<BookingModel>> getRecentBookings() async {
    if (_authProvider?.user == null) return [];
    return await _bookingRepository.getRecentBookings(_authProvider!.user!.id);
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    _pendingSubscription?.cancel();
    _activeSubscription?.cancel();
    _instantSubscription?.cancel();
    super.dispose();
  }
}
