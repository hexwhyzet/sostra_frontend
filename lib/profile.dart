import 'package:flutter/material.dart';
import 'package:qr_reader/request.dart';
import 'package:qr_reader/settings.dart';

import 'data/common/user.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    try {
      Map<String, dynamic>? response = await sendRequest('GET', 'whoami/');
      if (response != null && response.containsKey('success') && response['success']) {
        setState(() {
          user = User(
            id: response['id'],
            username: response['username'] ?? '',
            firstName: response['first_name'],
            lastName: response['last_name'],
            displayName: response['display_name'] ?? response['username'] ?? '',
          );
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching user info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : user == null
              ? Center(child: Text('Не удалось загрузить информацию о пользователе'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Theme.of(context).primaryColor,
                                    child: Text(
                                      user!.displayName.isNotEmpty
                                          ? user!.displayName[0].toUpperCase()
                                          : user!.username[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 32,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user!.displayName,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (user!.username.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              'Логин: ${user!.username}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      if (user!.firstName != null && user!.firstName!.isNotEmpty)
                        _buildInfoCard('Имя', user!.firstName!),
                      if (user!.lastName != null && user!.lastName!.isNotEmpty)
                        _buildInfoCard('Фамилия', user!.lastName!),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


