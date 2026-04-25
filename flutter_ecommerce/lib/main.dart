import 'package:flutter/material.dart';
import 'package:rivium_chat/rivium_chat.dart';
import 'package:rivium_chat_ui/rivium_chat_ui.dart';
import 'package:rivium_push/rivium_push.dart';

import 'screens/login_screen.dart';
import 'screens/orders_screen.dart';
import 'services/file_upload_service.dart';

/// RiviumChat E-commerce Example App
///
/// This example demonstrates a real-world e-commerce chat integration where:
/// - Buyers can chat with sellers about their orders
/// - Each order has its own chat room (1:1 conversation)
/// - Supports file attachments, reactions, typing indicators, and more
///
/// Features demonstrated:
/// - RiviumChatScope for client lifecycle management
/// - ChatScreen for complete chat UI
/// - Custom message bubbles with order context
/// - File upload integration
/// - Unread badges and room list
/// - Presence and typing indicators
/// - Message reactions and pinning
/// - Read receipts

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RiviumPush.init(const RiviumPushConfig(
    apiKey: 'rv_live_64e0ada5eeb66e3adf6136337802a5a34713ce4966372854',
    showNotificationInForeground: true,
  ));

  RiviumPush.onMessage((message) {
    debugPrint('RiviumPush message: ${message.title} - ${message.body}');
  });

  RiviumPush.onRegistered((deviceId) {
    debugPrint('RiviumPush registered with deviceId: $deviceId');
  });

  RiviumPush.onError((error) {
    debugPrint('RiviumPush ERROR: $error');
  });

  RiviumPush.onDetailedError((error) {
    debugPrint(
        'RiviumPush DETAILED ERROR: code=${error.code}, message=${error.message}');
  });

  RiviumPush.onNotificationTapped((notification) {
    debugPrint('Notification tapped: ${notification.data}');
  });

  runApp(const RiviumChatEcommerceApp());
}

class RiviumChatEcommerceApp extends StatefulWidget {
  const RiviumChatEcommerceApp({super.key});

  @override
  State<RiviumChatEcommerceApp> createState() => _RiviumChatEcommerceAppState();
}

class _RiviumChatEcommerceAppState extends State<RiviumChatEcommerceApp> {
  // In a real app, these would come from your auth system
  String? _currentUserId;
  String? _currentUserName;
  String? _userRole; // 'buyer' or 'seller'

  // Your RiviumChat API key (from AuthLeap dashboard)
  static const String _apiKey =
      'rv_live_64e0ada5eeb66e3adf6136337802a5a34713ce4966372854';

  void _onLogin(String userId, String userName, String role) {
    debugPrint(
        '_onLogin called: userId=$userId, userName=$userName, role=$role');
    setState(() {
      _currentUserId = userId;
      _currentUserName = userName;
      _userRole = role;
    });
    debugPrint('Calling RiviumPush.register...');
    RiviumPush.register(
        userId: userId,
        metadata: {'displayName': userName, 'role': role}).then((_) {
      debugPrint('RiviumPush.register() completed (async result returned)');
    }).catchError((e) {
      debugPrint('RiviumPush.register() FAILED: $e');
    });
    RiviumPush.getDeviceId()
        .then((id) => debugPrint('RiviumPush deviceId: $id'));
  }

  void _onLogout() {
    RiviumPush.unregister();
    setState(() {
      _currentUserId = null;
      _currentUserName = null;
      _userRole = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return MaterialApp(
        title: 'RiviumChat E-commerce Demo',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        home: LoginScreen(onLogin: _onLogin),
      );
    }

    // Create RiviumChat configuration with file uploader
    final config = RiviumChatConfig(
      apiKey: _apiKey,
      userId: _currentUserId!,
      userInfo: {
        'displayName': _currentUserName,
        'role': _userRole,
      },
      fileUploader: FileUploadService.uploadFile,
    );

    // RiviumChatScope wraps MaterialApp so all Navigator routes inherit it
    return RiviumChatScope(
      config: config,
      autoConnect: true,
      onConnected: () {
        debugPrint('RiviumChat connected!');
      },
      onError: (error) {
        debugPrint('RiviumChat error: $error');
      },
      child: MaterialApp(
        title: 'RiviumChat E-commerce Demo',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        home: OrdersScreen(
          currentUserId: _currentUserId!,
          currentUserName: _currentUserName!,
          userRole: _userRole!,
          onLogout: _onLogout,
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}
