import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'shamm_ui.dart';

Widget openLiveCall(BuildContext context, String id, String name) {
  return LiveCall(peerId: id, peerName: name);
}

bool _callOpen = false;

Future<void> watchIncoming(BuildContext context) async {
  if (_callOpen || !context.mounted) return;
  try {
    final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/calls/inbox'));
    if (raw is! List || !context.mounted) return;
    for (final item in raw.whereType<Map>()) {
      if (item['type']?.toString() != 'offer' || item['sdp'] == null) continue;
      _callOpen = true;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LiveCall(
          peerId: item['from']?.toString() ?? '',
          peerName: item['from_name']?.toString() ?? 'Staff',
          remoteOffer: item['sdp'].toString(),
        ),
      ));
      _callOpen = false;
      break;
    }
  } catch (_) {}
}

class LiveCall extends StatefulWidget {
  const LiveCall({super.key, required this.peerId, required this.peerName, this.remoteOffer});

  final String peerId;
  final String peerName;
  final String? remoteOffer;

  @override
  State<LiveCall> createState() => _LiveCallState();
}

class _LiveCallState extends State<LiveCall> {
  RTCPeerConnection? pc;
  MediaStream? local;
  Timer? poll;
  String status = 'Calling…';
  bool closed = false;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    try {
      final model = context.read<AppModel>();
      pc = await createPeerConnection({
        'iceServers': <dynamic>[],
        'sdpSemantics': 'unified-plan',
      });
      local = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      for (final track in local!.getAudioTracks()) {
        await pc!.addTrack(track, local!);
      }
      pc!.onIceCandidate = (candidate) {
        if (candidate.candidate == null) return;
        model.ask((api) => api.post('/api/v1/calls/signal', {
              'to': widget.peerId,
              'type': 'ice',
              'candidate': candidate.candidate,
            }));
      };
      pc!.onConnectionState = (state) {
        if (!mounted) return;
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          setState(() => status = 'Connected');
        }
      };
      if (widget.remoteOffer != null) {
        await pc!.setRemoteDescription(RTCSessionDescription(widget.remoteOffer, 'offer'));
        final answer = await pc!.createAnswer({'offerToReceiveAudio': true});
        await pc!.setLocalDescription(answer);
        await model.ask((api) => api.post('/api/v1/calls/signal', {
              'to': widget.peerId,
              'type': 'answer',
              'sdp': answer.sdp,
            }));
        if (mounted) setState(() => status = 'Connecting…');
      } else {
        final offer = await pc!.createOffer({'offerToReceiveAudio': true});
        await pc!.setLocalDescription(offer);
        await model.ask((api) => api.post('/api/v1/calls/signal', {
              'to': widget.peerId,
              'type': 'offer',
              'sdp': offer.sdp,
            }));
      }
      poll = Timer.periodic(const Duration(milliseconds: 400), (_) => pull());
    } catch (_) {
      if (mounted) setState(() => status = 'The call could not start. Stay on the school network and try again.');
    }
  }

  Future<void> pull() async {
    if (closed || pc == null) return;
    try {
      final raw = await context.read<AppModel>().ask((api) => api.get('/api/v1/calls/inbox'));
      if (raw is! List) return;
      for (final item in raw.whereType<Map>()) {
        final type = item['type']?.toString();
        if (type == 'answer' && item['sdp'] != null) {
          await pc!.setRemoteDescription(RTCSessionDescription(item['sdp'].toString(), 'answer'));
          if (mounted) setState(() => status = 'Connecting…');
        } else if (type == 'ice' && item['candidate'] != null) {
          await pc!.addCandidate(RTCIceCandidate(item['candidate'].toString(), '', 0));
        } else if (type == 'hangup' || type == 'reject') {
          if (mounted) setState(() => status = 'The other person ended the call');
          await hangUp(send: false);
        }
      }
    } catch (_) {}
  }

  Future<void> hangUp({bool send = true}) async {
    if (closed) return;
    closed = true;
    poll?.cancel();
    if (send) {
      try {
        await context.read<AppModel>().ask((api) => api.post('/api/v1/calls/signal', {'to': widget.peerId, 'type': 'hangup'}));
      } catch (_) {}
    }
    await local?.dispose();
    await pc?.close();
    if (mounted) Navigator.maybePop(context);
  }

  @override
  void dispose() {
    poll?.cancel();
    local?.dispose();
    pc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallBoard(name: widget.peerName, status: status, onEnd: hangUp);
  }
}
