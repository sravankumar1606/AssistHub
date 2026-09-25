import 'package:flutter/material.dart';
import 'package:assisthub/providers/core/constants/app_colors.dart';
import 'package:assisthub/providers/core/utils/helpers.dart';
import 'package:assisthub/providers/core/widgets/custom_text_field.dart';
import 'package:assisthub/data/services/admin_broadcast_service.dart';

enum _Target { everyone, allCustomers, allEmployees, specificUser }

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _service = AdminBroadcastService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _searchController = TextEditingController();

  _Target _target = _Target.everyone;
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSending = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    // Typing again means they're picking someone else — drop the old
    // selection so results show instead of the locked-in recipient card.
    if (_selectedUser != null) {
      setState(() => _selectedUser = null);
    }

    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _service.searchUsers(query.trim());
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      Helpers.showSnackBar(context, 'Enter both a title and message', isError: true);
      return;
    }
    if (_target == _Target.specificUser && _selectedUser == null) {
      Helpers.showSnackBar(context, 'Select a recipient', isError: true);
      return;
    }

    setState(() => _isSending = true);

    try {
      int sentCount = 1;
      switch (_target) {
        case _Target.everyone:
          sentCount = await _service.sendToAll(title: title, body: body);
          break;
        case _Target.allCustomers:
          sentCount = await _service.sendToRole(role: 'customer', title: title, body: body);
          break;
        case _Target.allEmployees:
          sentCount = await _service.sendToRole(role: 'employee', title: title, body: body);
          break;
        case _Target.specificUser:
          await _service.sendToUserId(
            userId: _selectedUser!['id'],
            title: title,
            body: body,
          );
          break;
      }

      if (!mounted) return;
      Helpers.showSnackBar(context, 'Sent to $sentCount recipient(s)');
      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _selectedUser = null;
        _searchController.clear();
        _searchResults = [];
      });
    } catch (e) {
      if (mounted) Helpers.showSnackBar(context, 'Failed to send: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Notification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Recipients', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Everyone'),
                selected: _target == _Target.everyone,
                onSelected: (_) => setState(() => _target = _Target.everyone),
              ),
              ChoiceChip(
                label: const Text('All Customers'),
                selected: _target == _Target.allCustomers,
                onSelected: (_) => setState(() => _target = _Target.allCustomers),
              ),
              ChoiceChip(
                label: const Text('All Employees'),
                selected: _target == _Target.allEmployees,
                onSelected: (_) => setState(() => _target = _Target.allEmployees),
              ),
              ChoiceChip(
                label: const Text('Specific person'),
                selected: _target == _Target.specificUser,
                onSelected: (_) => setState(() => _target = _Target.specificUser),
              ),
            ],
          ),
          if (_target == _Target.specificUser) ...[
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Search by name or email',
              controller: _searchController,
              prefixIcon: Icons.search,
              onChanged: _searchUsers,
            ),
            if (_isSearching) const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            if (_selectedUser != null)
              Card(
                color: AppColors.primary.withOpacity(0.08),
                child: ListTile(
                  title: Text(_selectedUser!['name'] ?? ''),
                  subtitle: Text(_selectedUser!['email'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _selectedUser = null;
                      _searchController.clear();
                      _searchResults = [];
                    }),
                  ),
                ),
              )
            else
              ..._searchResults.take(5).map((user) => Card(
                    child: ListTile(
                      title: Text(user['name'] ?? ''),
                      subtitle: Text(user['email'] ?? ''),
                      trailing: Text(user['role'] ?? ''),
                      onTap: () => setState(() {
                        _selectedUser = user;
                        // Show the chosen recipient in the field itself,
                        // so it's clear who the message will go to.
                        _searchController.text = user['email'] ?? '';
                        _searchResults = [];
                      }),
                    ),
                  )),
          ],
          const SizedBox(height: 24),
          Text('Message', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          CustomTextField(
            label: 'Title',
            controller: _titleController,
          ),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Message',
            controller: _bodyController,
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSending ? null : _send,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _isSending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
    );
  }
}
