import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_reader/request.dart';

import 'canteen_edit_dish.dart';

class CanteenManagerMiniApp extends StatelessWidget {
  const CanteenManagerMiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Менеджер столовой'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OrderStats(),
                  ),
                );
              },
              child: const Text('Просмотр статистики по заказам'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FeedbacksPage(),
                  ),
                );
              },
              child: const Text('Просмотр отзывов'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RemovedOrdersPage(),
                  ),
                );
              },
              child: const Text('Просмотр удалённых заказов'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DishesEditImagesView(),
                  ),
                );
              },
              child: const Text('Редактировать фотграфии блюд'),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderStats extends StatefulWidget {

  const OrderStats({super.key});

  @override
  State<OrderStats> createState() => _OrderStatsState();
}

class _OrderStatsState extends State<OrderStats> with WidgetsBindingObserver {
  List<dynamic> dishes = [];
  DateTime selectedDate = DateTime.now();
  bool isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchDishes();
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
        fetchDishes();
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('ru', 'RU')
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        isLoading = true;
        selectedDate = picked;
      });
      fetchDishes();
    }
  }


  Future<void> fetchDishes() async {
    var dict = {
      'date': DateFormat('yyyy-MM-dd').format(selectedDate)
    };
    try {
      final response = await sendRequest("GET", "food/orders/aggregate_orders/", queryParams: dict);
      setState(() {
        dishes = response;
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching dishes: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика по заказам'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchDishes();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Text(
                "Статистика по заказам",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Row(
                children: [
                  const Text(
                    "Заказы на дату: ",
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd').format(selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
            ),
            isLoading ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()),) : SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final dish = dishes[index];
                  return ListTile(
                    leading: const SizedBox(width: 50, height: 50, child: Icon(Icons.fastfood),),
                    title: Text(dish['dish']),
                    subtitle: Text("Количество заказов: ${dish['total_orders']}"),
                  );
                },
                childCount: dishes.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbacksPage extends StatefulWidget {
  const FeedbacksPage({super.key});

  @override
  State<FeedbacksPage> createState() => _FeedbacksPageState();
}

class _FeedbacksPageState extends State<FeedbacksPage> with WidgetsBindingObserver {
  List<dynamic> feedbacks = [];
  List<dynamic> dishes = [];
  bool isLoadingFeedbacks = true;
  bool isLoadingDishes = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchFeedback();
    fetchDishes();
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
        fetchFeedback();
        fetchDishes();
      }
    });
  }

  Future<void> fetchFeedback() async {
    try {
      final response = await sendRequest("GET", "food/feedback/");
      setState(() {
        feedbacks = response;
        isLoadingFeedbacks = false;
      });
    } catch (error) {
      setState(() {
        isLoadingFeedbacks = false;
      });
      print('Error fetching feedbacks: $error');
    }
  }

  Future<void> fetchDishes() async {
    try {
      final response = await sendRequest("GET", "food/dishes/");
      setState(() {
        dishes = response;
        isLoadingDishes = false;
      });
    } catch (error) {
      setState(() {
        isLoadingDishes = false;
      });
      print('Error fetching dishes: $error');
    }
  }

  Map<String, dynamic>? getDishById(int id) {
    return dishes.firstWhere(
          (element) => element['id'] == id,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отзывы'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchFeedback();
              fetchDishes();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: isLoadingFeedbacks || isLoadingDishes
          ? const Center(child: CircularProgressIndicator())
          : feedbacks.isEmpty
          ? const Center(child: Text('Нет отзывов'))
          : ListView.builder(
        itemCount: feedbacks.length,
        itemBuilder: (context, index) {
          var feedback = feedbacks[index];

          String comment = feedback['comment'] ?? "";
          if (comment.length > 1000) {
            comment = "${comment.substring(0, 1000)}...";
          }

          String dishName = getDishById(feedback['dish'])?['name'] ?? "Неизвестное блюдо";

          String formattedDate = "";
          if (feedback['created_at'] != null) {
            DateTime createdAt = DateTime.parse(feedback['created_at']).toLocal();
            formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(createdAt);
          }

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Блюдо: $dishName', style: TextStyle(color: Colors.grey[700])),
                  Text('Дата: $formattedDate', style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  if (feedback['photo'] != null && feedback['photo'].isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        feedback['photo'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class RemovedOrdersPage extends StatefulWidget {
  const RemovedOrdersPage({super.key});

  @override
  State<RemovedOrdersPage> createState() => _RemovedOrdersPageState();
}

class _RemovedOrdersPageState extends State<RemovedOrdersPage> with WidgetsBindingObserver {
  List<dynamic> orders = [];
  List<dynamic> dishes = [];
  bool isLoadingRemovedOrders = true;
  bool isLoadingDishes = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchOrders();
    fetchDishes();
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
        fetchOrders();
        fetchDishes();
      }
    });
  }

  Future<void> fetchOrders() async {
    try {
      final response = await sendRequest("GET", "food/removed_orders/");
      setState(() {
        orders = response;
        isLoadingRemovedOrders = false;
      });
    } catch (error) {
      setState(() {
        isLoadingRemovedOrders = false;
      });
      print('Error fetching removed orders: $error');
    }
  }

  Future<void> fetchDishes() async {
    try {
      final response = await sendRequest("GET", "food/dishes/");
      setState(() {
        dishes = response;
        isLoadingDishes = false;
      });
    } catch (error) {
      setState(() {
        isLoadingDishes = false;
      });
      print('Error fetching dishes: $error');
    }
  }

  Map<String, dynamic>? getDishById(int id) {
    return dishes.firstWhere(
          (element) => element['id'] == id,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Удалённые заказы'),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                fetchOrders();
                fetchDishes();
              },
              tooltip: 'Обновить',
            ),
          ],
        ),
        body: isLoadingRemovedOrders || isLoadingDishes ? const Center(child: CircularProgressIndicator()) :
        orders.isEmpty ? const Center(child: Text('Нет удалённых заказов')) :
        ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            String comment = orders[index]['comment'] ?? "";
            if (comment.length > 1000) {
              comment = "${comment.substring(0, 1000)}...";
            }
            return ListTile(
              title: Text(
                'Блюдо: ${getDishById(orders[index]['dish'])?['name']}'),
              subtitle: Text(
                'Причина: ${orders[index]["deletion_reason"]??""}\n'
                    'Дата: ${orders[index]["cooking_time"]??""}\n',
              ),
            );
          },
        ));
  }
}
