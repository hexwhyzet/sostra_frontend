import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_reader/alert.dart';
import 'package:qr_reader/data/common/user.dart';
import 'package:qr_reader/data/dispatch/duty.dart';
import 'package:qr_reader/request.dart';

class ReassignDutyScreen extends StatefulWidget {
  final int dutyId;
  final String? refusalReason;
  final String? refusedBy;
  final int notificationId;

  const ReassignDutyScreen({
    super.key,
    required this.dutyId,
    this.refusalReason,
    this.refusedBy,
    required this.notificationId,
  });

  @override
  State<ReassignDutyScreen> createState() => _ReassignDutyScreenState();
}

class _ReassignDutyScreenState extends State<ReassignDutyScreen> {
  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = true;
  Duty? _duty;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchDuty();
  }

  Future<void> _fetchDuty() async {
    try {
      Map<String, dynamic> response =
          await sendRequest('GET', 'dispatch/duties/${widget.dutyId}/');
      setState(() {
        _duty = Duty.fromJson(response);
      });
    } catch (e) {
      print('Error fetching duty: $e');
    }
  }

  Future<void> _fetchUsers() async {
    try {
      List<dynamic> response = await sendRequest('GET', 'users/');

      setState(() {
        _users = User.fromJsonList(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      raiseErrorFlushbar(context, 'Не удалось загрузить пользователей');
    }
  }

  void _reassignDuty() async {
    if (_selectedUser == null) {
      raiseErrorFlushbar(context, "Выберите пользователя для переназначения");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await sendRequest(
          'POST', 'dispatch/duties/reassign_by_notification/',
          body: {'user_id': _selectedUser!.id, 'notification_id': widget.notificationId});

      Navigator.pop(context);
      raiseSuccessFlushbar(context, "Дежурство переназначено");
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      raiseErrorFlushbar(context, 'Не удалось переназначить дежурство');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Переназначить дежурство')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_duty != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Информация о дежурстве',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text('Роль: ${_duty!.role.name}'),
                            Text(
                                'Дата: ${DateFormat('dd.MM.yyyy').format(_duty!.start.toLocal())} - ${DateFormat('dd.MM.yyyy').format(_duty!.end.toLocal())}'),
                            Text(
                                'Время: ${DateFormat('HH:mm').format(_duty!.start.toLocal())} - ${DateFormat('HH:mm').format(_duty!.end.toLocal())}'),
                          ],
                        ),
                      ),
                    ),
                  if (widget.refusedBy != null) ...[
                    SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Отказ от дежурства',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700),
                            ),
                            SizedBox(height: 8),
                            Text('Отказался: ${widget.refusedBy}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (widget.refusalReason != null &&
                      widget.refusalReason!.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Card(
                      color: Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Причина отказа',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(widget.refusalReason!),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
                  DropdownButtonFormField<User>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Выберите нового дежурного',
                      border: OutlineInputBorder(),
                      helperText: 'Выберите пользователя для переназначения',
                    ),
                    items: _users.map((user) {
                      return DropdownMenuItem(
                        value: user,
                        child: Text(user.displayName),
                      );
                    }).toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedUser = value;
                            });
                          },
                    value: _selectedUser,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting || _selectedUser == null
                          ? null
                          : _reassignDuty,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Переназначить дежурство'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
