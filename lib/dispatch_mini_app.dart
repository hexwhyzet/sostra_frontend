import 'dart:async';
import 'dart:developer';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:image_picker/image_picker.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_reader/alert.dart';
import 'package:qr_reader/data/dispatch/duty_point.dart';
import 'package:qr_reader/request.dart';
import 'package:qr_reader/settings.dart';
import 'package:qr_reader/visits.dart';
import 'package:video_player/video_player.dart';

import 'botton.dart';
import 'data/common/user.dart';
import 'data/dispatch/duty.dart';
import 'data/dispatch/incident.dart';
import 'data/dispatch/incident_message.dart';
import 'data/dispatch/incident_statistics.dart';
import 'data/dispatch/duty_point.dart';
import 'data/common/user.dart';

void main() => runApp(IncidentMiniApp());

class IncidentMiniApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    IncidentList(),
    DutySchedule(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Инциденты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Расписание',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class IncidentCreationScreen extends StatefulWidget {
  @override
  _IncidentCreationScreenState createState() => _IncidentCreationScreenState();
}

class _IncidentCreationScreenState extends State<IncidentCreationScreen> {
  List<dynamic> points = [];
  bool isLoading = true;
  dynamic selectedPoint;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDutyPoints();
    setState(() {
      isLoading = false;
    });
    titleController.addListener(() {
      setState(() {}); // Для того, чтобы активировалась кнопка создания
    });
    descriptionController.addListener(() {
      setState(() {}); // Для того, чтобы активировалась кнопка создания
    });
  }

  Future<void> fetchDutyPoints() async {
    List<dynamic> response = await sendRequest("GET", "dispatch/duty_points/");
    setState(() {
      points = DutyPoint.fromJsonList(response);
      points.sort((a, b) => b.name.compareTo(a.name));
    });
  }

  Future<void> createIncident() async {
    final response = await sendRequestWithStatus(
      "POST",
      "dispatch/incidents/",
      body: {
        'point_id': selectedPoint.id,
        'name': titleController.text,
        'description': descriptionController.text,
      },
    );

    if (response.statusCode == 201) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при создании инцидента')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Создание инцидента')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<dynamic>(
                    items: points
                        .map((point) => DropdownMenuItem(
                              value: point,
                              child: Text(point.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedPoint = value;
                      });
                    },
                    hint: Text('Выберите точку'),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: 'Заголовок'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: 'Описание'),
                    maxLines: 8,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: selectedPoint != null &&
                            titleController.text.isNotEmpty &&
                            descriptionController.text.isNotEmpty
                        ? createIncident
                        : null,
                    child: Text('Создать инцидент'),
                  ),
                ],
              ),
            ),
    );
  }
}

class TransferDutyScreen extends StatefulWidget {
  final int dutyId;

  const TransferDutyScreen({super.key, required this.dutyId});

  @override
  State<TransferDutyScreen> createState() => _TransferDutyScreenState();
}

class _TransferDutyScreenState extends State<TransferDutyScreen> {
  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = true;

  final TextEditingController _reasonTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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

  void _transferDuty() async {
    // if (_selectedUser == null) {
    //   raiseErrorFlushbar(context, "Выберите пользователя");
    //   return;
    // }

    final int userId = _selectedUser == null ? 0 : _selectedUser!.id;
    final int dutyId = widget.dutyId;

    try {
      await sendRequest(
        'POST', 
        'dispatch/duties/$dutyId/transfer_duty/',
        body: {'user_id': userId, 'user_reason': _reasonTextController.text},
      );
      Navigator.pop(context);
      if (userId == 0) {
        raiseSuccessFlushbar(
            context, "Отказ от дежурства отправлен администратору");
      } else {
        raiseSuccessFlushbar(context, "Дежурство передано");
      }
    } catch (e) {
      raiseErrorFlushbar(context, 'Не удалось обработать запрос');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Передать дежурство')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButtonFormField<User>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Выберите пользователя (необязательно)',
                      border: OutlineInputBorder(),
                      helperText:
                          'Оставьте пустым, чтобы отказаться от дежурства',
                    ),
                    items: [
                      const DropdownMenuItem<User>(
                        value: null,
                        child: Text('-- Отказаться от дежурства --'),
                      ),
                      ..._users.map((user) {
                        return DropdownMenuItem(
                          value: user,
                          child: Text(user.displayName),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUser = value;
                      });
                    },
                    value: _selectedUser,
                  ),
                  TextField(
                    controller: _reasonTextController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    minLines: 3,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Введите причину',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _transferDuty,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedUser == null
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(_selectedUser == null
                          ? 'Отказаться от дежурства'
                          : 'Передать дежурство'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class IncidentList extends StatefulWidget {
  @override
  _IncidentListState createState() => _IncidentListState();
}

class _IncidentListState extends State<IncidentList> with WidgetsBindingObserver {
  late int currentUserId;
  List<Incident> incidents = [];
  List<Duty> duties = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        fetchData();
      }
    });
  }

