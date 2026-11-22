// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'hive_core.dart';
import 'platform_node.dart';
import 'secure_file.dart';
import 'ui/hivenet_ui.dart';
import 'transfer_experience.dart';
import 'identity.dart';

const _port = 8765;
final themeMode = ValueNotifier(ThemeMode.dark);
void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeMode,
    builder: (_, mode, _) => MaterialApp(
      title: 'HiveNet',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const Dashboard(),
    ),
  );
}

/*
  int tab = 0;
  int get onlineCount => peers.where((p) => p.online).length;
  int get pooledFree => peers.where((p) => p.online).fold(0, (n, p) => n + p.free);

  Widget _page(BuildContext context, String title, List<Widget> children) =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 110), children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ...children,
      ]);

  Widget _summary(BuildContext context) => HnCard(child: Wrap(spacing: 20, runSpacing: 16, children: [
    _stat(context, Icons.storage_outlined, size(pooledFree), 'Pooled free'),
    _stat(context, Icons.devices_outlined, '$onlineCount / ${peers.length}', 'Peers online'),
    _stat(context, Icons.photo_library_outlined, '${gallery.length}', 'Distributed images'),
  ]));
  Widget _stat(BuildContext context, IconData icon, String value, String label) => SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 10), Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), Text(label, style: Theme.of(context).textTheme.labelMedium)]));

  Widget _storagePage(BuildContext c) => _page(c, 'Storage', [_summary(c), const SectionTitle('Node capacity'), ...peers.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.dns_outlined, color: p.online ? Colors.teal : Theme.of(c).colorScheme.error), title: Text(p.id ?? p.host), subtitle: Text(p.online ? '${size(p.free)} available • ${p.host}:$_port' : '${p.host}:$_port unavailable'), trailing: StatusPill(online: p.online, label: p.online ? 'Live' : 'Offline'))))])];
  Widget _peersPage(BuildContext c) => _page(c, 'Peers', [Text('Live network telemetry • tap a connected peer to browse its files.', style: Theme.of(c).textTheme.bodyMedium), const SizedBox(height: 12), ...peers.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, onTap: p.online ? () => browsePeer(p) : null, leading: Icon(p.online ? Icons.lan_outlined : Icons.portable_wifi_off_outlined), title: Text(p.id ?? p.host), subtitle: Text('${p.host}:$_port\n${p.online ? '${p.latencyMs ?? '?'} ms • ${(p.reliability * 100).toStringAsFixed(0)}% reliability • ${size(p.free)} free' : 'Offline'}'), isThreeLine: true, trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { setState(() => peers.remove(p)); await savePeers(); }))))) ]);
  Widget _galleryPage(BuildContext c) => _page(c, 'Gallery', [Text('${gallery.length} images discovered across responsive peers.'), const SizedBox(height: 12), ...gallery.map((g) => Padding(padding: const EdgeInsets.only(bottom: 10), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, onTap: () => showDistributedImage(g), leading: Container(width: 50, height: 50, decoration: BoxDecoration(color: Theme.of(c).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.image_outlined)), title: Text(g.meta.name), subtitle: Text('${size(g.meta.originalBytes)} → ${size(g.meta.bytes)} • ${g.meta.id.substring(0, 12)}…\n${g.locations.length} replica location(s): ${g.locations.map((p) => p.id ?? p.host).join(', ')}'), isThreeLine: true))))]);
  Widget _routerPage(BuildContext c) { final selected = selectReplicaPeers(peers, (p) => PeerCandidate(key: p.key, freeBytes: p.free, latencyMs: p.latencyMs, online: p.online, successes: p.successes, failures: p.failures), 0); return _page(c, 'Smart Router', [HnCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.account_tree_outlined), const SizedBox(width: 10), const Text('Two independent replicas', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), StatusPill(online: selected.length == 2, label: selected.length == 2 ? 'Ready' : 'Needs peers')]), const SizedBox(height: 12), const Text('Scores use actual free space, probe latency, availability, and verified-transfer reliability.'), ...selected.asMap().entries.map((e) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Text('${e.key + 1}')), title: Text(e.value.id ?? e.value.host), subtitle: Text('${size(e.value.free)} free • ${e.value.latencyMs ?? '?'} ms • ${(e.value.reliability * 100).toStringAsFixed(0)}% reliable')))])), const SectionTitle('Eligible peer telemetry'), ...peers.map((p) => Padding(padding: const EdgeInsets.only(bottom: 8), child: HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: StatusPill(online: p.online, label: p.online ? 'Eligible' : 'Offline'), title: Text(p.id ?? p.host), trailing: Text(p.online ? '${p.latencyMs ?? '?'} ms' : '—'))))]); }
  Widget _activityPage(BuildContext c) => _page(c, 'Activity', [HnCard(child: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.verified_outlined), title: Text('Integrity verification'), subtitle: Text('All downloads are SHA-256 verified before preview.'))), const SizedBox(height: 10), HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.sync_outlined), title: const Text('Network diagnostics'), subtitle: Text(status), trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: refresh)))]);
  Widget _settingsPage(BuildContext c) => _page(c, 'Settings', [HnCard(child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Dark theme'), subtitle: const Text('Premium low-light Material 3 palette'), value: themeMode.value == ThemeMode.dark, onChanged: (v) => themeMode.value = v ? ThemeMode.dark : ThemeMode.light)), const SizedBox(height: 10), HnCard(child: const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.repeat_rounded), title: Text('Replication factor'), subtitle: Text('Two verified, distinct Android storage peers are required.'), trailing: Text('2'))), const SizedBox(height: 10), HnCard(child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.memory_outlined), title: const Text('This device'), subtitle: Text('${PlatformNode.receiverDescription}\n$nodeId'), isThreeLine: true))]);

  @override
  Widget build(BuildContext context) {
    final pages = [_legacyHome(context), _storagePage(context), _peersPage(context), _galleryPage(context), _routerPage(context), _activityPage(context), _settingsPage(context)];
    const labels = ['Home', 'Storage', 'Peers', 'Gallery', 'Router', 'Activity', 'Settings'];
    const icons = [Icons.home_outlined, Icons.storage_outlined, Icons.devices_outlined, Icons.photo_library_outlined, Icons.account_tree_outlined, Icons.bolt_outlined, Icons.settings_outlined];
    return LayoutBuilder(builder: (context, box) { final rail = box.maxWidth >= 760; return Scaffold(appBar: AppBar(title: const Text('HiveNet', style: TextStyle(fontWeight: FontWeight.w800)), actions: [if (busy) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) else IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]), floatingActionButton: tab == 0 || tab == 3 ? FloatingActionButton.extended(onPressed: busy ? null : upload, icon: const Icon(Icons.upload_outlined), label: const Text('Upload')) : null, bottomNavigationBar: rail ? null : NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: List.generate(7, (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]))), body: Row(children: [if (rail) NavigationRail(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), extended: box.maxWidth > 1050, destinations: List.generate(7, (i) => NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i])))), if (rail) const VerticalDivider(width: 1), Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]))) ])); });
  }
}
*/

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────
ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kCyan,
    brightness: brightness,
    primary: kCyan,
    secondary: kPurple,
    tertiary: kAmber,
    surface: dark ? kDarkSurface : const Color(0xffF5F7F6),
    error: kRed,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? kDarkBg : const Color(0xffEEF2F0),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xff14222B) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: kCyan.withOpacity(0.16),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 180),
        elevation: const WidgetStatePropertyAll(1),
        overlayColor: WidgetStatePropertyAll(kDarkBg.withOpacity(.12)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        animationDuration: const Duration(milliseconds: 180),
        overlayColor: WidgetStatePropertyAll(kCyan.withOpacity(.10)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: dark ? Colors.white : const Color(0xff1E1B4B),
      displayColor: dark ? Colors.white : const Color(0xff1D3037),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Domain models (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class Peer {
  Peer(this.host);
  final String host;
  String? id;
  int free = 0;
  int total = 0;
  bool online = false;
  int? latencyMs;
  int successes = 0;
  int failures = 0;
  String? nickname;
  String? ownerName;
  bool trusted = false;
  String get base => 'http://$host:$_port';
  String get key => id ?? host;
  double get reliability => PeerCandidate(
    key: key,
    freeBytes: free,
    latencyMs: latencyMs,
    online: online,
    successes: successes,
    failures: failures,
  ).reliability;

  Map<String, dynamic> toJson() => {
    'host': host,
    'id': id,
    'total': total,
    'successes': successes,
    'failures': failures,
    'nickname': nickname,
    'ownerName': ownerName,
    'trusted': trusted,
  };
}

class Meta {
  Meta(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['name'] as String? ?? 'image.jpg',
      bytes = (j['bytes'] as num).toInt(),
      originalBytes =
          (j['originalBytes'] as num?)?.toInt() ?? (j['bytes'] as num).toInt();
  final String id, name;
  final int bytes;
  final int originalBytes;
  double get compressionRatio => originalBytes == 0 ? 1 : bytes / originalBytes;
}

class GalleryImage {
  GalleryImage(this.meta);
  final Meta meta;
  final List<Peer> locations = [];
}

class ActivityEvent {
  ActivityEvent(this.title, this.detail, this.icon, {this.error = false})
    : time = DateTime.now();
  final String title, detail;
  final IconData icon;
  final DateTime time;
  final bool error;
}

class ReplicaSendResult {
  const ReplicaSendResult._(this.stored, [this.error]);
  const ReplicaSendResult.stored() : this._(true);
  const ReplicaSendResult.failed(String error) : this._(false, error);

  final bool stored;
  final String? error;
}

class UploadFailure implements Exception {
  const UploadFailure(this.stage, this.message, {this.eligibleStoragePeers});

  final TransferStage stage;
  final String message;
  final int? eligibleStoragePeers;

  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────────────────────
class _RegistrationBackdrop extends StatelessWidget {
  const _RegistrationBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.75),
          radius: 1.05,
          colors: [Color(0xff123A3D), Color(0xff071217), kDarkBg],
          stops: [0, .48, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -160,
            right: -110,
            child: _BackdropGlow(color: kCyan.withOpacity(.14), size: 330),
          ),
          Positioned(
            bottom: -180,
            left: -110,
            child: _BackdropGlow(
              color: const Color(0xff00BFAE).withOpacity(.10),
              size: 360,
            ),
          ),
        ],
      ),
    ),
  );
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// Dashboard widget
// ─────────────────────────────────────────────────────────────────────────────
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  final picker = ImagePicker();
  final vault = OwnerVault();
  final identityStore = IdentityStore();
  final _httpClient = http.Client();
  final _displayNameController = TextEditingController();
  final _deviceNicknameController = TextEditingController();
  final ownerRecords = <String, Map<String, dynamic>>{};
  final peers = <Peer>[];
  Box<dynamic>? _webImages;
  var images = <Meta>[];
  var gallery = <GalleryImage>[];
  String? lastCompression;
  final activity = <ActivityEvent>[];
  int tab = 0;
  var nodeId = '';
  var deviceName = 'This device';
  HiveProfile? profile;
  var busy = true;
  bool _isBootstrapping = true;
  var status = 'Starting node...';
  UploadExperience? uploadExperience;
  List<IncomingTransfer> incomingTransfers = const [];
  Timer? _incomingPoll;
  Timer? _pairPoll;
  Future<void>? _refreshInFlight;
  bool _loadingIncomingTransfers = false;
  late final List<ScrollController> _scrollControllers;
  int _peerFilter = 0;
  int _galleryFilter = 0;

  // Background gradient animation controller
  late final AnimationController _bgAnimationController;
  // Storage ring animation controller
  late final AnimationController _storageRingCtrl;
  // Router topology animation controller
  late final AnimationController _routerAnimCtrl;

  void log(String title, String detail, IconData icon, {bool error = false}) {
    activity.insert(0, ActivityEvent(title, detail, icon, error: error));
    if (activity.length > 30) activity.removeLast();
  }

  @override
  void initState() {
    super.initState();
    _scrollControllers = List.generate(6, (_) => ScrollController());
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _storageRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _routerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _bootstrap();
    _incomingPoll = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadIncomingTransfers(),
    );
  }

  Future<void> _bootstrap() async {
    try {
      await init();
    } catch (error) {
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Node startup failed: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _isBootstrapping = false);
    }
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _storageRingCtrl.dispose();
    _routerAnimCtrl.dispose();
    _incomingPoll?.cancel();
    _pairPoll?.cancel();
    _httpClient.close();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    _displayNameController.dispose();
    _deviceNicknameController.dispose();
    super.dispose();
  }

  // ─── business logic (all unchanged) ───────────────────────────────────────

  String randomId() => base64Url
      .encode(List.generate(12, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');

  Future<void> init() async {
    profile = await identityStore.read();
    if (profile == null) {
      if (mounted) {
        setState(() {
          busy = false;
          status = 'Create your local HiveNet profile.';
        });
      }
      return;
    }
    if (kIsWeb) {
      await Hive.initFlutter();
      _webImages = await Hive.openBox<dynamic>('hivenet_images');
    }
    final prefs = await SharedPreferences.getInstance();
    final savedOwner =
        jsonDecode(prefs.getString('ownedEncryptedFiles') ?? '{}') as Map;
    ownerRecords.addAll(
      savedOwner.map(
        (key, value) =>
            MapEntry(key as String, Map<String, dynamic>.from(value as Map)),
      ),
    );
    nodeId = profile!.deviceId;
    await prefs.setString('node', nodeId);
    // A user-selected nickname is the visible device label; its UUID and
    // Android-Keystore public key remain the cryptographic identity.
    deviceName = profile!.deviceNickname;
    await PlatformNode.devicePublicKey();
    for (final saved
        in (jsonDecode(prefs.getString('peers') ?? '[]') as List)) {
      // Accept the old string-only peer list while retaining real transfer
      // history for the smart router in the new format.
      final data = saved is String
          ? <String, dynamic>{'host': saved}
          : Map<String, dynamic>.from(saved as Map);
      final peer = Peer(data['host'] as String)
        ..successes = (data['successes'] as num?)?.toInt() ?? 0
        ..failures = (data['failures'] as num?)?.toInt() ?? 0
        ..id = data['id'] as String?
        ..total = (data['total'] as num?)?.toInt() ?? 0;
      peer
        ..nickname = data['nickname'] as String?
        ..ownerName = data['ownerName'] as String?
        ..trusted = data['trusted'] as bool? ?? false;
      final duplicate = peers.any(
        (existing) =>
            existing.host == peer.host ||
            (peer.id != null && existing.id == peer.id),
      );
      if (!duplicate) peers.add(peer);
    }
    // A foreground receiver is native because a Flutter activity may be
    // paused or destroyed while another LAN node uploads a replica.
    await PlatformNode.start(nodeId);
    await _loadIncomingTransfers();
    await refresh();
  }

  Future<void> _loadIncomingTransfers() async {
    if (_loadingIncomingTransfers) return;
    _loadingIncomingTransfers = true;
    try {
      final raw = await PlatformNode.incomingTransfers();
      final next = raw.map(IncomingTransfer.fromPlatform).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (!mounted) return;
      // Avoid rebuilding for an unchanged native receiver snapshot.
      if (next.length == incomingTransfers.length &&
          next.every(
            (item) => incomingTransfers.any(
              (old) =>
                  old.id == item.id &&
                  old.stage == item.stage &&
                  old.receivedBytes == item.receivedBytes,
            ),
          )) {
        return;
      }
      final wasComplete = incomingTransfers
          .where((e) => e.complete)
          .map((e) => e.id)
          .toSet();
      setState(() => incomingTransfers = next);
      if (next.any((item) => item.complete && !wasComplete.contains(item.id))) {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // The foreground service can be restarting; retain the last good state.
    } finally {
      _loadingIncomingTransfers = false;
    }
  }

  void _setUpload(UploadExperience value) {
    if (!mounted) return;
    final prior = uploadExperience?.stage;
    setState(() {
      uploadExperience = value;
      status = value.message;
    });
    if (prior != value.stage &&
        (value.stage == TransferStage.complete ||
            value.stage == TransferStage.failed)) {
      HapticFeedback.mediumImpact();
    } else if (prior != value.stage) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> savePeers() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'peers',
      jsonEncode(peers.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> saveOwnerRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ownedEncryptedFiles', jsonEncode(ownerRecords));
  }

  Future<http.Response> get(String u) =>
      _httpClient.get(Uri.parse(u)).timeout(const Duration(seconds: 5));

  /// Coalesces pull-to-refresh, startup, and post-upload scans so they do not
  /// race each other or multiply LAN requests.
  Future<void> refresh() {
    final current = _refreshInFlight;
    if (current != null) return current;
    late final Future<void> refreshFuture;
    refreshFuture = _refresh().whenComplete(() {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = refreshFuture;
    return refreshFuture;
  }

  Future<void> _refresh() async {
    if (nodeId.isEmpty) return;
    if (mounted) {
      setState(() {
        busy = true;
        status = 'Checking peers...';
      });
    }
    await Future.wait(
      peers.map((p) async {
        try {
          final clock = Stopwatch()..start();
          final r = await get('${p.base}/v1/info');
          clock.stop();
          if (r.statusCode == 200) {
            final j = jsonDecode(r.body) as Map<String, dynamic>;
            p.online = true;
            p.id = j['nodeId'] as String?;
            p.free = (j['freeBytes'] as num?)?.toInt() ?? 0;
            p.total = (j['totalBytes'] as num?)?.toInt() ?? 0;
            p.latencyMs = clock.elapsedMilliseconds;
          } else {
            p.online = false;
            p.latencyMs = null;
          }
        } catch (_) {
          p.online = false;
          p.latencyMs = null;
        }
      }),
    );
    final own = <Meta>[];
    if (kIsWeb) {
      images = _webImages!.values
          .map((e) => Meta(Map<String, dynamic>.from(e['meta'] as Map)))
          .toList();
      own.addAll(images);
    } else {
      try {
        final r = await get('http://127.0.0.1:$_port/v1/files');
        if (r.statusCode == 200) {
          images = (jsonDecode(r.body) as List)
              .map((e) => Meta(e as Map<String, dynamic>))
              .toList();
          own.addAll(images);
        }
      } catch (_) {}
    }
    await _refreshGallery(own);
    log(
      'Network scan complete',
      '${peers.where((p) => p.online).length} peers online',
      Icons.radar,
    );
    if (mounted) {
      setState(() {
        busy = false;
        status = kIsWeb
            ? 'Browser client connected to LAN peers'
            : 'Node active on port $_port';
      });
      // Animate the storage ring whenever a refresh completes
      _storageRingCtrl.forward(from: 0);
    }
  }

  Future<void> _refreshGallery(List<Meta> own) async {
    final entries = <String, GalleryImage>{};
    void add(Meta meta, [Peer? location]) {
      final entry = entries.putIfAbsent(meta.id, () => GalleryImage(meta));
      if (location != null &&
          !entry.locations.any((p) => p.key == location.key)) {
        entry.locations.add(location);
      }
    }

    for (final meta in own) {
      add(meta);
    }
    await Future.wait(
      peers.where((p) => p.online).map((peer) async {
        try {
          final response = await get('${peer.base}/v1/files');
          if (response.statusCode != 200) return;
          for (final raw in jsonDecode(response.body) as List) {
            add(Meta(raw as Map<String, dynamic>), peer);
          }
        } catch (_) {
          // A failed scan is not proof that an earlier replica has vanished.
        }
      }),
    );
    gallery = entries.values.toList()
      ..sort((a, b) => a.meta.name.compareTo(b.meta.name));
  }

  Future<void> addPeer() async {
    final text = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add LAN peer'),
        content: TextField(
          controller: text,
          decoration: const InputDecoration(hintText: '192.168.1.42'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, text.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final host = value
        ?.replaceFirst(RegExp(r'^https?://'), '')
        .split(':')
        .first
        .trim();
    if (host != null && host.isNotEmpty && !peers.any((p) => p.host == host)) {
      setState(() => peers.add(Peer(host)));
      log('Peer added', '$host:$_port', Icons.add_link);
      await savePeers();
      await refresh();
    }
  }

  Future<void> _pairNewDevice() async {
    var ip = await PlatformNode.localIp();
    if (!mounted) return;
    if (ip == null || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to a LAN or Wi-Fi network before pairing.'),
        ),
      );
      return;
    }
    // Android emulators expose a NAT-only 10.0.2.x address. A phone cannot
    // route to it, so use the Windows host's Wi-Fi address after port-forwarding.
    if (ip.startsWith('10.0.2.') || ip.startsWith('10.0.3.')) {
      final field = TextEditingController();
      final host = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('BlueStacks pairing address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BlueStacks uses a private emulator address. Enter this PC’s Wi-Fi IPv4 address after forwarding TCP 8765 to BlueStacks.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: field,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Example: 10.10.80.89',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
              child: const Text('Use address'),
            ),
          ],
        ),
      );
      if (host == null || host.isEmpty) return;
      ip = host;
    }
    final publicKey = await PlatformNode.devicePublicKey();
    final session = await PlatformNode.startPairing({
      'userId': profile!.userId,
      'ownerName': profile!.displayName,
      'deviceId': profile!.deviceId,
      'deviceName': profile!.deviceNickname,
      'publicKey': publicKey,
    });
    final payload = jsonEncode({
      'v': 1,
      'host': ip,
      'port': _port,
      'token': session['token'],
      'expiresAt': session['expiresAt'],
      'deviceId': profile!.deviceId,
      'deviceName': profile!.deviceNickname,
      'publicKey': publicKey,
    });
    if (!mounted) return;
    _pairPoll?.cancel();
    _pairPoll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final requests = await PlatformNode.pairingRequests();
      if (requests.isEmpty || !mounted) return;
      _pairPoll?.cancel();
      final request = requests.first;
      final allow = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Approve new HiveNet device?'),
          content: Text(
            '${request['ownerName'] ?? 'Unknown owner'} · ${request['deviceName'] ?? 'Unnamed device'}\n\nThe device supplied a valid signing-key proof for this one-time session.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (allow == true &&
          await PlatformNode.approvePairing('${request['deviceId']}')) {
        final host = request['host']?.toString();
        if (host != null && !peers.any((peer) => peer.host == host)) {
          peers.add(
            Peer(host)
              ..id = request['deviceId']?.toString()
              ..nickname = request['deviceName']?.toString()
              ..ownerName = request['ownerName']?.toString()
              ..trusted = true,
          );
        }
        await savePeers();
        await refresh();
      }
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDarkSurface,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pair New Device',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              'Scan this one-time QR from the new HiveNet device. It expires in five minutes.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: payload, size: 250),
            ),
            const SizedBox(height: 14),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PulsingDot(color: kCyan),
                SizedBox(width: 8),
                Text('Waiting for a signed pairing request…'),
              ],
            ),
          ],
        ),
      ),
    );
    _pairPoll?.cancel();
  }

  Future<void> _scanPairQr() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDarkBg,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .78,
        child: MobileScanner(
          onDetect: (capture) async {
            final raw = capture.barcodes.isEmpty
                ? null
                : capture.barcodes.first.rawValue;
            if (raw == null) return;
            try {
              final qr = Map<String, dynamic>.from(jsonDecode(raw) as Map);
              final host = qr['host'] as String;
              final port = qr['port'] as int;
              final token = qr['token'] as String;
              if ((qr['expiresAt'] as num).toInt() <
                  DateTime.now().millisecondsSinceEpoch) {
                throw const FormatException('This pairing QR has expired.');
              }
              Navigator.pop(c);
              final publicKey = await PlatformNode.devicePublicKey();
              final proof = await PlatformNode.signDeviceProof(
                '$token|${profile!.deviceId}',
              );
              final localIp = await PlatformNode.localIp();
              final response = await _httpClient
                  .post(
                    Uri.parse('http://$host:$port/v1/pair/$token/request'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'deviceId': profile!.deviceId,
                      'deviceName': profile!.deviceNickname,
                      'ownerName': profile!.displayName,
                      'publicKey': publicKey,
                      'proof': proof,
                      'host': localIp ?? '',
                    }),
                  )
                  .timeout(const Duration(seconds: 8));
              if (response.statusCode != 202) {
                throw Exception(
                  'Pairing request rejected (${response.statusCode}).',
                );
              }
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Request sent. Approve it on the other device.',
                  ),
                ),
              );
              for (var attempt = 0; attempt < 30; attempt++) {
                await Future<void>.delayed(const Duration(seconds: 2));
                final statusResponse = await _httpClient
                    .get(
                      Uri.parse('http://$host:$port/v1/pair/$token/status'),
                      headers: {'x-hivenet-device-id': profile!.deviceId},
                    )
                    .timeout(const Duration(seconds: 5));
                if (statusResponse.statusCode != 200) continue;
                final status =
                    jsonDecode(statusResponse.body) as Map<String, dynamic>;
                if (status['state'] == 'approved') {
                  if (!peers.any((peer) => peer.host == host)) {
                    peers.add(
                      Peer(host)
                        ..id = qr['deviceId']?.toString()
                        ..nickname = qr['deviceName']?.toString()
                        ..ownerName = (status['owner'] as Map?)?['ownerName']
                            ?.toString()
                        ..trusted = true,
                    );
                  }
                  await savePeers();
                  await refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Paired with ${qr['deviceName']} successfully.',
                        ),
                      ),
                    );
                  }
                  return;
                }
              }
              throw Exception(
                'Approval timed out. Keep both devices on the same LAN and try again.',
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Could not pair: $e')));
              }
            }
          },
        ),
      ),
    );
  }

  Future<ReplicaSendResult> send(
    Peer peer,
    String id,
    String originalName,
    String storedName,
    int originalBytes,
    EncryptedFile image,
  ) async {
    try {
      final r = await _httpClient
          .put(
            Uri.parse('${peer.base}/v1/files/$id'),
            body: image.ciphertext,
            headers: {
              'Content-Type': 'application/octet-stream',
              'x-hivenet-sha256': id,
              // Gallery filename and opaque storage filename are separate.
              // The receiving node persists only [storedName] to its filesystem.
              'x-hivenet-name-b64': base64Url.encode(utf8.encode(originalName)),
              'x-hivenet-stored-name': storedName,
              'x-hivenet-sender-b64': base64Url.encode(utf8.encode(deviceName)),
              'x-hivenet-mime': 'application/octet-stream',
              'x-hivenet-original-bytes': '$originalBytes',
              'x-hivenet-delete-token-hash': image.deleteTokenHash,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 201) {
        String detail = 'Peer returned HTTP ${r.statusCode}.';
        try {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          detail = body['error']?.toString() ?? detail;
        } catch (_) {
          // A non-JSON response still has a useful HTTP status above.
        }
        return ReplicaSendResult.failed(detail);
      }
      final ack = jsonDecode(r.body) as Map<String, dynamic>;
      if (ack['stored'] != true || ack['sha256'] != id) {
        return const ReplicaSendResult.failed(
          'The peer acknowledgement did not confirm the expected SHA-256.',
        );
      }
      return const ReplicaSendResult.stored();
    } on TimeoutException {
      return const ReplicaSendResult.failed(
        'Timed out waiting for the storage peer acknowledgement.',
      );
    } catch (error) {
      return ReplicaSendResult.failed('Network transfer failed: $error');
    }
  }

  Future<void> upload() async {
    final selected = await picker.pickImage(source: ImageSource.gallery);
    if (selected == null) return;
    late final Uint8List source;
    try {
      source = await selected.readAsBytes();
    } catch (error) {
      _setUpload(
        UploadExperience(
          stage: TransferStage.failed,
          failedStage: TransferStage.selected,
          message: 'The selected image could not be read.',
          originalName: selected.name,
          error: 'Image selection failed: $error',
        ),
      );
      return;
    }
    var failureStage = TransferStage.selected;
    String? storedName;
    String? contentId;
    var eligibleStoragePeers = 0;
    List<TransferPeerView> latestPeerViews = const [];
    _setUpload(
      UploadExperience(
        stage: TransferStage.selected,
        message: 'Preview ready. Preparing this image on your device.',
        originalName: selected.name,
        preview: source,
      ),
    );
    // Give the selected state a frame before starting the real CPU work.
    await Future<void>.delayed(Duration.zero);
    setState(() {
      busy = true;
      status = 'Compressing image...';
    });
    try {
      failureStage = TransferStage.compressing;
      _setUpload(
        UploadExperience(
          stage: TransferStage.compressing,
          message: 'Compressing image locally.',
          originalName: selected.name,
          preview: source,
        ),
      );
      final prepared = await compute<List<int>, CompressedImage>(
        compressImage,
        source,
      );
      failureStage = TransferStage.encrypting;
      _setUpload(
        UploadExperience(
          stage: TransferStage.encrypting,
          message: 'Encrypting locally with AES-256-GCM.',
          originalName: selected.name,
          preview: source,
        ),
      );
      final encrypted = await vault.encrypt(
        prepared.bytes,
        onHashing: () {
          failureStage = TransferStage.hashing;
          _setUpload(
            UploadExperience(
              stage: TransferStage.hashing,
              message:
                  'Generating the SHA-256 identity for the encrypted object.',
              originalName: selected.name,
              preview: source,
            ),
          );
        },
      );
      final id = encrypted.id;
      contentId = id;
      storedName = 'encryptedImage_${id.substring(0, 12)}';
      lastCompression =
          '${size(prepared.originalBytes)} → ${size(prepared.bytes.length)} '
          '(${((1 - prepared.ratio) * 100).toStringAsFixed(0)}% smaller, '
          '${prepared.width}×${prepared.height})';
      PeerCandidate candidate(Peer peer) => PeerCandidate(
        key: peer.key,
        freeBytes: peer.free,
        latencyMs: peer.latencyMs,
        online: peer.online,
        successes: peer.successes,
        failures: peer.failures,
      );
      failureStage = TransferStage.discovering;
      _setUpload(
        UploadExperience(
          stage: TransferStage.discovering,
          message: 'Evaluating live capacity, latency, and verified-transfer history.',
          originalName: selected.name,
          storedName: storedName,
          sha256: id,
          preview: source,
        ),
      );
      // A local device is never treated as one of its own remote replicas.
      // Eligibility requires a fresh probe, enough real free space, and a
      // distinct device identity.
      failureStage = TransferStage.selecting;
      final eligible = rankEligibleReplicaPeers(
        peers.where((peer) => peer.key != nodeId),
        candidate,
        encrypted.ciphertext.length,
      );
      eligibleStoragePeers = eligible.length;
      final ranked = eligible.take(2).toList();
      if (eligibleStoragePeers < 2) {
        throw UploadFailure(
          TransferStage.selecting,
          'Upload blocked — $eligibleStoragePeers of 2 required storage peers available. Connect another online device with enough free space.',
          eligibleStoragePeers: eligibleStoragePeers,
        );
      }
      List<TransferPeerView> peerViews(
        List<Peer> selection, {
        Peer? active,
        Set<String> verified = const {},
        Set<String> failed = const {},
      }) => selection.asMap().entries.map((entry) {
        final peer = entry.value;
        final peerStatus = verified.contains(peer.key)
            ? 'Replica stored and SHA-256 verified'
            : failed.contains(peer.key)
            ? 'Transfer failed; no acknowledgement was accepted'
            : active?.key == peer.key
            ? 'Network transfer in progress'
            : 'Queued for verified replication';
        final peerState = verified.contains(peer.key)
            ? TransferPeerState.verified
            : failed.contains(peer.key)
            ? TransferPeerState.failed
            : active?.key == peer.key
            ? TransferPeerState.transferring
            : TransferPeerState.queued;
        return TransferPeerView(
          name: peer.id ?? peer.host,
          rank: entry.key == 0 ? 'BEST REPLICA' : 'SECOND REPLICA',
          availableStorage: size(peer.free),
          latency: '${peer.latencyMs ?? '?'} ms',
          reliability:
              '${(peer.reliability * 100).toStringAsFixed(0)}% reliable',
          status: peerStatus,
          state: peerState,
        );
      }).toList();
      latestPeerViews = peerViews(ranked);
      _setUpload(
        UploadExperience(
          stage: TransferStage.selecting,
          message: 'Two distinct storage devices were selected.',
          originalName: selected.name,
          storedName: storedName,
          sha256: id,
          preview: source,
          peers: latestPeerViews,
        ),
      );
      // A failed top-ranked device is replaced by the next ranked *distinct*
      // peer; a successful transfer is never faked or counted twice.
      final attemptedKeys = <String>{};
      final replicas = <Peer>[];
      List<Peer> displayPeers(Peer active) {
        final seen = <String>{};
        return [
          ...replicas,
          active,
          ...ranked,
          ...peers,
        ].where((candidate) => seen.add(candidate.key)).take(2).toList();
      }

      while (replicas.length < 2) {
        final next = selectReplicaPeers(
          peers.where(
            (peer) => peer.key != nodeId && !attemptedKeys.contains(peer.key),
          ),
          candidate,
          encrypted.ciphertext.length,
        );
        if (next.isEmpty) break;
        final peer = next.first;
        attemptedKeys.add(peer.key);
        failureStage = TransferStage.sending;
        latestPeerViews = peerViews(
          displayPeers(peer),
          active: peer,
          verified: replicas.map((item) => item.key).toSet(),
        );
        _setUpload(
          UploadExperience(
            stage: TransferStage.sending,
            message: 'Sending encrypted data to ${peer.id ?? peer.host}.',
            originalName: selected.name,
            storedName: storedName,
            sha256: id,
            preview: source,
            peers: latestPeerViews,
          ),
        );
        final result = await send(
          peer,
          id,
          selected.name,
          storedName,
          prepared.originalBytes,
          encrypted,
        );
        if (result.stored) {
          failureStage = TransferStage.verifying;
          latestPeerViews = peerViews(
            displayPeers(peer),
            verified: {...replicas.map((item) => item.key), peer.key},
          );
          _setUpload(
            UploadExperience(
              stage: TransferStage.verifying,
              message:
                  '${peer.id ?? peer.host} acknowledged the replica and SHA-256.',
              originalName: selected.name,
              storedName: storedName,
              sha256: id,
              preview: source,
              peers: latestPeerViews,
            ),
          );
          peer.successes++;
          replicas.add(peer);
        } else {
          peer.failures++;
          latestPeerViews = peerViews(
            displayPeers(peer),
            verified: replicas.map((item) => item.key).toSet(),
            failed: {peer.key},
          );
          _setUpload(
            UploadExperience(
              stage: TransferStage.sending,
              message:
                  'Transfer to ${peer.id ?? peer.host} failed: ${result.error ?? 'no acknowledgement'}. Trying another eligible peer.',
              originalName: selected.name,
              storedName: storedName,
              sha256: id,
              preview: source,
              peers: latestPeerViews,
            ),
          );
        }
      }
      await savePeers();
      if (replicas.length != 2) {
        failureStage = TransferStage.sending;
        log(
          'Replication failed',
          'Two verified replicas were not available.',
          Icons.error_outline,
          error: true,
        );
        throw UploadFailure(
          TransferStage.sending,
          'Only ${replicas.length} of 2 remote replicas were verified. No upload was completed.',
          eligibleStoragePeers: eligibleStoragePeers,
        );
      }
      failureStage = TransferStage.verifying;
      ownerRecords[id] = {
        'name': selected.name,
        'storedName': storedName,
        'nonce': base64Url.encode(encrypted.nonce),
        'bytes': prepared.bytes.length,
        'originalBytes': prepared.originalBytes,
      };
      await saveOwnerRecords();
      if (kIsWeb) {
        await _webImages!.put(id, {
          'meta': {
            'id': id,
            'name': selected.name,
            'bytes': encrypted.ciphertext.length,
            'originalBytes': prepared.originalBytes,
          },
          'bytes': encrypted.ciphertext,
        });
      }
      if (mounted) {
        log(
          'Image replicated',
          '${replicas.map((p) => p.id ?? p.host).join(' and ')} verified $id',
          Icons.verified,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Replicated and verified on both storage nodes.'),
          ),
        );
        _setUpload(
          UploadExperience(
            stage: TransferStage.complete,
            message: 'Both independent replicas are stored and verified.',
            originalName: selected.name,
            storedName: storedName,
            sha256: id,
            preview: source,
            peers: peerViews(
              replicas,
              verified: replicas.map((item) => item.key).toSet(),
            ),
          ),
        );
      }
    } catch (e) {
      final failure = e is UploadFailure
          ? e
          : UploadFailure(failureStage, 'Upload failed: $e');
      log('Upload failed', failure.message, Icons.error_outline, error: true);
      _setUpload(
        UploadExperience(
          stage: TransferStage.failed,
          message: failure.message,
          originalName: selected.name,
          storedName: storedName,
          sha256: contentId,
          preview: source,
          peers: latestPeerViews,
          error: failure.message,
          failedStage: failure.stage,
          eligibleStoragePeers:
              failure.eligibleStoragePeers ?? eligibleStoragePeers,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
    await refresh();
  }

  Future<void> showImage(Meta m, [Peer? peer]) async {
    final owner = ownerRecords[m.id];
    if (owner == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This encrypted object belongs to another device.'),
          ),
        );
      }
      return;
    }
    try {
      late final Uint8List encrypted;
      if (kIsWeb && peer == null) {
        final record = _webImages!.get(m.id) as Map;
        encrypted = _verifiedBytes(
          m.id,
          Uint8List.fromList(List<int>.from(record['bytes'] as List)),
        );
      } else {
        final r = await get(
          '${peer?.base ?? 'http://127.0.0.1:$_port'}/v1/files/${m.id}',
        );
        if (r.statusCode != 200) throw Exception();
        encrypted = _verifiedBytes(m.id, r.bodyBytes);
      }
      final plaintext = await vault.decrypt(
        m.id,
        encrypted,
        base64Url.decode(owner['nonce'] as String),
      );
      if (!mounted) return;
      await _showImage(owner['name'] as String, plaintext);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not retrieve image.')),
        );
      }
    }
  }

  /// Attempts every known replica in order. A missing/offline first device is
  /// therefore recoverable as long as its other replica is available.
  Future<void> showDistributedImage(GalleryImage image) async {
    final owner = ownerRecords[image.meta.id];
    if (owner == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This encrypted object belongs to another device.'),
          ),
        );
      }
      return;
    }
    if (kIsWeb && _webImages!.containsKey(image.meta.id)) {
      await showImage(image.meta);
      return;
    }
    if (!kIsWeb && images.any((meta) => meta.id == image.meta.id)) {
      await showImage(image.meta);
      return;
    }
    for (final peer in image.locations.where((peer) => peer.online)) {
      try {
        final response = await get('${peer.base}/v1/files/${image.meta.id}');
        if (response.statusCode != 200) continue;
        if (mounted) {
          final encrypted = _verifiedBytes(image.meta.id, response.bodyBytes);
          final plaintext = await vault.decrypt(
            image.meta.id,
            encrypted,
            base64Url.decode(owner['nonce'] as String),
          );
          await _showImage(owner['name'] as String, plaintext);
        }
        return;
      } catch (_) {
        // Try the next independently stored replica.
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available verified replica for this image.'),
        ),
      );
    }
  }

  /// A retrieval is only displayed when it still matches its content address.
  /// Android verifies on receipt too; this catches corruption in transit or at
  /// rest before a peer's image is rendered on either platform.
  Uint8List _verifiedBytes(String id, List<int> bytes) {
    final imageBytes = Uint8List.fromList(bytes);
    if (!matchesContentId(id, imageBytes)) {
      throw const FormatException('Image checksum did not match its ID.');
    }
    return imageBytes;
  }

  Future<void> _showImage(String name, Uint8List bytes) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(name)),
        body: Center(child: InteractiveViewer(child: Image.memory(bytes))),
      ),
    ),
  );

  Future<void> browsePeer(Peer peer) async {
    try {
      final r = await get('${peer.base}/v1/files');
      if (r.statusCode != 200) throw Exception();
      final files = (jsonDecode(r.body) as List)
          .map((e) => Meta(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (c) => ListView(
          children: [
            ListTile(
              title: Text('${peer.id ?? peer.host} gallery'),
              subtitle: Text('${files.length} stored images'),
            ),
            ...files.map(
              (m) => ListTile(
                leading: const Icon(Icons.image),
                title: Text(m.name),
                subtitle: Text(size(m.bytes)),
                onTap: () {
                  Navigator.pop(c);
                  showImage(m, peer);
                },
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load peer gallery.')),
        );
      }
    }
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  String size(int n) => n > 1048576
      ? '${(n / 1048576).toStringAsFixed(1)} MB'
      : '${(n / 1024).toStringAsFixed(0)} KB';

  int get onlineCount => peers.where((p) => p.online).length;
  int get pooledFree =>
      peers.where((p) => p.online).fold(0, (n, p) => n + p.free);
  int get pooledTotal =>
      peers.where((p) => p.online).fold(0, (n, p) => n + p.total);
  int get pooledUsed =>
      (pooledTotal - pooledFree).clamp(0, pooledTotal).toInt();

  /// Every tab owns one primary scrollable. Keeping its controller alive makes
  /// tab changes feel native while avoiding nested vertical gesture arenas.
  Widget _tabList({required int index, required List<Widget> children}) {
    return Scrollbar(
      controller: _scrollControllers[index],
      child: ListView(
        key: PageStorageKey<String>('hivenet-tab-$index'),
        controller: _scrollControllers[index],
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 124),
        children: children,
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: selected
              ? kDarkBg
              : (dark ? Colors.white70 : const Color(0xff20343B)),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        selectedColor: kCyan,
        backgroundColor: dark
            ? Colors.white.withOpacity(0.055)
            : kCyan.withOpacity(0.08),
        side: BorderSide(color: kCyan.withOpacity(selected ? 0 : 0.30)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // ─── page builders ────────────────────────────────────────────────────────

  Widget _home(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Stack(
      children: [
        // Pull-to-refresh scroll view
        CustomScrollView(
          key: const PageStorageKey<String>('hivenet-tab-0'),
          controller: _scrollControllers[0],
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Gradient SliverAppBar ──
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                IconButton(
                  onPressed: busy ? null : refresh,
                  tooltip: 'Refresh network',
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
                IconButton(
                  onPressed: busy ? null : upload,
                  tooltip: 'Encrypt and upload image',
                  icon: const Icon(Icons.upload_rounded, color: Colors.white),
                ),
                IconButton(
                  onPressed: addPeer,
                  tooltip: 'Add LAN peer',
                  icon: const Icon(Icons.add_link, color: Colors.white),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: const Text(
                  'HiveNet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: 1.5,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gradient background
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xff172832), Color(0xff0E1A21)],
                        ),
                      ),
                    ),
                    // Honeycomb decoration via CustomPaint
                    Positioned.fill(
                      child: CustomPaint(painter: _HoneycombPainter()),
                    ),
                    // Bottom blur fade
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              (dark ? kDarkBg : const Color(0xffEEECFF))
                                  .withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // ── Node info card ──
                  GlassCard(
                    glowColor: kPurple,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.hive_outlined, color: kCyan),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      deviceName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedStatusPill(
                              online: !busy,
                              label: busy ? 'Syncing' : 'Live',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          nodeId,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: dark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            color: dark ? kCyan : kPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          PlatformNode.receiverDescription,
                          style: TextStyle(
                            fontSize: 11,
                            color: dark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (incomingTransfers.isNotEmpty) ...[
                    NeonSectionTitle('Incoming replicas', color: kAmber),
                    ...incomingTransfers
                        .take(3)
                        .map(
                          (transfer) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: IncomingTransferCard(
                              transfer: transfer,
                              formatSize: size,
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 16),

                  // ── Metric cards row ──
                  SizedBox(
                    width: double.infinity,
                    child: NeonButton(
                      label: busy
                          ? 'Preparing secure upload…'
                          : 'Encrypt & Upload Image',
                      icon: Icons.upload_rounded,
                      onPressed: busy ? null : upload,
                      colors: const [kCyan, kCyan],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: Row(
                      children: [
                        Expanded(
                          child: GradientMetricCard(
                            icon: Icons.storage_outlined,
                            value: size(pooledFree),
                            label: 'Pooled storage',
                            colors: const [kPurple, kPink],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GradientMetricCard(
                            icon: Icons.devices_outlined,
                            value: '$onlineCount/${peers.length}',
                            label: 'Peers online',
                            colors: const [kCyan, kPurple],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GradientMetricCard(
                            icon: Icons.photo_library_outlined,
                            value: '${gallery.length}',
                            label: 'Gallery items',
                            colors: const [kPink, kAmber],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Peers section ──
                  NeonSectionTitle(
                    'Peers ($onlineCount/${peers.length} online)',
                    color: kCyan,
                  ),
                  ...peers.asMap().entries.map(
                    (entry) => _animatedPeerCard(c, entry.value, entry.key),
                  ),
                  if (peers.isEmpty)
                    GlassCard(
                      child: Text(
                        'No peers yet. Tap + to add a LAN peer.',
                        style: TextStyle(
                          color: dark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),

                  // ── Distributed gallery ──
                  NeonSectionTitle(
                    'Distributed Gallery (${gallery.length})',
                    color: kPink,
                  ),
                  if (gallery.isEmpty)
                    GlassCard(
                      glowColor: kPink,
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_outlined, color: kPink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No distributed images yet.',
                              style: TextStyle(
                                color: dark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...gallery.map((entry) => _encryptedImageBar(c, entry)),

                  // ── Local gallery ──
                  NeonSectionTitle(
                    'Local Replicas (${images.length})',
                    color: kAmber,
                  ),
                  if (images.isEmpty)
                    GlassCard(
                      glowColor: kAmber,
                      child: const Text(
                        'No local replicas yet. This device becomes a '
                        'replica when another device uploads.',
                      ),
                    )
                  else
                    ...images.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          glowColor: kAmber,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [kAmber, kPink],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.image_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(m.name),
                            subtitle: Text(
                              '${size(m.bytes)} · ${m.id.substring(0, 10)}…',
                            ),
                            onTap: () => showImage(m),
                          ),
                        ),
                      ),
                    ),

                  if (lastCompression != null) ...[
                    const SizedBox(height: 8),
                    GlassCard(
                      glowColor: kGreen,
                      child: Row(
                        children: [
                          const Icon(Icons.compress, color: kGreen, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Last upload: $lastCompression',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ],

      // ── Upload FAB ──
    );
  }

  /// Animated peer card with staggered opacity slide-in
  Widget _animatedPeerCard(BuildContext c, Peer p, int index) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 300 + index * 80),
        opacity: 1.0,
        child: GlassCard(
          glowColor: p.online ? kCyan : kRed,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: p.online ? [kCyan, kGreen] : [kRed, kPink],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                p.online ? Icons.check_circle_outline : Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(p.id ?? p.host),
            subtitle: Text(
              '${p.host}:$_port'
              '${p.online ? ' · ${size(p.free)} free · ${p.latencyMs ?? '?'} ms · ${(p.reliability * 100).toStringAsFixed(0)}% reliable' : ' · offline'}',
              style: TextStyle(
                fontSize: 11,
                color: dark ? Colors.white54 : Colors.black54,
              ),
            ),
            onTap: p.online ? () => browsePeer(p) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedStatusPill(
                  online: p.online,
                  label: p.online ? 'Live' : 'Off',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    setState(() => peers.remove(p));
                    await savePeers();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Encrypted objects have no safe preview. Present their verifiable metadata
  /// as a compact file row instead of implying a readable image thumbnail.
  Widget _encryptedImageBar(BuildContext c, GalleryImage entry) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    final canOpen = ownerRecords.containsKey(entry.meta.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => showDistributedImage(entry),
        child: GlassCard(
          glowColor: kCyan,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kCyan.withOpacity(dark ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kCyan.withOpacity(0.28)),
                ),
                child: Icon(
                  canOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: kCyan,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.meta.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${size(entry.meta.bytes)}  ·  ${entry.locations.length} verified replica${entry.locations.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: dark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      canOpen
                          ? 'AES-256-GCM · owned by this device'
                          : 'Encrypted object · access restricted',
                      style: const TextStyle(
                        fontSize: 10,
                        color: kCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                canOpen ? Icons.chevron_right_rounded : Icons.shield_outlined,
                color: dark ? Colors.white54 : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-screen, event-driven upload experience.
  Widget _uploadOverlay(BuildContext c) {
    final experience = uploadExperience!;
    return TransferExperienceSheet(
      key: ValueKey('${experience.stage}-${experience.message}'),
      experience: experience,
      formatSize: size,
      onClose: experience.isFinished
          ? () => setState(() => uploadExperience = null)
          : null,
      onRetry: experience.stage == TransferStage.failed
          ? () {
              setState(() => uploadExperience = null);
              upload();
            }
          : null,
      onScanQr: experience.failedStage == TransferStage.selecting
          ? () async {
              setState(() => uploadExperience = null);
              await _scanPairQr();
            }
          : null,
      onAddPeer: experience.failedStage == TransferStage.selecting
          ? () async {
              setState(() => uploadExperience = null);
              await _pairNewDevice();
            }
          : null,
    );
  }

  // ─── storage page ─────────────────────────────────────────────────────────

  Widget _storage(BuildContext c) {
    final totalFree = pooledFree;
    final totalCapacity = pooledTotal;
    final usedCapacity = pooledUsed;
    final usedFraction = totalCapacity == 0
        ? 0.0
        : (usedCapacity / totalCapacity).clamp(0.0, 1.0);
    final dark = Theme.of(c).brightness == Brightness.dark;

    return _tabList(
      index: 1,
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Storage', color: kPurple),

        // Animated ring
        GlassCard(
          glowColor: kPurple,
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _storageRingCtrl,
                builder: (context, _) => SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: StorageRingPainter(
                      fraction: usedFraction,
                      progress: _storageRingCtrl.value,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) =>
                                const LinearGradient(colors: [kPurple, kCyan])
                                    .createShader(b),
                            child: Text(
                              size(totalFree),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Text(
                            'pooled free',
                            style: TextStyle(fontSize: 12, color: kCyan),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(kPurple, 'Used ${size(usedCapacity)}'),
                  const SizedBox(width: 20),
                  _legendDot(kCyan, 'Free ${size(totalFree)}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        NeonSectionTitle('Node Capacity', color: kCyan),
        ...peers.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              glowColor: p.online ? kCyan : kRed,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.storage_outlined,
                  color: p.online ? kCyan : kRed,
                ),
                title: Text(p.id ?? p.host),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.online
                          ? '${size(p.free)} available · ${p.host}:$_port'
                          : '${p.host}:$_port unavailable',
                    ),
                    if (p.online) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.free > 0
                              ? (1 - p.free / (p.free + 1024 * 1024)).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0,
                          backgroundColor: dark
                              ? Colors.white12
                              : Colors.black12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            kCyan,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: AnimatedStatusPill(
                  online: p.online,
                  label: p.online ? 'Live' : 'Offline',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );

  // ─── peers page ───────────────────────────────────────────────────────────

  Widget _peers(BuildContext c) {
    final dark = Theme.of(c).brightness == Brightness.dark;
    final visiblePeers = peers.where((peer) {
      return _peerFilter == 0 ||
          (_peerFilter == 1 && peer.online) ||
          (_peerFilter == 2 && !peer.online);
    }).toList();
    return _tabList(
      index: 2,
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Peers', color: kCyan),
        Text(
          'Live network telemetry · tap a connected peer to browse its files.',
          style: TextStyle(
            fontSize: 12,
            color: dark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          children: [
            _filterChip(
              label: 'All (${peers.length})',
              selected: _peerFilter == 0,
              onSelected: () => setState(() => _peerFilter = 0),
            ),
            _filterChip(
              label: 'Online ($onlineCount)',
              selected: _peerFilter == 1,
              onSelected: () => setState(() => _peerFilter = 1),
            ),
            _filterChip(
              label: 'Offline (${peers.length - onlineCount})',
              selected: _peerFilter == 2,
              onSelected: () => setState(() => _peerFilter = 2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NeonButton(
                label: 'Scan QR',
                icon: Icons.qr_code_scanner_rounded,
                colors: const [kCyan, kGreen],
                onPressed: _scanPairQr,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pairNewDevice,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Pair device'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (visiblePeers.isEmpty)
          GlassCard(
            glowColor: kCyan,
            child: Column(
              children: [
                const Icon(
                  Icons.devices_other_outlined,
                  color: kCyan,
                  size: 42,
                ),
                const SizedBox(height: 10),
                Text(
                  peers.isEmpty
                      ? 'No peers connected yet.'
                      : 'No ${_peerFilter == 1 ? 'online' : 'offline'} peers.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Scan a device QR code or create a one-time pairing QR to join your HiveNet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ...visiblePeers.asMap().entries.map((entry) {
          final p = entry.value;
          final reliability = p.reliability;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              glowColor: p.online ? kCyan : kRed,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: p.online ? () => browsePeer(p) : null,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: p.online ? [kCyan, kGreen] : [kRed, kPink],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    p.online
                        ? Icons.lan_outlined
                        : Icons.portable_wifi_off_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(p.id ?? p.host),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.host}:$_port · ${p.online ? '${p.latencyMs ?? '?'} ms' : 'Offline'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    if (p.online) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Text(
                            'Latency  ',
                            style: TextStyle(fontSize: 10),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ((p.latencyMs ?? 500) / 500).clamp(
                                  0.0,
                                  1.0,
                                ),
                                backgroundColor: dark
                                    ? Colors.white12
                                    : Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  kAmber,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Text(
                            'Reliability',
                            style: TextStyle(fontSize: 10),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: reliability,
                                backgroundColor: dark
                                    ? Colors.white12
                                    : Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  kGreen,
                                ),
                                minHeight: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                isThreeLine: p.online,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    setState(() => peers.remove(p));
                    await savePeers();
                  },
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── gallery page ─────────────────────────────────────────────────────────

  Widget _gallery(BuildContext c) {
    // The current protocol stores encrypted JPEG replicas only. The category
    // controls are still useful as the app grows, but never invent media that
    // the network has not actually reported.
    final visibleGallery = _galleryFilter < 2 ? gallery : <GalleryImage>[];
    return _tabList(
      index: 3,
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Gallery', color: kPink),
        Text(
          '${gallery.length} encrypted objects across responsive peers. '
          'Previews stay private; only verified metadata is shown here.',
        ),
        const SizedBox(height: 12),
        Wrap(
          children: [
            _filterChip(
              label: 'All (${gallery.length})',
              selected: _galleryFilter == 0,
              onSelected: () => setState(() => _galleryFilter = 0),
            ),
            _filterChip(
              label: 'Images (${gallery.length})',
              selected: _galleryFilter == 1,
              onSelected: () => setState(() => _galleryFilter = 1),
            ),
            _filterChip(
              label: 'Videos',
              selected: _galleryFilter == 2,
              onSelected: () => setState(() => _galleryFilter = 2),
            ),
            _filterChip(
              label: 'Other',
              selected: _galleryFilter == 3,
              onSelected: () => setState(() => _galleryFilter = 3),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: NeonButton(
            label: busy ? 'Preparing secure upload…' : 'Upload & Share',
            icon: Icons.upload_rounded,
            colors: const [kCyan, kGreen],
            onPressed: busy ? null : upload,
          ),
        ),
        const SizedBox(height: 14),
        if (visibleGallery.isEmpty)
          GlassCard(
            glowColor: kPink,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      _galleryFilter > 1
                          ? Icons.video_library_outlined
                          : Icons.photo_library_outlined,
                      color: kPink,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _galleryFilter > 1
                          ? 'No ${_galleryFilter == 2 ? 'videos' : 'other files'} are stored.'
                          : 'No distributed images yet.',
                    ),
                    if (_galleryFilter > 1) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'HiveNet currently replicates encrypted image files.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          ...visibleGallery.map((entry) => _encryptedImageBar(c, entry)),
        /* Legacy thumbnail grid, deliberately not used for encrypted files.
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: gallery.length,
            itemBuilder: (c, i) {
              final g = gallery[i];
              return GestureDetector(
                onTap: () => showDistributedImage(g),
                child: GlassCard(
                  glowColor: kPink,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ShimmerBox(height: double.infinity),
                              const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.white54,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        g.meta.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${size(g.meta.bytes)} · ${g.locations.length} replica(s)',
                        style: const TextStyle(fontSize: 10, color: kCyan),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          */
      ],
    );
  }

  // ─── router page ──────────────────────────────────────────────────────────

  Widget _router(BuildContext c) {
    final selected = selectReplicaPeers(
      peers,
      (p) => PeerCandidate(
        key: p.key,
        freeBytes: p.free,
        latencyMs: p.latencyMs,
        online: p.online,
        successes: p.successes,
        failures: p.failures,
      ),
      0,
    );
    final dark = Theme.of(c).brightness == Brightness.dark;

    return _tabList(
      index: 4,
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Smart Router', color: kAmber),

        // Animated topology diagram
        GlassCard(
          glowColor: kAmber,
          padding: const EdgeInsets.all(0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 200,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _routerAnimCtrl,
                      builder: (context, _) => CustomPaint(
                        painter: RouterTopologyPainter(
                          _routerAnimCtrl.value,
                          onlinePeers: onlineCount,
                          totalPeers: peers.length,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 18,
                    child: Row(
                      children: const [
                        PulsingDot(color: kCyan, size: 6),
                        SizedBox(width: 7),
                        Text(
                          'LIVE ROUTES',
                          style: TextStyle(
                            color: kCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    bottom: 15,
                    left: 0,
                    right: 0,
                    child: Text(
                      'LOCAL COORDINATOR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        GlassCard(
          glowColor: kAmber,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: kAmber),
                  const SizedBox(width: 10),
                  const Text(
                    'Two independent replicas',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  AnimatedStatusPill(
                    online: selected.length == 2,
                    label: selected.length == 2 ? 'Ready' : 'Needs peers',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Scores use actual free space, probe latency, availability, and verified-transfer reliability.',
                style: TextStyle(
                  color: dark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                ),
              ),
              ...selected.asMap().entries.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPurple, kCyan]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  title: Text(e.value.id ?? e.value.host),
                  subtitle: Text(
                    '${size(e.value.free)} free · ${e.value.latencyMs ?? '?'} ms · ${(e.value.reliability * 100).toStringAsFixed(0)}% reliable',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        NeonSectionTitle('Eligible Peer Telemetry', color: kCyan),
        ...peers.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              glowColor: p.online ? kGreen : kRed,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AnimatedStatusPill(
                  online: p.online,
                  label: p.online ? 'Eligible' : 'Offline',
                ),
                title: Text(p.id ?? p.host),
                trailing: Text(
                  p.online ? '${p.latencyMs ?? '?'} ms' : '—',
                  style: TextStyle(
                    color: p.online ? kCyan : kRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── settings page ────────────────────────────────────────────────────────

  Widget _settings(BuildContext c) {
    return _tabList(
      index: 5,
      children: [
        const SizedBox(height: 16),
        NeonSectionTitle('Settings', color: kPurple),

        GlassCard(
          glowColor: kCyan,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_circle_rounded, color: kCyan),
            title: Text(
              profile!.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${profile!.deviceNickname}\nDevice ${profile!.deviceId.substring(0, 8)}… · Android Keystore key',
            ),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kGreen,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.devices_other_rounded, color: kGreen),
            title: const Text(
              'My HiveNet Devices',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${peers.length} known LAN device${peers.length == 1 ? '' : 's'} · trust is not granted by a display name',
            ),
            onTap: () => setState(() => _tab = 2),
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kCyan,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_2_rounded, color: kCyan),
            title: const Text(
              'Pair New Device',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Generate a five-minute signed pairing QR'),
            onTap: _pairNewDevice,
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          glowColor: kAmber,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.qr_code_scanner_rounded, color: kAmber),
            title: const Text(
              'Scan QR to Connect',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Connect without typing an IP address'),
            onTap: _scanPairQr,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kPurple,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: ShaderMask(
              shaderCallback: (b) =>
                  const LinearGradient(colors: [kPurple, kCyan])
                      .createShader(b),
              child: const Text(
                'Dark Theme',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            subtitle: const Text('Use HiveNet\'s cyberpunk dark palette.'),
            value: themeMode.value == ThemeMode.dark,
            onChanged: (v) =>
                themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
            activeColor: kPurple,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kCyan,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.network_check_outlined, color: kCyan),
            title: const Text(
              'Run Diagnostics',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(status),
            onTap: refresh,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kAmber,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.repeat_rounded, color: kAmber),
            title: Text(
              'Replication Factor',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Two independent verified replicas'),
            trailing: Text(
              '2',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: kAmber,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kGreen,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.memory_outlined, color: kGreen),
            title: const Text(
              'This Device',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('${PlatformNode.receiverDescription}\n$nodeId'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 10),

        GlassCard(
          glowColor: kPink,
          child: const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.verified_user_outlined, color: kPink),
            title: Text(
              'End-to-End Encryption',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('AES-256-GCM · SHA-256 content addressing'),
          ),
        ),
      ],
    );
  }

  Widget _onboarding(BuildContext c) {
    return Scaffold(
      backgroundColor: kDarkBg,
      body: Stack(
        children: [
          const _RegistrationBackdrop(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: GlassCard(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  glowColor: kCyan,
                  borderRadius: 30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: RegistrationBrandMark()),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: kCyan.withOpacity(.12),
                            border: Border.all(color: kCyan.withOpacity(.28)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'PRIVATE  •  DISTRIBUTED  •  YOURS',
                            style: TextStyle(
                              color: Color(0xff9EF5E9),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.05,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Welcome to HiveNet',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a private identity for your encrypted, device-owned cloud. No email, password, or central account.',
                        style: TextStyle(height: 1.45, color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                      AnimatedRegistrationField(
                        controller: _displayNameController,
                        labelText: 'Display name',
                        hintText: 'Rishi',
                        leadingIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      AnimatedRegistrationField(
                        controller: _deviceNicknameController,
                        labelText: 'This device nickname',
                        hintText: "Rishi's phone",
                        leadingIcon: Icons.phone_android_rounded,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: PressScale(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Create My Profile'),
                            onPressed: () async {
                              if (_displayNameController.text.trim().isEmpty ||
                                  _deviceNicknameController.text
                                      .trim()
                                      .isEmpty) {
                                ScaffoldMessenger.of(c).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter a display name and device nickname.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final created = await identityStore.create(
                                displayName: _displayNameController.text,
                                deviceNickname: _deviceNicknameController.text,
                              );
                              if (!mounted) return;
                              setState(() {
                                profile = created;
                                busy = true;
                              });
                              await init();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: PressScale(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              if (_displayNameController.text.trim().isEmpty ||
                                  _deviceNicknameController.text
                                      .trim()
                                      .isEmpty) {
                                ScaffoldMessenger.of(c).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter your name and this device nickname, then scan the QR.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final created = await identityStore.create(
                                displayName: _displayNameController.text,
                                deviceNickname: _deviceNicknameController.text,
                              );
                              if (!mounted) return;
                              setState(() {
                                profile = created;
                                busy = true;
                              });
                              await init();
                              await _scanPairQr();
                            },
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Connect Existing Device'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 16,
                            color: kCyan,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Protected by an Android-Keystore signing key. Your private key never leaves this device.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── _tab variable + build ────────────────────────────────────────────────

  int _tab = 0;

  @override
  Widget build(BuildContext c) {
    if (_isBootstrapping) return const HiveNetworkSplashScreen();
    if (profile == null) return _onboarding(c);
    final dark = Theme.of(c).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(c).bottom;
    final compactNavigation = MediaQuery.sizeOf(c).width < 390;

    final pages = [
      _home(c),
      _storage(c),
      _peers(c),
      _gallery(c),
      _router(c),
      _settings(c),
    ];
    const labels = [
      'Home',
      'Storage',
      'Peers',
      'Gallery',
      'Router',
      'Settings',
    ];
    const icons = [
      Icons.home_outlined,
      Icons.storage_outlined,
      Icons.devices_outlined,
      Icons.photo_library_outlined,
      Icons.account_tree_outlined,
      Icons.settings_outlined,
    ];
    const selectedIcons = [
      Icons.home_rounded,
      Icons.storage_rounded,
      Icons.devices_rounded,
      Icons.photo_library_rounded,
      Icons.account_tree_rounded,
      Icons.settings_rounded,
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated shifting gradient background ──
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, _) {
              final t = _bgAnimationController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.7 + t * 0.25, -0.9 + t * 0.18),
                    radius: 1.25,
                    colors: dark
                        ? [
                            kDarkSurface,
                            Color.lerp(kDarkBg, kCyan.withOpacity(0.16), t)!,
                            kDarkBg,
                          ]
                        : [
                            const Color(0xffF8FAF9),
                            Color.lerp(
                              const Color(0xffEEF2F0),
                              kCyan.withOpacity(0.07),
                              t * 0.35,
                            )!,
                            const Color(0xffEEF2F0),
                          ],
                  ),
                ),
              );
            },
          ),

          // ── Page content with animated tab switch ──
          SafeArea(
            bottom: false,
            child: TabTransitionWrapper(tabIndex: _tab, child: pages[_tab]),
          ),

          // ── Floating frosted glass navigation bar ──
          Positioned(
            bottom: bottomInset + 8,
            left: 12,
            right: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xff132129).withOpacity(0.97)
                        : Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: dark
                          ? kCyan.withOpacity(0.30)
                          : const Color(0xff203B43).withOpacity(0.18),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(dark ? 0.36 : 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(6, (i) {
                        final selected = _tab == i;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: labels[i],
                            child: PressScale(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _tab = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compactNavigation ? 2 : 5,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: selected
                                        ? kCyan.withOpacity(dark ? 0.24 : 0.14)
                                        : Colors.transparent,
                                    border: selected
                                        ? Border.all(
                                            color: kCyan.withOpacity(
                                              dark ? 0.52 : 0.34,
                                            ),
                                          )
                                        : null,
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: kCyan.withOpacity(0.18),
                                              blurRadius: 12,
                                              spreadRadius: -4,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        selected ? selectedIcons[i] : icons[i],
                                        color: selected
                                            ? kCyan
                                            : (dark
                                                  ? Colors.white70
                                                  : Colors.black54),
                                        size: compactNavigation ? 21 : 23,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        labels[i],
                                        style: TextStyle(
                                          fontSize: compactNavigation
                                              ? 8.5
                                              : 9.5,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: selected
                                              ? kCyan
                                              : (dark
                                                    ? Colors.white70
                                                    : Colors.black54),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // This must be painted above the persistent navigation. Otherwise
          // the last recovery action in a failed upload is covered on phones.
          if (uploadExperience != null)
            Positioned.fill(child: _uploadOverlay(c)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HoneycombPainter  –  decorative header background
// ─────────────────────────────────────────────────────────────────────────────
class _HoneycombPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(0.18);

    const r = 28.0; // hex radius
    const dx = r * 1.732; // horizontal step
    const dy = r * 1.5; // vertical step

    for (var row = -1; row < size.height / dy + 2; row++) {
      for (var col = -1; col < size.width / dx + 2; col++) {
        final cx = col * dx + (row.isOdd ? dx / 2 : 0);
        final cy = row * dy;
        _drawHex(canvas, Offset(cx, cy), r, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    const sides = 6;
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final angle = (i * 60 - 30) * (3.14159265358979 / 180);
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HoneycombPainter _) => false;
}
