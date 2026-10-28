import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'scoped_push_route.dart';

class FirebaseRuntimeConfig {
  const FirebaseRuntimeConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.storageBucket,
    this.iosBundleId,
  });

  factory FirebaseRuntimeConfig.fromEnvironment() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
    const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
    return FirebaseRuntimeConfig(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
    );
  }

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? storageBucket;
  final String? iosBundleId;

  bool get hasAnyValue =>
      apiKey.isNotEmpty ||
      appId.isNotEmpty ||
      messagingSenderId.isNotEmpty ||
      projectId.isNotEmpty ||
      (storageBucket?.isNotEmpty ?? false) ||
      (iosBundleId?.isNotEmpty ?? false);

  bool get isConfigured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  FirebaseOptions get options => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket,
        iosBundleId: iosBundleId,
      );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _firebaseReady = false;
  final Set<String> _organizationIds = <String>{};
  final Set<String> _deviceIds = <String>{};
  String? _currentToken;
  final ScopedPushMailbox _routeMailbox = ScopedPushMailbox();
  ValueChanged<String>? _routeHandler;
  String? _activeRouteOrganizationId;
  String? _activeRouteUserId;
  String? _registeredUserId;
  int _registrationEpoch = 0;

  bool get isFirebaseReady => _firebaseReady;

  Future<void> initializeFirebase() async {
    final config = FirebaseRuntimeConfig.fromEnvironment();
    if (!config.hasAnyValue) return;
    if (!config.isConfigured) {
      throw StateError(
        'Firebase push configuration is incomplete. Provide FIREBASE_API_KEY, '
        'FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID and FIREBASE_PROJECT_ID.',
      );
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: config.options);
    }
    _firebaseReady = true;

    _tokenRefreshSubscription ??=
        FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      _currentToken = token;
      for (final organizationId in _organizationIds) {
        await _registerToken(organizationId, token);
      }
    });

    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleOpenedMessage(initialMessage);
  }

  Future<void> registerCurrentWorkspace({
    required String organizationId,
  }) async {
    if (!_firebaseReady || organizationId.isEmpty) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final epoch = ++_registrationEpoch;
    // A mobile session with multiple memberships is currently blocked from
    // using unscoped operational RPCs. Never subscribe its handset to all
    // tenants or silently choose a first membership for push registration.
    final memberships = await client
        .from('organization_members')
        .select('organization_id')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .limit(2);
    if (epoch != _registrationEpoch ||
        client.auth.currentUser?.id != user.id) {
      return;
    }
    if (memberships.length != 1 ||
        memberships.single['organization_id'] != organizationId) {
      _registeredUserId = null;
      _organizationIds.clear();
      return;
    }
    _registeredUserId = user.id;
    _organizationIds
      ..clear()
      ..add(organizationId);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsReady = await _waitForApnsToken();
      if (!apnsReady) return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (epoch != _registrationEpoch ||
        client.auth.currentUser?.id != user.id ||
        token == null ||
        token.trim().isEmpty) {
      return;
    }
    _currentToken = token;
    await _registerToken(organizationId, token);
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) return true;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  Future<void> _registerToken(String organizationId, String token) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != _registeredUserId ||
        !_organizationIds.contains(organizationId)) {
      return;
    }
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.iOS => 'ios',
            _ => 'android',
          };
    final value = await client.rpc(
      'notification_register_device',
      params: {
        'p_organization_id': organizationId,
        'p_platform': platform,
        'p_device_token': token,
        'p_device_name': 'FactoryOS ${defaultTargetPlatform.name}',
      },
    );
    if (value is String && value.isNotEmpty) _deviceIds.add(value);
  }

  void attachRouteHandler(
    ValueChanged<String> handler, {
    required String organizationId,
    required String userId,
  }) {
    _routeHandler = handler;
    _activeRouteOrganizationId = organizationId;
    _activeRouteUserId = userId;
    final pending = _routeMailbox.consumeFor(
      organizationId: organizationId,
      recipientUserId: userId,
    );
    if (pending != null) {
      scheduleMicrotask(() {
        if (identical(_routeHandler, handler) &&
            _activeRouteOrganizationId == organizationId &&
            _activeRouteUserId == userId &&
            Supabase.instance.client.auth.currentUser?.id == userId) {
          handler(pending);
        }
      });
    }
  }

  void detachRouteHandler(ValueChanged<String> handler) {
    if (!identical(_routeHandler, handler)) return;
    _routeHandler = null;
    _activeRouteOrganizationId = null;
    _activeRouteUserId = null;
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final route = ScopedPushRoute.fromData(message.data);
    if (route == null) return;
    final handler = _routeHandler;
    if (handler == null) {
      _routeMailbox.store(route);
    } else if (route.matches(
          organizationId: _activeRouteOrganizationId ?? '',
          recipientUserId: _activeRouteUserId ?? '',
        ) &&
        Supabase.instance.client.auth.currentUser?.id ==
            route.recipientUserId) {
      handler(route.actionRoute);
    }
  }

  Future<void> disableCurrentDevice() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    final token = _currentToken;
    if (token != null && token.isNotEmpty) {
      try {
        await client.rpc(
          'notification_disable_current_device',
          params: {'p_device_token': token},
        );
        _deviceIds.clear();
        return;
      } catch (_) {
        // Backward-compatible fallback for deployments not yet on migration 0040.
      }
    }

    for (final deviceId in _deviceIds.toList(growable: false)) {
      await client.rpc(
        'notification_disable_device',
        params: {'p_device_id': deviceId},
      );
    }
    _deviceIds.clear();
  }

  Future<void> signOut() async {
    try {
      await disableCurrentDevice();
    } finally {
      ++_registrationEpoch;
      _organizationIds.clear();
      _registeredUserId = null;
      _currentToken = null;
      _routeMailbox.clear();
      _routeHandler = null;
      _activeRouteOrganizationId = null;
      _activeRouteUserId = null;
      await Supabase.instance.client.auth.signOut();
    }
  }
}
