import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/validators.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_button.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/data/models/employee_model.dart';
import 'package:assisthub/providers/auth_provider.dart';
import 'package:assisthub/providers/booking_provider.dart';
import 'package:assisthub/providers/employee_provider.dart';

class BookingScreen extends StatefulWidget {
  /// Either [employee] (normal, targeted booking) or [category] (Instant
  /// Booking entry point from the home page, no specific employee yet)
  /// must be provided.
  final EmployeeModel? employee;
  final String? category;

  const BookingScreen({super.key, this.employee, this.category})
      : assert(employee != null || category != null,
            'Provide either an employee or a category');

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _serviceDetailsController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  int _hours = 2;
  bool _isLoading = false;
  late bool _isInstant;
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  double _estimatedRate = 300; // fallback used only when no employee chosen

  /// The category this booking is for, whichever entry point was used.
  String get _category => widget.employee?.serviceCategory ?? widget.category!;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _phoneController.text = user?.phone ?? '';
    _addressController.text = user?.address ?? '';
    _serviceDetailsController.text = widget.employee?.serviceDetails ?? '';

    // Category-only entry (Instant Booking from home) is always instant —
    // there's no specific employee to book normally with. When a specific
    // employee was chosen, instant stays an optional toggle.
    _isInstant = widget.employee == null;

    if (widget.employee == null) {
      _estimateRateForCategory();
    }
  }

  void _estimateRateForCategory() {
    final matches = context
        .read<EmployeeProvider>()
        .employees
        .where((e) => e.serviceCategory == widget.category)
        .toList();
    if (matches.isEmpty) return;
    final avg = matches.map((e) => e.hourlyRate).reduce((a, b) => a + b) / matches.length;
    setState(() => _estimatedRate = avg);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _serviceDetailsController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  double get _totalAmount =>
      (widget.employee?.hourlyRate ?? _estimatedRate) * _hours;

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final permission = await Geolocator.checkPermission();
      var granted = permission;
      if (permission == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }

      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        if (mounted) {
          Helpers.showSnackBar(
            context,
            'Location permission denied. You can still type your address manually.',
            isError: true,
          );
        }
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          Helpers.showSnackBar(context, 'Please enable location services', isError: true);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Location captured — the employee will get your exact pin.',
        );
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(context, 'Could not get location: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final bookingProvider = context.read<BookingProvider>();
    final success = await bookingProvider.createBooking(
      employeeId: widget.employee?.id ?? '',
      employeeName: widget.employee?.name ?? '',
      employeePhone: widget.employee?.phone ?? '',
      serviceCategory: _category,
      serviceDetails: _serviceDetailsController.text.trim(),
      scheduledDate: _selectedDate,
      scheduledTime: _selectedTime.format(context),
      amount: _totalAmount,
      customerPhone: _phoneController.text.trim(),
      customerAddress: _addressController.text.trim(),
      customerLatitude: _latitude,
      customerLongitude: _longitude,
      notes: _notesController.text,
      isInstant: _isInstant,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Helpers.showSnackBar(
        context,
        _isInstant
            ? 'Instant request sent to all nearby $_category providers!'
            : 'Booking request sent successfully!',
      );
      Navigator.pop(context);
      Navigator.pop(context);
    } else if (mounted) {
      Helpers.showSnackBar(context, bookingProvider.error ?? 'Failed to create booking', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Service'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            employee != null
                ? _buildEmployeeInfo(employee)
                : _buildCategoryInfo(_category),
            const SizedBox(height: 16),
            _buildInstantBookingToggle(),
            const SizedBox(height: 24),
            _buildSectionTitle('Schedule'),
            const SizedBox(height: 12),
            _buildDateTimePicker(),
            const SizedBox(height: 16),
            _buildDurationSelector(),
            const SizedBox(height: 24),
            _buildSectionTitle('What do you need?'),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Service Details',
              hint: employee != null
                  ? 'Describe what you need'
                  : 'e.g. Kitchen tap is leaking, needs urgent fix',
              controller: _serviceDetailsController,
              maxLines: 3,
              validator: (value) =>
                  Validators.required(value, 'Service details'),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Contact Details'),
            const SizedBox(height: 12),
            CustomTextField(
              label: 'Phone Number',
              hint: 'Enter your phone number',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: Validators.phone,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Address',
              hint: 'Enter service address',
              controller: _addressController,
              maxLines: 2,
              prefixIcon: Icons.location_on_outlined,
              validator: (value) => Validators.required(value, 'Address'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocating ? null : _useCurrentLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: Text(
                      _isLocating
                          ? 'Getting location...'
                          : (_latitude != null
                              ? 'Location captured ✓'
                              : 'Use my current location'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _latitude != null ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (_latitude != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'The employee will get your exact pin location for accurate navigation.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey600,
                      ),
                ),
              ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Notes (Optional)',
              hint: 'Any special instructions?',
              controller: _notesController,
              maxLines: 3,
              prefixIcon: Icons.note_outlined,
            ),
            const SizedBox(height: 24),
            _buildPriceSummary(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.grey300.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: GradientButton(
            text: _isInstant ? 'Send Instant Request' : 'Confirm Booking',
            onPressed: _submitBooking,
            isLoading: _isLoading,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryInfo(String category) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Sent to all available providers in this category',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeInfo(EmployeeModel employee) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: employee.profileImage != null
                  ? NetworkImage(employee.profileImage!)
                  : null,
              child: employee.profileImage == null
                  ? Text(
                      employee.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.serviceCategory,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Helpers.formatCurrency(employee.hourlyRate),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'per hour',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey500,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstantBookingToggle() {
    return Card(
      color: _isInstant ? AppColors.warning.withOpacity(0.08) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instant Booking',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    _isInstant
                        ? 'Sent to every $_category provider nearby — first to accept gets the job.'
                        : 'In a hurry? Send this to all nearby providers instead of just this one.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey600,
                        ),
                  ),
                ],
              ),
            ),
            if (widget.employee != null)
              Switch(
                value: _isInstant,
                activeColor: AppColors.warning,
                onChanged: (value) => setState(() => _isInstant = value),
              )
            else
              const Icon(Icons.lock_outline, size: 18, color: AppColors.grey500),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildDateTimePicker() {
    return Row(
      children: [
        Expanded(
          child: _buildPickerCard(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: DateFormat('MMM dd, yyyy').format(_selectedDate),
            onTap: _selectDate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPickerCard(
            icon: Icons.access_time,
            label: 'Time',
            value: _selectedTime.format(context),
            onTap: _selectTime,
          ),
        ),
      ],
    );
  }

  Widget _buildPickerCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.grey500,
                          ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.grey500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Duration',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.grey500,
                        ),
                  ),
                  Text(
                    '$_hours hours',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _hours > 1
                      ? () => setState(() => _hours--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primary,
                ),
                Text(
                  '$_hours',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: _hours < 8
                      ? () => setState(() => _hours++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Card(
      color: AppColors.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPriceRow(
              widget.employee != null ? 'Service Rate' : 'Estimated Rate',
              '${Helpers.formatCurrency(widget.employee?.hourlyRate ?? _estimatedRate)}/hr',
            ),
            const SizedBox(height: 8),
            _buildPriceRow('Duration', '$_hours hours'),
            const Divider(height: 24),
            _buildPriceRow(
              'Total',
              Helpers.formatCurrency(_totalAmount),
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? Theme.of(context).textTheme.titleMedium
              : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.grey600,
                  ),
        ),
        Text(
          value,
          style: isTotal
              ? Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