  void fetchData() async {
    currentUserId = int.parse(await config.userId.getSetting() ?? '0');
    await fetchIncidents();
    await fetchDuties();
  }

  Future<void> fetchIncidents() async {
    List<dynamic> response =
        await sendRequest("GET", "dispatch/incidents/my_incidents/");
    setState(() {
      incidents = Incident.fromJsonList(response);
      incidents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> fetchDuties() async {
    List<dynamic> dutiesResponse =
        await sendRequest("GET", "dispatch/duties/my_duties/");
    setState(() {
      duties = Duty.fromJsonList(dutiesResponse);
    });
  }

  Widget buildSection(String title, List<Incident> incidents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...incidents.map((incident) => IncidentTile(incident)).toList(),
      ],
    );
  }

  Future<void> openDuty(int dutyId) async {
    await sendRequest("POST", "dispatch/duties/${dutyId}/open/");
    fetchDuties();
  }

  Widget buildDutyTile(Duty duty) {
    return ListTile(
      title: Text(duty.role.name),
      trailing: SizedBox(
        width: 200,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: duty.isOpened ? null : () => openDuty(duty.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: duty.isOpened
                    ? Colors.white
                    : Theme.of(context).primaryColor,
                foregroundColor: duty.isOpened
                    ? Theme.of(context).primaryColor
                    : Colors.white,
              ),
              child: Text(duty.isOpened ? 'Открыто' : 'Открыть'),
            ),
            if (!duty.isOpened)
              Padding(
                padding: EdgeInsets.only(left: 15),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              TransferDutyScreen(dutyId: duty.id)),
                    );
                    fetchDuties();
                  },
                  child: Icon(Icons.close, size: 35, color: Colors.white),
                ),
              )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Incident> responsibleIncidents = [];
    List<Incident> authorIncidents = [];
    List<Incident> otherIncidents = [];

    for (final i in incidents) {
      if (i.responsibleUser?.id == currentUserId) {
        responsibleIncidents.add(i);
      } else if (i.author?.id == currentUserId) {
        authorIncidents.add(i);
      } else {
        otherIncidents.add(i);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Инциденты"),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => IncidentStatisticsScreen()),
              );
            },
            tooltip: 'Статистика',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchData();
            },
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => IncidentCreationScreen()),
              );
              fetchData();
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          if (duties.isNotEmpty) buildSection('Ваши текущие дежурства', []),
          ...duties.map((duty) => buildDutyTile(duty)).toList(),
          if (responsibleIncidents.isNotEmpty)
            buildSection('Вы ответственный за инцидент:', responsibleIncidents),
          if (authorIncidents.isNotEmpty)
            buildSection('Вы автор инцидента:', authorIncidents),
          if (otherIncidents.isNotEmpty)
            buildSection('Остальные инциденты', otherIncidents),
        ],
      ),
    );
  }
}

class IncidentTile extends StatelessWidget {
  final Incident incident;

  IncidentTile(this.incident);

  @override
  Widget build(BuildContext context) {
    final pointName = incident.point?.name ?? 'Неизвестная точка';
    Duration diff = DateTime.now().toUtc().difference(incident.createdAt);
    final timeAgo = formatTimeAgo(diff.inSeconds);

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(incident.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 5, bottom: 5),
              child: Text('Система: $pointName'),
            ),
            Text('Инцидент создан: $timeAgo'),
          ],
        ),
        trailing:
            incident.isCritical ? Icon(Icons.warning, color: Colors.red) : null,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    IncidentDetailScreen(incidentId: incident.id)),
          );
        },
      ),
    );
  }
}

class DutySchedule extends StatefulWidget {
  @override
  _DutyScheduleState createState() => _DutyScheduleState();
}

