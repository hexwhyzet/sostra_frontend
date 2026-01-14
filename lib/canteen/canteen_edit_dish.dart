import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../request.dart';

class DishesEditImagesView extends StatefulWidget {
  const DishesEditImagesView({super.key});

  @override
  State<DishesEditImagesView> createState() => _DishesEditImagesViewState();
}

class _DishesEditImagesViewState extends State<DishesEditImagesView> with WidgetsBindingObserver {
  List<dynamic> dishes = [];
  bool isLoading = true;
  final ImagePicker _picker = ImagePicker();
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
    setState(() {
      isLoading = true;
    });
    fetchDishes();
  }

  Future<void> fetchDishes() async {
    try {
      final response = await sendRequest("GET", "food/dishes/");
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

  Future<void> _editDishPhoto(Map<String, dynamic> dish) async {
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return;

    try {
      await sendFileWithMultipart(
        "POST",
        "food/dishes/${dish['id']}/upload-photo/",
        pickedImage,
        "photo",
        body: dish,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото успешно обновлено')),
        );
      }

      refreshState();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать фото блюд'),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dishes.length,
        itemBuilder: (context, index) {
          final dish = dishes[index];
          final imageUrl = dish['photo'];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: imageUrl != null
                  ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                  : const Icon(Icons.fastfood, size: 40),
              title: Text(dish['name'] ?? 'Без названия'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editDishPhoto(dish),
              ),
            ),
          );
        },
      ),
    );
  }
}
