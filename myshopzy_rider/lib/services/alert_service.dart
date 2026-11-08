import 'dart:async';
import 'dart:typed_data' show Int64List, Uint8List;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../constants/app_config.dart';
import '../constants/translations.dart';

class AlertService {
  static const _notificationId = 7101;
  static const _channelId = 'new_orders';
  static const _permissionPromptedKey = 'new_order_notification_prompted';
  static const _vibrationPattern = [0, 700, 400, 700, 400];

  final AudioPlayer _player = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _alertTimer;
  Timer? _fallbackTimer;
  Timer? _hapticTimer;
  String? _orderId;
  bool _isRinging = false;
  bool _initialized = false;
  Future<void>? _initializing;
  String? _notifiedOrderId;
  int _generation = 0;
  VoidCallback? onNotificationTap;
  VoidCallback? onStopped;

  bool get isRinging => _isRinging;

  Future<void> init() => _initializing ??= _init();

  Future<void> _init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.sonification,
          ),
        ));
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _player.setAudioContext(AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {},
          ),
        ));
      }
    } catch (error) {
      debugPrint('Could not initialize new-order audio: $error');
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        const settings = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        );
        await _notifications.initialize(
          settings: settings,
          onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
        );
        if (defaultTargetPlatform == TargetPlatform.android) {
          final android = _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          await android?.createNotificationChannel(AndroidNotificationChannel(
            _channelId,
            T.t('new_order_alert'),
            description: T.t('new_order_channel_desc'),
            importance: Importance.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('new_order'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList(_vibrationPattern),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ));
        }
      } catch (error) {
        debugPrint('Could not initialize new-order notifications: $error');
      }
    }
    _initialized = true;
  }

  Future<void> unlockAudio() async {
    await init();
    if (!kIsWeb) return;
    try {
      const silentWave = <int>[
        82,
        73,
        70,
        70,
        38,
        0,
        0,
        0,
        87,
        65,
        86,
        69,
        102,
        109,
        116,
        32,
        16,
        0,
        0,
        0,
        1,
        0,
        1,
        0,
        64,
        31,
        0,
        0,
        64,
        31,
        0,
        0,
        1,
        0,
        8,
        0,
        100,
        97,
        116,
        97,
        2,
        0,
        0,
        0,
        128,
        128,
      ];
      await _player.play(BytesSource(Uint8List.fromList(silentWave)));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await _player.stop();
    } catch (error) {
      debugPrint('Could not unlock browser audio: $error');
    }
  }

  Future<void> explainAndRequestNotificationPermission(
      BuildContext context) async {
    if (kIsWeb) return;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_permissionPromptedKey) ?? false) return;
    if (!context.mounted) return;

    final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(T.t('notification_permission_title')),
            content: Text(T.t('notification_permission_msg')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(T.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(T.t('yes')),
              ),
            ],
          ),
        ) ??
        false;
    await preferences.setBool(_permissionPromptedKey, true);
    if (!accepted || !context.mounted) return;

    try {
      await Permission.notification.request();
    } catch (error) {
      debugPrint('Could not request notification permission: $error');
    }
  }

  Future<void> startNewOrderAlert(String orderId) async {
    if (_orderId == orderId && _isRinging) return;
    final generation = ++_generation;
    await _stopResources();
    await init();
    if (generation != _generation) return;
    _orderId = orderId;
    _isRinging = true;
    _alertTimer = Timer(
      const Duration(seconds: AppConfig.alertMaxSeconds),
      () => unawaited(stop()),
    );
    if (!kIsWeb) {
      try {
        await WakelockPlus.enable();
      } catch (error) {
        debugPrint('Could not keep screen awake for order alert: $error');
      }
      if (!_isCurrent(generation)) return;
      await _startVibration();
    }
    await _playLoop(generation);
  }

  Future<void> _playLoop(int generation) async {
    if (!_isCurrent(generation)) return;
    try {
      await _player.play(AssetSource('sounds/new_order.mp3'));
    } catch (error) {
      debugPrint('New-order audio unavailable; using system alert: $error');
      if (_isCurrent(generation)) _startFallback(generation);
    }
  }

  void _startFallback(int generation) {
    if (!_isCurrent(generation) || _fallbackTimer != null) return;
    unawaited(_playSystemAlert());
    _fallbackTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_isCurrent(generation)) {
        unawaited(_playSystemAlert());
      }
    });
  }

  Future<void> _playSystemAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (error) {
      debugPrint('System alert sound failed: $error');
    }
  }

  Future<void> _startVibration() async {
    if (kIsWeb) return;
    try {
      final hasAmplitude = await Vibration.hasAmplitudeControl();
      if (hasAmplitude) {
        await Vibration.vibrate(
          pattern: _vibrationPattern,
          repeat: 0,
          amplitude: 255,
        );
      } else {
        _hapticTimer?.cancel();
        HapticFeedback.heavyImpact();
        _hapticTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
          if (_isRinging) HapticFeedback.heavyImpact();
        });
      }
    } catch (error) {
      debugPrint('Could not vibrate for new order: $error');
      _hapticTimer?.cancel();
      _hapticTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (_isRinging) HapticFeedback.heavyImpact();
      });
    }
  }

  Future<void> showBackgroundNotification({
    required String orderId,
    required String body,
  }) async {
    if (kIsWeb || !_initialized || !_isRinging || _notifiedOrderId == orderId) {
      return;
    }
    _notifiedOrderId = orderId;
    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        T.t('new_order_alert'),
        channelDescription: T.t('new_order_channel_desc'),
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('new_order'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(_vibrationPattern),
        ongoing: true,
        autoCancel: false,
        timeoutAfter: AppConfig.alertMaxSeconds * 1000,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: 'new_order.mp3',
      );
      await _notifications.show(
        id: _notificationId,
        title: T.t('new_order_alert'),
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
        ),
        payload: orderId,
      );
    } catch (error) {
      _notifiedOrderId = null;
      debugPrint('Could not show new-order notification: $error');
    }
  }

  Future<void> cancelBackgroundNotification() async {
    if (kIsWeb) return;
    _notifiedOrderId = null;
    try {
      await _notifications.cancel(id: _notificationId);
    } catch (error) {
      debugPrint('Could not cancel new-order notification: $error');
    }
  }

  Future<void> testAlert() async {
    if (_isRinging) return;
    await startNewOrderAlert('__test__');
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 5), () => unawaited(stop()));
  }

  Future<void> stop() async {
    ++_generation;
    await _stopResources();
  }

  Future<void> _stopResources() async {
    final wasRinging = _isRinging;
    _isRinging = false;
    _orderId = null;
    _notifiedOrderId = null;
    _alertTimer?.cancel();
    _alertTimer = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _hapticTimer?.cancel();
    _hapticTimer = null;
    try {
      await _player.stop();
    } catch (error) {
      debugPrint('Could not stop new-order audio: $error');
    }
    if (!kIsWeb) {
      try {
        await Vibration.cancel();
      } catch (error) {
        debugPrint('Could not stop new-order vibration: $error');
      }
      try {
        await WakelockPlus.disable();
      } catch (error) {
        debugPrint('Could not release new-order wakelock: $error');
      }
      try {
        await _notifications.cancel(id: _notificationId);
      } catch (error) {
        debugPrint('Could not cancel new-order notification: $error');
      }
    }
    if (wasRinging) onStopped?.call();
  }

  bool _isCurrent(int generation) => _isRinging && generation == _generation;

  Future<void> dispose() async {
    await stop();
    try {
      await _player.dispose();
    } catch (error) {
      debugPrint('Could not dispose new-order audio player: $error');
    }
  }

  // TODO: FCM push from the backend will trigger this when the app is closed.
}
