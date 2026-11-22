// ignore_for_file: deprecated_member_use

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'ui/hivenet_ui.dart';

/// Every value is set by a real operation in [Dashboard], never a timer.
enum TransferStage {
  selected,
  compressing,
  encrypting,
  hashing,
  discovering,
  selecting,
  sending,
  verifying,
  complete,
  failed,
}

enum UploadStageState { pending, inProgress, completed, failed, skipped }

enum TransferPeerState { queued, transferring, verified, failed }

class TransferPeerView {
  const TransferPeerView({
    required this.name,
    required this.rank,
    required this.availableStorage,
    required this.latency,
    required this.reliability,
    required this.status,
    required this.state,
  });

  final String name;
  final String rank;
  final String availableStorage;
  final String latency;
  final String reliability;
  final String status;
  final TransferPeerState state;
}

class UploadExperience {
  const UploadExperience({
    required this.stage,
    required this.message,
    this.originalName,
    this.storedName,
    this.sha256,
    this.preview,
    this.peers = const [],
    this.error,
    this.failedStage,
    this.eligibleStoragePeers,
    this.requiredStoragePeers = 2,
  });

  final TransferStage stage;
  final String message;
  final String? originalName;
  final String? storedName;
  final String? sha256;
  final Uint8List? preview;
  final List<TransferPeerView> peers;
  final String? error;
  final TransferStage? failedStage;
  final int? eligibleStoragePeers;
  final int requiredStoragePeers;

  bool get isFinished =>
      stage == TransferStage.complete || stage == TransferStage.failed;

  /// A failure must not be interpreted as a completed final stage. The UI uses
  /// the operation that actually failed to render completed, failed, and
  /// skipped work independently.
  UploadStageState stateFor(TransferStage target) {
    if (stage == TransferStage.complete) {
      return UploadStageState.completed;
    }
    if (stage == TransferStage.failed) {
      final failedAt = failedStage ?? TransferStage.selecting;
      if (target == failedAt) return UploadStageState.failed;
      return target.index < failedAt.index
          ? UploadStageState.completed
          : UploadStageState.skipped;
    }
    if (target.index < stage.index) return UploadStageState.completed;
    if (target == stage) return UploadStageState.inProgress;
    return UploadStageState.pending;
  }
}

class IncomingTransfer {
  const IncomingTransfer({
    required this.id,
    required this.sender,
    required this.originalName,
    required this.storedName,
    required this.receivedBytes,
    required this.totalBytes,
    required this.stage,
    required this.updatedAt,
    this.error,
  });

  factory IncomingTransfer.fromPlatform(Map<dynamic, dynamic> raw) {
    int number(String key) => (raw[key] as num?)?.toInt() ?? 0;
    return IncomingTransfer(
      id: raw['id']?.toString() ?? '',
      sender: raw['sender']?.toString() ?? 'Unknown device',
      originalName: raw['originalName']?.toString() ?? 'image.jpg',
      storedName: raw['storedName']?.toString() ?? 'encryptedImage',
      receivedBytes: number('receivedBytes'),
      totalBytes: number('totalBytes'),
      stage: raw['stage']?.toString() ?? 'Incoming',
      updatedAt: number('updatedAt'),
      error: raw['error']?.toString(),
    );
  }

  final String id;
  final String sender;
  final String originalName;
  final String storedName;
  final int receivedBytes;
  final int totalBytes;
  final String stage;
  final int updatedAt;
  final String? error;

  double get progress =>
      totalBytes == 0 ? 0 : (receivedBytes / totalBytes).clamp(0, 1);
  bool get complete => stage == 'Stored Successfully';
  bool get failed => stage == 'Failed';
}

class TransferExperienceSheet extends StatefulWidget {
  const TransferExperienceSheet({
    super.key,
    required this.experience,
    required this.formatSize,
    this.onRetry,
    this.onClose,
    this.onAddPeer,
    this.onScanQr,
  });

  final UploadExperience experience;
  final String Function(int) formatSize;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;
  final VoidCallback? onAddPeer;
  final VoidCallback? onScanQr;

  @override
  State<TransferExperienceSheet> createState() =>
      _TransferExperienceSheetState();
}

