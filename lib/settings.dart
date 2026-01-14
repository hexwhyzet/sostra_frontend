import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_reader/botton.dart';
import 'package:qr_reader/universal_safe_area.dart';
import 'package:qr_reader/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> _getSetting(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(key);
}

Future<void> _setSetting(String key, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<void> _clearSetting(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(key);
}

class SettingAccessor {
  String settingKey = 'key';

  SettingAccessor({required this.settingKey});

  Future<String?> getSetting() async {
    return await _getSetting(settingKey);
  }

  Future<void> setSetting(String value) {
    return _setSetting(settingKey, value);
  }

  Future<void> clearSetting() {
    return _clearSetting(settingKey);
  }
}

class DefaultSettingAccessor {
  String settingKey = 'key';
  String defaultValue = 'value';

  DefaultSettingAccessor(
      {required this.settingKey, required this.defaultValue});

  Future<String> getSetting() async {
    return await _getSetting(settingKey) ?? defaultValue;
  }

  Future<void> setSetting(String value) {
    return _setSetting(settingKey, value);
  }

  Future<void> clearSetting() {
    return _clearSetting(settingKey);
  }
}

class Config {
  SettingAccessor code = SettingAccessor(settingKey: 'code');
  DefaultSettingAccessor hostname = DefaultSettingAccessor(
      settingKey: 'hostname', defaultValue: 'appsostra.ru');
  SettingAccessor userId = SettingAccessor(settingKey: 'userId');
  SettingAccessor authToken = SettingAccessor(settingKey: 'AUTH_TOKEN');
  SettingAccessor refreshToken = SettingAccessor(settingKey: 'AUTH_REFRESH_TOKEN');
}

final config = Config();

class SettingsScreen extends StatefulWidget {
  final VoidCallback? logoutCallback;

  SettingsScreen({required this.logoutCallback});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController _controller = TextEditingController();
  String appVersion = "";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    String buildNumber = packageInfo.buildNumber;
    setState(() {
      appVersion = "$version ($buildNumber)";
    });
  }

  void _loadSettings() async {
    _controller.text = await config.hostname.getSetting();
  }

  void _saveSettings() async {
    await config.hostname.setSetting(_controller.text);
    FocusScope.of(context).unfocus();
  }

  void _logout() {
    if (widget.logoutCallback != null) {
      widget.logoutCallback!();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        toolbarHeight: 65,
        titleTextStyle: TextStyle(color: Theme.of(context).canvasColor),
        title: Text('Настройки'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              StyledWideButton(
                text: "Профиль",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ProfileScreen()),
                  );
                },
                bg: Theme.of(context).primaryColor,
                fg: Colors.white,
                height: 50,
                textWidth: 0.5,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _controller,
                decoration: InputDecoration(labelText: 'Hostname'),
              ),
              SizedBox(height: 20),
              StyledWideButton(
                text: "Сохранить",
                onPressed: _saveSettings,
                bg: Theme.of(context).dialogBackgroundColor,
                fg: Theme.of(context).primaryColor,
                height: 50,
                textWidth: 0.5,
              ),
              Spacer(flex: 1),
              Text(
                "Версия приложения: $appVersion",
              ),
              if (widget.logoutCallback != null)
                Column(
                  children: [
                    SizedBox(height: 10),
                    StyledWideButton(
                      text: "Выйти из аккаунта",
                      onPressed: _logout,
                      bg: Colors.red,
                      fg: Colors.white,
                      height: 50,
                    ),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}
