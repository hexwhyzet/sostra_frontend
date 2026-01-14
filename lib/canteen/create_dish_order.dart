import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_reader/request.dart';

import '../alert.dart';
import './canteen_mini_app.dart';

class CreateDishOrderView extends StatefulWidget {
  final List<dynamic> dishes;

  const CreateDishOrderView({super.key, required this.dishes});

  @override
  State<CreateDishOrderView> createState() => _CreateDishOrderState();
}

class _CreateDishOrderState extends State<CreateDishOrderView> with WidgetsBindingObserver {
  late List<dynamic> dishes;
  List<dynamic> menu = [];
  bool isLoading = true;
  List<int> selectedDishes = [];
  final DateTime firstDate = DateTime.now().add(const Duration(days: 1));
  final DateTime lastDate = DateTime.now().add(const Duration(days: 7));
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  bool createOrderButtonEnabled = true;
  String? selectedCategory;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    dishes = widget.dishes;
    loadMenu();
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
        loadMenu();
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ru', 'RU')
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedDishes = [];
        isLoading = true;
      });
      loadMenu();
    }
  }

  Future<void> loadMenu() async {
    try {
      final date = DateFormat('yyyy-MM-dd').format(selectedDate);
      final response = await sendRequest("GET", "food/allowed_dishes/");
      setState(() {
        menu = response.where((item) => item['date'] == date).toList();
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching menu: $error');
    }
  }


  List<dynamic> get filteredDishes {
    final menuDishIds = menu.map((item) => item['dish']).toSet();

    if (selectedCategory == null || selectedCategory!.isEmpty) {
      return dishes.where((dish) => menuDishIds.contains(dish['id'])).toList();
    }
    return dishes.where((dish) => dish['category'] == selectedCategory && menuDishIds.contains(dish['id'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание заказа'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              loadMenu();
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Text(
                "Заказ блюд",
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
                    "Заказ на дату: ",
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
            SliverToBoxAdapter(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text("Выберите категорию блюд"),
                value: selectedCategory,
                onChanged: (String? value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                items: [
                  const DropdownMenuItem(value: '', child: Text("Все категории")),
                  ...dishes
                      .map((dish) => dish['category'] as String)
                      .toSet()
                      .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(getDishTypeName(category)),
                  )),
                ],
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final dish = filteredDishes[index];
                  return ListTile(
                    leading: dish['photo'] != null
                        ? Image.network(
                      dish['photo'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                        : const SizedBox(
                      width: 50,
                      height: 50,
                      child: Icon(Icons.fastfood),
                    ),
                    title: Text(dish['name']),
                    subtitle: Text(getDishTypeName(dish['category'])),
                    trailing: Checkbox(
                      value: selectedDishes.contains(dish['id']),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedDishes.add(dish['id']);
                          } else {
                            selectedDishes.remove(dish['id']);
                          }
                        });
                      },
                    ),
                  );
                },
                childCount: filteredDishes.length,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    if (!createOrderButtonEnabled) {
                      return;
                    }
                    setState(() {
                      createOrderButtonEnabled = false;
                    });
                    if (selectedDishes.isNotEmpty) {
                      try {
                        for (final dish in selectedDishes) {
                          var dict = {
                            'dish': dish,
                            'cooking_time': DateFormat('yyyy-MM-dd').format(selectedDate)
                          };
                          await sendRequest("POST", "food/orders/", body: dict);
                        }
                        if (context.mounted) {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          await raiseSuccessFlushbar(context, 'Заказ успешно создан!');
                        }
                      } catch (error) {
                        print('Error creating order: $error');
                        if (context.mounted) {
                          await raiseErrorFlushbar(context,
                              'Ошибка формирования заказа!');
                        }
                      }
                      print("Заказ оформлен на ${selectedDate.toString()}");
                    } else {
                      await raiseErrorFlushbar(context,
                          'Пожалуйста, выберите блюда для заказа');
                    }
                    if (context.mounted) {
                      setState(() {
                        createOrderButtonEnabled = true;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Заказать"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}