class _TransferExperienceSheetState extends State<TransferExperienceSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.experience;
    final success = value.stage == TransferStage.complete;
    final failed = value.stage == TransferStage.failed;
    final color = failed
        ? kRed
        : success
        ? kGreen
        : kCyan;
    return Material(
      color: Colors.black.withOpacity(.78),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
                maxHeight: constraints.maxHeight < 820
                    ? constraints.maxHeight
                    : 820,
              ),
              child: SingleChildScrollView(
                // The final recovery action stays reachable above every phone
                // gesture area, even when the transfer details are long.
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 72),
                child: GlassCard(
                  glowColor: color,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _stageIcon(value.stage, color),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _title(value.stage),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  value.message,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          if (value.isFinished)
                            IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _VisualRoute(
                        animation: _motion,
                        peers: value.peers,
                        stage: value.stage,
                        preview: value.preview,
                      ),
                      const SizedBox(height: 18),
                      if (value.preview != null)
                        _fileRow(
                          Icons.image_outlined,
                          'Original',
                          value.originalName ?? 'Selected image',
                        ),
                      if (value.storedName != null)
                        _fileRow(
                          Icons.lock_outline_rounded,
                          'Stored as',
                          value.storedName!,
                        ),
                      if (value.sha256 != null)
                        _fileRow(
                          Icons.fingerprint_rounded,
                          'SHA-256',
                          '${value.sha256!.substring(0, 16)}…',
                        ),
                      const SizedBox(height: 8),
                      ...TransferStage.values
                          .where((stage) => stage != TransferStage.failed)
                          .take(8)
                          .map((stage) => _stageRow(stage, value)),
                      if (value.peers.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'SELECTED STORAGE DEVICES',
                          style: TextStyle(
                            color: kCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...value.peers.map(_peerCard),
                      ],
                      if (failed)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            value.error ??
                                'The transfer could not be completed.',
                            style: const TextStyle(
                              color: kRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (failed &&
                          value.failedStage == TransferStage.selecting) ...[
                        const SizedBox(height: 14),
                        _replicaRequirement(value),
                        if (widget.onAddPeer != null || widget.onScanQr != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                if (widget.onScanQr != null)
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: widget.onScanQr,
                                      icon: const Icon(
                                        Icons.qr_code_scanner_rounded,
                                      ),
                                      label: const Text('Scan QR'),
                                    ),
                                  ),
                                if (widget.onScanQr != null &&
                                    widget.onAddPeer != null)
                                  const SizedBox(width: 10),
                                if (widget.onAddPeer != null)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: widget.onAddPeer,
                                      icon: const Icon(Icons.add_link_rounded),
                                      label: const Text('Add peer'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                      if (failed && widget.onRetry != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: SizedBox(
                            width: double.infinity,
                            child: PressScale(
                              child: FilledButton.icon(
                                onPressed: widget.onRetry,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Choose another image'),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageIcon(TransferStage stage, Color color) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: color.withOpacity(.16),
      shape: BoxShape.circle,
      border: Border.all(color: color.withOpacity(.6)),
    ),
    child: Icon(
      stage == TransferStage.complete
          ? Icons.check_rounded
          : stage == TransferStage.failed
          ? Icons.error_outline_rounded
          : Icons.hub_rounded,
      color: color,
    ),
  );

  String _title(TransferStage stage) => switch (stage) {
    TransferStage.selected => 'Image selected',
    TransferStage.compressing => 'Compressing image',
    TransferStage.encrypting => 'Encrypting locally',
    TransferStage.hashing => 'Generating SHA-256 identity',
    TransferStage.discovering => 'Discovering peers',
    TransferStage.selecting => 'Selecting two replicas',
    TransferStage.sending => 'Sending verified replicas',
    TransferStage.verifying => 'Verifying replicas',
    TransferStage.complete => 'Upload complete',
    TransferStage.failed => 'Upload needs attention',
  };

  Widget _fileRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        Icon(icon, size: 16, color: kCyan),
        const SizedBox(width: 9),
        Text('$label: ', style: const TextStyle(color: Colors.white60)),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _replicaRequirement(UploadExperience value) {
    final eligible = value.eligibleStoragePeers ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAmber.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAmber.withOpacity(.35)),
      ),
      child: Text(
        '$eligible of ${value.requiredStoragePeers} required storage peers available. Connect another eligible device before uploading.',
        style: const TextStyle(color: kAmber, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _stageRow(TransferStage target, UploadExperience value) {
    final state = value.stateFor(target);
    final color = switch (state) {
      UploadStageState.completed => kGreen,
      UploadStageState.inProgress => kCyan,
      UploadStageState.failed => kRed,
      UploadStageState.skipped => Colors.white38,
      UploadStageState.pending => Colors.white24,
    };
    final icon = switch (state) {
      UploadStageState.completed => Icons.check_circle_rounded,
      UploadStageState.inProgress => Icons.radio_button_checked_rounded,
      UploadStageState.failed => Icons.cancel_rounded,
      UploadStageState.skipped => Icons.remove_circle_outline_rounded,
      UploadStageState.pending => Icons.circle_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Text(
            '${_title(target)}${state == UploadStageState.skipped ? ' — skipped' : ''}',
            style: TextStyle(
              color:
                  state == UploadStageState.pending ||
                      state == UploadStageState.skipped
                  ? Colors.white54
                  : Colors.white,
              fontWeight:
                  state == UploadStageState.inProgress ||
                      state == UploadStageState.failed
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _peerCard(TransferPeerView peer) {
    final color = switch (peer.state) {
      TransferPeerState.verified => kGreen,
      TransferPeerState.failed => kRed,
      TransferPeerState.transferring => kCyan,
      TransferPeerState.queued => Colors.white60,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  peer.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                peer.rank,
                style: const TextStyle(
                  color: kCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${peer.availableStorage} free  •  ${peer.latency}  •  ${peer.reliability}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            peer.status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualRoute extends StatelessWidget {
  const _VisualRoute({
    required this.animation,
    required this.peers,
    required this.stage,
    this.preview,
  });
  final Animation<double> animation;
  final List<TransferPeerView> peers;
  final TransferStage stage;
  final Uint8List? preview;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 165,
    child: AnimatedBuilder(
      animation: animation,
      builder: (_, child) => CustomPaint(
        painter: _RoutePainter(
          animation.value,
          active:
              stage == TransferStage.sending ||
              stage == TransferStage.verifying,
          peerCount: peers.length,
        ),
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(-.72, 0),
              child: _node(
                preview == null
                    ? const Icon(
                        Icons.phone_android_rounded,
                        color: Colors.white,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          preview!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            if (peers.isNotEmpty)
              Align(
                alignment: const Alignment(.7, -.58),
                child: _node(
                  const Icon(Icons.storage_rounded, color: Colors.white),
                  color: kPurple,
                ),
              ),
            if (peers.length > 1)
              Align(
                alignment: const Alignment(.7, .58),
                child: _node(
                  const Icon(Icons.storage_rounded, color: Colors.white),
                  color: kGreen,
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _node(Widget child, {Color color = kCyan}) => Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [BoxShadow(color: color.withOpacity(.4), blurRadius: 18)],
    ),
    child: child,
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.t, {required this.active, required this.peerCount});
  final double t;
  final bool active;
  final int peerCount;

  @override
  void paint(Canvas canvas, Size size) {
    final from = Offset(size.width * .25, size.height * .5);
    final destinations = [
      if (peerCount > 0) Offset(size.width * .78, size.height * .24),
      if (peerCount > 1) Offset(size.width * .78, size.height * .76),
    ];
    for (final to in destinations) {
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(size.width * .53, from.dy, to.dx, to.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = kCyan.withOpacity(.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      if (active) {
        final metrics = path.computeMetrics().first;
        final pos = metrics
            .getTangentForOffset(
              metrics.length * ((t + (to.dy / size.height) * .37) % 1),
            )!
            .position;
        canvas.drawCircle(
          pos,
          6,
          Paint()
            ..color = kCyan
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.t != t || old.active != active || old.peerCount != peerCount;
}

class IncomingTransferCard extends StatefulWidget {
  const IncomingTransferCard({
    super.key,
    required this.transfer,
    required this.formatSize,
  });
  final IncomingTransfer transfer;
  final String Function(int) formatSize;
  @override
  State<IncomingTransferCard> createState() => _IncomingTransferCardState();
}

class _IncomingTransferCardState extends State<IncomingTransferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.transfer;
    final color = item.failed
        ? kRed
        : item.complete
        ? kGreen
        : kAmber;
    return GlassCard(
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: Tween(begin: .9, end: 1.08).animate(_pulse),
                child: Icon(
                  item.complete
                      ? Icons.check_circle_rounded
                      : Icons.move_to_inbox_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.complete ? 'Stored successfully' : item.stage,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'From ${item.sender}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Original: ${item.originalName}\nReplica: ${item.storedName}',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: item.complete ? 1 : item.progress,
            color: color,
            backgroundColor: Colors.white12,
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.formatSize(item.receivedBytes)} of ${widget.formatSize(item.totalBytes)}  •  ${item.complete
                ? 'SHA-256 verified'
                : item.failed
                ? item.error ?? 'Failed'
                : 'Writing encrypted replica'}',
            style: TextStyle(fontSize: 11, color: color),
          ),
          if (item.complete)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Encrypted replica stored. A thumbnail is unavailable because this device does not hold the owner’s decryption key.',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ),
        ],
      ),
    );
  }
}
