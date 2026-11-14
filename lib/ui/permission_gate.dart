import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../platform/media_store.dart';
import 'common.dart';

/// 取得讀取音訊的權限後才顯示 [child]，並在取得權限時掃描一次音樂庫。
class PermissionGate extends ConsumerStatefulWidget {
  const PermissionGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends ConsumerState<PermissionGate> {
  PermissionStatus? _status;
  Permission _permission = Permission.audio;
  int _sdk = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // 從系統設定頁回來時重新檢查
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    _sdk = await MediaStoreChannel.sdkInt();
    // Android 13 起改用 READ_MEDIA_AUDIO
    _permission = _sdk >= 33 ? Permission.audio : Permission.storage;
    _update(await _permission.status);
  }

  Future<void> _request() async {
    final status = await _permission.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    _update(status);
  }

  void _update(PermissionStatus status) {
    if (!mounted) return;
    final wasGranted = _status?.isGranted ?? false;
    setState(() => _status = status);
    if (status.isGranted && !wasGranted) {
      if (_sdk >= 33) Permission.notification.request();
      scanLibrary(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const Scaffold();
    if (status.isGranted) return widget.child;

    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.library_music,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.permissionTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(l10n.permissionBody, textAlign: TextAlign.center),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _request,
                child: Text(
                  status.isPermanentlyDenied
                      ? l10n.openSettings
                      : l10n.grantPermission,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