class _DutyScheduleState extends State<DutySchedule> with WidgetsBindingObserver {
  DateTime selectedDate = DateTime.now();
  List<Duty> duties = [];
  bool isLoading = false;
  Timer? _refreshTimer;

  Future<void> fetchDutiesForDate(DateTime date) async {
    setState(() {
      isLoading = true;
    });

    List<dynamic> response = await sendRequest("GET",
        "dispatch/duties/?date=${DateFormat('yyyy-MM-dd').format(date)}");
    setState(() {
      duties = Duty.fromJsonList(response);
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchDutiesForDate(selectedDate);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        fetchDutiesForDate(selectedDate);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Расписание дежурств"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchDutiesForDate(selectedDate);
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedDate = selectedDate.subtract(Duration(days: 1));
                  });
                  fetchDutiesForDate(selectedDate);
                },
              ),
              Text(DateFormat('dd MMM yyyy').format(selectedDate),
                  style: TextStyle(fontSize: 18)),
              IconButton(
                icon: Icon(Icons.arrow_forward),
                onPressed: () {
                  setState(() {
                    selectedDate = selectedDate.add(Duration(days: 1));
                  });
                  fetchDutiesForDate(selectedDate);
                },
              ),
            ],
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: duties.length,
                    itemBuilder: (context, index) {
                      final duty = duties[index];
                      return ListTile(
                        title: Text(duty.role.name),
                        subtitle: Text('Дежурный: ${duty.user.displayName}'),
                        trailing: duty.isOpened
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : Icon(Icons.cancel, color: Colors.red),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class IncidentDetailScreen extends StatefulWidget {
  final int incidentId;
  final expandableFabKey = GlobalKey<ExpandableFabState>();

  IncidentDetailScreen({required this.incidentId});

  @override
  _IncidentDetailScreenState createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen>
    with WidgetsBindingObserver {
  bool _isDescriptionVisible = false;
  Incident? _incident;
  List<IncidentMessage> _messages = [];
  int _currentPage = 1;
  bool _isLoadingMessages = false;
  Timer? _timer;

  // bool _hasMoreMessages = true;
  bool _hasMoreMessages = false;

  List<String> availableActions = [];

  @override
  void initState() {
    super.initState();
    fetchAll();
    WidgetsBinding.instance.addObserver(this);
    _startUpdating();
  }

  void _startUpdating() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (ModalRoute.of(context)?.isCurrent ?? true) {
        fetchMessages();
      }
    });
  }

  Future<void> fetchAll() async {
    setState(() {
      fetchIncident(widget.incidentId);
      fetchMessages();
      fetchActions();
    });
  }

  Future<void> fetchActions() async {
    availableActions = (await sendRequest('GET',
            'dispatch/incidents/${widget.incidentId}/available_actions/'))
        .cast<String>();
  }

  Future<void> fetchIncident(int incidentId) async {
    dynamic incidentResponse =
        await sendRequest("GET", "dispatch/incidents/$incidentId/");
    setState(() {
      _incident = Incident.fromJson(incidentResponse);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  // Future<void> fetchLatestMessages() async {
  //   var pageCount = 1;
  //   List<IncidentMessage> allNewMessages = [];
  //   while (true) {
  //     List<dynamic> response = (await sendRequest(
  //         "GET", "dispatch/incidents/${widget.incidentId}/messages/?page=$pageCount"))["results"];
  //     print(response);
  //     final newMessages = IncidentMessage.fromJsonList(response);
  //
  //     print(newMessages);
  //
  //     while (newMessages.isNotEmpty && (_messages.isEmpty || _messages[0].id < newMessages[0].id)) {
  //       allNewMessages.add(newMessages[0]);
  //       newMessages.removeAt(0);
  //       print("ADDED!");
  //     }
  //
  //     if (newMessages.isNotEmpty) {
  //       break;
  //     }
  //
  //     pageCount++;
  //   }
  //   setState(() {
  //     _messages.insertAll(0, allNewMessages);
  //   });
  // }

  // Future<void> fetchMessages() async {
  //   print("ENTER");
  //   if (_isLoadingMessages || !_hasMoreMessages) return;
  //
  //   setState(() {
  //     _isLoadingMessages = true;
  //   });
  //
  //   List<dynamic> response = (await sendRequest(
  //       "GET", "dispatch/incidents/${widget.incidentId}/messages/?page=$_currentPage"))["results"];
  //   final newMessages = IncidentMessage.fromJsonList(response);
  //
  //   if (newMessages.isEmpty) {
  //     return;
  //   }
  //
  //   setState(() {
  //     _hasMoreMessages = newMessages.isNotEmpty;
  //     print("PIZDA1");
  //     print(newMessages);
  //     while (_messages.isNotEmpty &&
  //         newMessages.isNotEmpty &&
  //         _messages[_messages.length - 1].id <= newMessages[0].id) {
  //       newMessages.removeAt(0);
  //     }
  //     print("PIZDA2");
  //     print(newMessages);
  //     _messages.addAll(newMessages);
  //     _isLoadingMessages = false;
  //     _currentPage++;
  //     print("HAS MORE");
  //     print(_hasMoreMessages);
  //   });
  // }

  Future<void> fetchMessages() async {
    // print("ENTER");
    // if (_isLoadingMessages || !_hasMoreMessages) return;

    // setState(() {
    //   _isLoadingMessages = true;
    // });

    List<dynamic> response = (await sendRequest(
        "GET", "dispatch/incidents/${widget.incidentId}/messages/"));
    final newMessages = IncidentMessage.fromJsonList(response);

    if (newMessages.isEmpty) {
      return;
    }

    setState(() {
      _messages = newMessages;
    });
  }

  Widget _buildMessage(IncidentMessage message, {bool isSystem = false}) {
    switch (message.type) {
      case 'photo':
        return InstaImageViewer(
          child: Image.network(message.contentObject.photoUrl!,
              errorBuilder: (context, error, stackTrace) {
            debugPrint('Ошибка при загрузке изображения: $error');
            debugPrint('StackTrace: $stackTrace');
            return const Icon(Icons.broken_image);
          }),
        );
      case 'video':
        return GestureDetector(
          onTap: () => {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                      videoUrl: message.contentObject.videoUrl!)),
            )
          },
          child: Icon(Icons.videocam, size: 50),
        );
      case 'audio':
        return Icon(Icons.audiotrack, size: 50);
      default:
        return Text(message.contentObject.text ?? "Текст недоступен",
            style:
                TextStyle(color: isSystem ? Colors.grey[700] : Colors.black));
    }
  }

  Future<ImageSource?> _showMediaOptions(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Открыть камеру"),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.image),
              title: Text("Выбрать из галереи"),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  void showMessageModal(BuildContext context) {
    TextEditingController _messageController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 15,
            left: 12.0,
            right: 12.0,
            top: 12.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Новое сообщение',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _messageController,
                minLines: 3,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Начните писать здесь...',
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    String message = _messageController.text;
                    await sendRequestWithStatus('POST',
                        'dispatch/incidents/${widget.incidentId}/messages/',
                        body: {
                          "message_type": "text",
                          "text": message,
                        },
                        isMultipart: true);
                    fetchMessages();
                    // fetchLatestMessages();
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.send),
                  label: Text('Отправить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();
  }

  AppBar getAppBar() {
    return AppBar(
      title: Text('Инцидент №${widget.incidentId}'),
      actions: availableActions.length > 0
          ? [
              PopupMenuButton<String>(
                onSelected: (String value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Вы выбрали: $value')),
                  );
                },
                itemBuilder: (BuildContext context) {
                  return [
                    if (availableActions.contains("opened"))
                      PopupMenuItem<String>(
                        value: "Открыть",
                        child: Text("Открыть"),
                        onTap: () async {
                          await sendRequest("POST",
                              "dispatch/incidents/${widget.incidentId}/change_status/",
                              body: {"status": "opened"});
                          fetchAll();
                        },
                      ),
                    if (availableActions.contains("closed"))
                      PopupMenuItem<String>(
                        value: "Закрыть",
                        child: Text("Закрыть"),
                        onTap: () async {
                          await sendRequest("POST",
                              "dispatch/incidents/${widget.incidentId}/change_status/",
                              body: {"status": "closed"});
                          fetchAll();
                        },
                      ),
                    if (availableActions.contains("force_closed"))
                      PopupMenuItem<String>(
                        value: "Ненадлежащее выполнение",
                        child: Text("Ненадлежащее выполнение"),
                        onTap: () async {
                          await sendRequest("POST",
                              "dispatch/incidents/${widget.incidentId}/change_status/",
                              body: {"status": "force_closed"});
                          fetchAll();
                        },
                      ),
                    if (availableActions.contains("escalate"))
                      PopupMenuItem<String>(
                        value: "Вызвать дежурного сотрудника высшего уровня",
                        child:
                            Text("Вызвать дежурного сотрудника высшего уровня"),
                        onTap: () async {
                          await sendRequest("POST",
                              "dispatch/incidents/${widget.incidentId}/escalate/");
                          fetchAll();
                        },
                      ),
                  ];
                },
                icon: Icon(Icons.more_vert), // Иконка кнопки в AppBar
              ),
            ]
          : [],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton:
          (_incident != null && _incident!.status != "waiting_to_be_accepted")
              ? ExpandableFab(
                  key: widget.expandableFabKey,
                  openButtonBuilder: RotateFloatingActionButtonBuilder(
                    child: const Icon(Icons.add, size: 32),
                    fabSize: ExpandableFabSize.regular,
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: const CircleBorder(),
                  ),
                  closeButtonBuilder: DefaultFloatingActionButtonBuilder(
                    child: const Icon(Icons.close),
                    fabSize: ExpandableFabSize.small,
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: const CircleBorder(),
                  ),
                  children: [
                    FloatingActionButton(
                      backgroundColor: Theme.of(context).primaryColor,
                      heroTag: null,
                      child: const Icon(Icons.edit),
                      onPressed: () {
                        showMessageModal(context);
                        final state = widget.expandableFabKey.currentState;
                        if (state != null) {
                          state.toggle();
                        }
                      },
                    ),
                    FloatingActionButton(
                      backgroundColor: Theme.of(context).primaryColor,
                      heroTag: null,
                      child: const Icon(Icons.image),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        ImageSource? source = await _showMediaOptions(context);
                        if (source != null) {
                          XFile? image = await picker.pickImage(source: source);
                          if (image != null) {
                            await sendFileWithMultipart(
                                "POST",
                                "dispatch/incidents/${widget.incidentId}/messages/",
                                image,
                                "photo",
                                body: {"message_type": "photo"});
                            fetchMessages();
                          }
                        }
                      },
                    ),
                    FloatingActionButton(
                      backgroundColor: Theme.of(context).primaryColor,
                      heroTag: null,
                      child: const Icon(
                        Icons.video_camera_back_outlined,
                        size: 32,
                      ),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        ImageSource? source = await _showMediaOptions(context);
                        if (source != null) {
                          XFile? video = await picker.pickVideo(source: source);
                          if (video != null) {
                            await sendFileWithMultipart(
                                "POST",
                                "dispatch/incidents/${widget.incidentId}/messages/",
                                video,
                                "video",
                                body: {"message_type": "video"});
                            fetchMessages();
                          }
                        }
                      },
                    ),
                    // FloatingActionButton(
                    //   backgroundColor: Theme.of(context).primaryColor,
                    //   heroTag: null,
                    //   child: const Icon(Icons.mic_rounded),
                    //   onPressed: () {},
                    // ),
                  ],
                )
              : null,
      appBar: getAppBar(),
      body: _incident == null
          ? Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDescriptionVisible = !_isDescriptionVisible;
                    });
                  },
                  child: Container(
                    color: Colors.grey[100],
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _incident?.name ?? '',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Система: ${_incident?.point?.name ?? 'Не назначена'}',
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ответственный: ${_incident?.responsibleUser?.displayName ?? 'Не назначен'}',
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Статус: ${_incident?.displayStatus ?? 'Не назначен'}',
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        Icon(_isDescriptionVisible
                            ? Icons.expand_less
                            : Icons.expand_more),
                      ],
                    ),
                  ),
                ),
                if (_isDescriptionVisible)
                  Container(
                    width: double.infinity,
                    color: Colors.grey[100],
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_incident?.description ?? '',
                              style: TextStyle(fontSize: 16)),
                          SizedBox(height: 8),
                          Text(
                              'Автор: ${_incident?.author?.displayName ?? 'Неизвестно'}',
                              style: TextStyle(fontSize: 14)),
                          SizedBox(height: 4),
                          Text(
                            'Уровень: ${_incident?.level ?? 'Не назначен'}',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                              'Дата создания: ${DateFormat('dd.MM.yyyy HH:mm').format(_incident!.createdAt.toLocal())}',
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    reverse: true,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    itemCount: _messages.length,
                    separatorBuilder: (BuildContext context, int index) {
                      if (!_isLoadingMessages || index != 0) {
                        return const Divider(height: 5);
                      }
                      return Container();
                    },
                    itemBuilder: (context, index) {
                      if (_isLoadingMessages && index == 0) {
                        return _isLoadingMessages
                            ? Center(child: CircularProgressIndicator())
                            : SizedBox.shrink();
                      }
                      final message = _messages[index];
                      return ListTile(
                        title: Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.user != null)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    message.user!.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              _buildMessage(message,
                                  isSystem: message.user == null)
                            ],
                          ),
                        ),
                        subtitle: Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(DateFormat('dd.MM.yyyy HH:mm')
                              .format(DateTime.parse(message.createdAt).toLocal())),
                        ),
                      );
                    },
                  ),
                ),
                if (_incident != null &&
                    _incident!.status == "waiting_to_be_accepted")
                  Center(
                    child: StyledWideButton(
                      text: "Принять инцидент",
                      height: 100.0,
                      bg: Theme.of(context).primaryColor,
                      fg: Theme.of(context).dialogBackgroundColor,
                      onPressed: () async {
                        try {
                          await sendRequest("POST",
                              "dispatch/incidents/${widget.incidentId}/change_status/",
                              body: {"status": "opened"});
                          raiseSuccessFlushbar(
                              context, "Инцидент принят вами.");
                          fetchAll();
                        } catch (error) {
                          raiseErrorFlushbar(context,
                              "Инцидент не удалось принять. Его может принять только ответственный.");
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({required this.videoUrl});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _controller,
          autoPlay: true,
          looping: false,
          allowFullScreen: false,
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Видео"),
        titleTextStyle: const TextStyle(color: Colors.white),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Center(
        child: _chewieController != null
            ? Chewie(
                controller: _chewieController!,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class IncidentStatisticsScreen extends StatefulWidget {
  @override
  _IncidentStatisticsScreenState createState() =>
      _IncidentStatisticsScreenState();
}

class _IncidentStatisticsScreenState extends State<IncidentStatisticsScreen> {
  IncidentStatistics? _statistics;
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedStatus;
  int? _selectedPointId;
  int? _selectedResponsibleUserId;
  int? _selectedAuthorId;

  List<DutyPoint> _points = [];
  List<User> _users = [];
  List<String> _statusOptions = [
    'opened',
    'closed',
    'force_closed',
    'waiting_to_be_accepted',
  ];
  Map<String, String> _statusLabels = {
    'opened': 'В работе',
    'closed': 'Выполнено',
    'force_closed': 'Ненадлежащее выполнение',
    'waiting_to_be_accepted': 'В ожидании принятия',
  };

  @override
  void initState() {
    super.initState();
    _fetchFilterData();
  }

  Future<void> _fetchFilterData() async {
    try {
      List<dynamic> pointsResponse =
          await sendRequest("GET", "dispatch/duty_points/");
      List<dynamic> usersResponse = await sendRequest("GET", "users/");

      setState(() {
        _points = DutyPoint.fromJsonList(pointsResponse);
        _users = User.fromJsonList(usersResponse);
      });
    } catch (e) {
      raiseErrorFlushbar(context, 'Не удалось загрузить данные для фильтров');
    }
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String url = "dispatch/incidents/statistics/?";
      List<String> params = [];

      if (_startDate != null) {
        params.add(
            "start_date=${_startDate!.toIso8601String().split('T')[0]}");
      }
      if (_endDate != null) {
        params.add("end_date=${_endDate!.toIso8601String().split('T')[0]}");
      }
      if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
        params.add("status=$_selectedStatus");
      }
      if (_selectedPointId != null) {
        params.add("point_id=$_selectedPointId");
      }
      if (_selectedResponsibleUserId != null) {
        params.add("responsible_user_id=$_selectedResponsibleUserId");
      }
      if (_selectedAuthorId != null) {
        params.add("author_id=$_selectedAuthorId");
      }

      url += params.join("&");

      Map<String, dynamic> response = await sendRequest("GET", url);
      setState(() {
        _statistics = IncidentStatistics.fromJson(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      raiseErrorFlushbar(context, 'Не удалось загрузить статистику');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Статистика по инцидентам"),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Фильтры
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Фильтры",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectDate(context, true),
                                  icon: Icon(Icons.calendar_today),
                                  label: Text(_startDate == null
                                      ? "Дата начала"
                                      : "${_startDate!.day}.${_startDate!.month}.${_startDate!.year}"),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _selectDate(context, false),
                                  icon: Icon(Icons.calendar_today),
                                  label: Text(_endDate == null
                                      ? "Дата окончания"
                                      : "${_endDate!.day}.${_endDate!.month}.${_endDate!.year}"),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: "Статус",
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedStatus,
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text("Все статусы"),
                              ),
                              ..._statusOptions.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(_statusLabels[status] ?? status),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value;
                              });
                            },
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            decoration: InputDecoration(
                              labelText: "Система дежурства",
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedPointId,
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text("Все системы"),
                              ),
                              ..._points.map((point) {
                                return DropdownMenuItem<int>(
                                  value: point.id,
                                  child: Text(point.name),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPointId = value;
                              });
                            },
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            decoration: InputDecoration(
                              labelText: "Ответственный дежурный",
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedResponsibleUserId,
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text("Все дежурные"),
                              ),
                              ..._users.map((user) {
                                return DropdownMenuItem<int>(
                                  value: user.id,
                                  child: Text(user.displayName),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedResponsibleUserId = value;
                              });
                            },
                          ),
                          SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            decoration: InputDecoration(
                              labelText: "Автор",
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedAuthorId,
                            items: [
                              DropdownMenuItem<int>(
                                value: null,
                                child: Text("Все авторы"),
                              ),
                              ..._users.map((user) {
                                return DropdownMenuItem<int>(
                                  value: user.id,
                                  child: Text(user.displayName),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedAuthorId = value;
                              });
                            },
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _fetchStatistics,
                              child: Text("Сформировать отчет"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Статистика
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else if (_statistics != null) ...[
                    // Общие метрики
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Метрики",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 12),
                            _buildMetricRow(
                                "Всего инцидентов", "${_statistics!.totalCount}"),
                            _buildMetricRow("Средний уровень эскалации",
                                "${_statistics!.averageLevel}"),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Статистика по статусам
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Статистика по статусам",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 12),
                            ..._statistics!.statusStatistics.entries.map((entry) {
                              return _buildStatRow(
                                  entry.value.display,
                                  "${entry.value.count} (${entry.value.percentage.toStringAsFixed(1)}%)");
                            }),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Статистика по критичности
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Статистика по критичности",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 12),
                            _buildStatRow(
                                "Критичные",
                                "${_statistics!.criticalStatistics.critical.count} (${_statistics!.criticalStatistics.critical.percentage.toStringAsFixed(1)}%)"),
                            _buildStatRow(
                                "Некритичные",
                                "${_statistics!.criticalStatistics.nonCritical.count} (${_statistics!.criticalStatistics.nonCritical.percentage.toStringAsFixed(1)}%)"),
                          ],
                        ),
                      ),
                    ),
                    if (_statistics!.pointStatistics.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Статистика по системам дежурства",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 12),
                              ..._statistics!.pointStatistics.entries.map((entry) {
                                return _buildStatRow(
                                    entry.value.name,
                                    "${entry.value.count} (${entry.value.percentage.toStringAsFixed(1)}%)");
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_statistics!.responsibleStatistics.isNotEmpty) ...[
                      SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Статистика по ответственным дежурным",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 12),
                              ..._statistics!.responsibleStatistics.entries
                                  .map((entry) {
                                return _buildStatRow(
                                    entry.value.name,
                                    "${entry.value.count} (${entry.value.percentage.toStringAsFixed(1)}%)");
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 16),
                    // Список инцидентов
                    Text("Список инцидентов (${_statistics!.incidents.length})",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    ..._statistics!.incidents.map((incident) {
                      return Card(
                        margin: EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(incident.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                  "Описание: ${incident.description.length > 50 ? incident.description.substring(0, 50) + '...' : incident.description}"),
                              SizedBox(height: 4),
                              Text("Автор: ${incident.authorName ?? '-'}"),
                              Text(
                                  "Ответственный: ${incident.responsibleUserName ?? '-'}"),
                              Text("Система: ${incident.pointName ?? '-'}"),
                              Text(
                                  "Статус: ${_statusLabels[incident.status] ?? incident.status}"),
                              Text("Уровень: ${incident.level}"),
                              Text(
                                  "Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(incident.createdAt.toLocal())}"),
                            ],
                          ),
                          trailing: incident.isCritical
                              ? Icon(Icons.warning, color: Colors.red)
                              : null,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16)),
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16))),
          Text(value, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
