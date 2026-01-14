import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_reader/canteen/create_dish_order.dart';
import 'package:qr_reader/request.dart';

import '../alert.dart';
import 'package:qr_reader/canteen/canteen_manager_mini_app.dart';

String getDishTypeName(String? dishType) {
  switch (dishType?.toLowerCase()) {
    case 'first_course':
      return 'Первое блюдо';
    case 'side_dish':
      return 'Гарнир';
    case 'main_course':
      return 'Второе блюдо';
    case 'salad':
      return 'Салат';
    case 'drink':
      return 'Напиток';
    default:
      return 'Неизвестный тип';
  }
}

class CanteenMiniApp extends StatelessWidget {
  const CanteenMiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Столовая'),
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
                    builder: (context) => const CanteenOrdersMiniApp(),
                  ),
                );
              },
              child: const Text('Просмотр заказов'),
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
          ],
        ),
      ),
    );
  }
}

class CanteenOrdersMiniApp extends StatefulWidget {
  const CanteenOrdersMiniApp({super.key});

  @override
  State<CanteenOrdersMiniApp> createState() => _CanteenOrdersMiniAppState();
}

class _CanteenOrdersMiniAppState extends State<CanteenOrdersMiniApp> with WidgetsBindingObserver {
  List<dynamic> dishes = [];
  List<dynamic> orders = [];
  bool isLoadingDishes = true;
  bool isLoadingOrders = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshState();
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
        refreshState();
      }
    });
  }

  void refreshState() {
    isLoadingOrders = true;
    isLoadingDishes = true;
    fetchOrders();
    fetchDishes();
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

  Future<void> fetchOrders() async {
    try {
      final response = await sendRequest("GET", "food/orders/");
      setState(() {
        orders = response;
        isLoadingOrders = false;
      });
    } catch (error) {
      setState(() {
        isLoadingOrders = false;
      });
      print('Error fetching orders: $error');
    }
  }

  Map<String, List<dynamic>> groupOrdersByDay() {
    Map<String, List<dynamic>> groupedOrders = {};
    for (var order in orders) {
      final date = order['cooking_time'].split('T')[0];
      if (!groupedOrders.containsKey(date)) {
        groupedOrders[date] = [];
      }
      groupedOrders[date]!.add(order);
    }
    return groupedOrders;
  }

  void _openOrdersForDay(String date, List<dynamic> dayOrders) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrdersForDayView(
          date: date,
          orders: dayOrders,
          dishes: dishes,
        ),
      ),
    );
    setState(() {
      isLoadingOrders = true;
    });
    refreshState();
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrders = groupOrdersByDay();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canteen Mini App'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              refreshState();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: isLoadingDishes || isLoadingOrders
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Заказы по дням',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: groupedOrders.keys.length,
                itemBuilder: (context, index) {
                  final date = groupedOrders.keys.elementAt(index);
                  final dayOrders = groupedOrders[date]!;
                  return ListTile(
                    title: Text('Дата: $date'),
                    subtitle: Text('Количество заказов: ${dayOrders.length}'),
                    onTap: () => _openOrdersForDay(date, dayOrders),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isLoadingDishes || isLoadingOrders
          ? null
          : FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateDishOrderView(dishes: dishes),
          ),
        ).then((result) {
          refreshState();
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class OrdersForDayView extends StatefulWidget {
  final String date;
  final List<dynamic> orders;
  final List<dynamic> dishes;

  const OrdersForDayView({
    required this.date,
    required this.orders,
    required this.dishes,
    super.key,
  });

  @override
  State<OrdersForDayView> createState() => _OrdersForDayViewState();
}

class _OrdersForDayViewState extends State<OrdersForDayView> with WidgetsBindingObserver {
  Timer? _refreshTimer;
  List<dynamic> orders = [];
  List<dynamic> dishes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    orders = widget.orders;
    dishes = widget.dishes;
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
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    try {
      final ordersResponse = await sendRequest("GET", "food/orders/");
      final dishesResponse = await sendRequest("GET", "food/dishes/");
      setState(() {
        orders = ordersResponse.where((order) {
          final orderDate = order['cooking_time'].split('T')[0];
          return orderDate == widget.date;
        }).toList();
        dishes = dishesResponse;
      });
    } catch (error) {
      print('Error refreshing data: $error');
    }
  }

  Map<String, dynamic>? _getDishById(int id) {
    return dishes.firstWhere(
          (element) => element['id'] == id,
      orElse: () => null,
    );
  }

  Future<void> _deleteOrder(BuildContext context, dynamic order, String comment) async {
    try {
      await sendRequest(
          "DELETE", "food/orders/${order['id']}/", body: {'reason': comment});
      if (context.mounted) {
        await raiseSuccessFlushbar(context, "Блюдо успешно удалено!");
      }
    } catch (e) {
      if (context.mounted) {
        await raiseErrorFlushbar(context, "Ошибка удаления блюда!");
      }
    }
  }

  void showDeleteConfirmationDialog(BuildContext context, dynamic order) {
    final TextEditingController commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить блюдо'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Вы уверены, что хотите удалить это блюдо?'),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Причина удаления',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                final comment = commentController.text.trim();
                Navigator.pop(context);
                Navigator.pop(context);
                await _deleteOrder(context, order, comment);
                _refreshData();
              },
              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказы за ${widget.date}'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _refreshData();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final dish = _getDishById(order['dish']);
          return ListTile(
            leading: dish?['photo'] != null
                ? Image.network(
              dish?['photo'],
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            )
                : const SizedBox(width: 50, height: 50, child: Icon(Icons.fastfood)),
            title: Text(dish?['name'] ?? 'Неизвестное блюдо'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.feedback, color: Colors.blue),
                  onPressed: () async {
                    await showReviewDialog(context, order['dish']);
                    _refreshData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => showDeleteConfirmationDialog(context, order),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Future<void> showReviewDialog(BuildContext context, int dishId) async {
  final TextEditingController reviewController = TextEditingController();
  final ImagePicker picker = ImagePicker();
  XFile? pickedImage;
  bool isSubmitting = false;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Оставить отзыв на блюдо'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reviewController,
                  decoration: const InputDecoration(hintText: 'Напишите свой отзыв здесь...'),
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                pickedImage != null
                    ? Image.file(File(pickedImage!.path), height: 100)
                    : const SizedBox(),
                TextButton.icon(
                  onPressed: () async {
                    final image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setState(() {
                        pickedImage = image;
                      });
                    }
                  },
                  icon: const Icon(Icons.photo),
                  label: const Text("Добавить фото"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (isSubmitting) return;
                  Navigator.pop(context);
                },
                child: const Text('Отменить'),
              ),
              TextButton(
                onPressed: () async {
                  if (isSubmitting) return;
                  setState(() {
                    isSubmitting = true;
                  });

                  final review = reviewController.text;
                  if (review.isEmpty) {
                    await raiseErrorFlushbar(context, "Введите текст отзыва");
                    setState(() {
                      isSubmitting = false;
                    });
                    return;
                  }

                  var dict = {
                    "dish": dishId.toString(),
                    "comment": review,
                  };

                  try {
                    if (pickedImage == null) {
                      await sendRequest(
                        "POST",
                        "food/feedback/",
                        body: {
                          "dish": dishId.toString(),
                          "comment": review,
                          "photo": null,
                        },
                      );
                    } else {
                      await sendFileWithMultipart(
                        "POST",
                        "food/feedback/",
                        pickedImage!,
                        "photo",
                        body: {
                          "dish": dishId.toString(),
                          "comment": review,
                        },
                      );
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                      await raiseSuccessFlushbar(context, "Отзыв успешно отправлен!");
                    }
                  } catch (e) {
                    if (context.mounted) {
                      await raiseErrorFlushbar(context, "Ошибка отправки отзыва!");
                    }
                  }

                  if (context.mounted) {
                    setState(() {
                      isSubmitting = false;
                    });
                  }
                },
                child: const Text('Отправить'),
              ),
            ],
          );
        },
      );
    },
  );
}