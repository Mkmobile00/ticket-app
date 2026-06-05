import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class TrailerArgs {
  final String videoId;
  final String title;
  const TrailerArgs(this.videoId, {this.title = 'Trailer'});
}

/// Plays a YouTube trailer in-app via the IFrame player (sets the proper
/// embed origin, so it works where a raw WebView throws "error 153").
class TrailerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  const TrailerScreen({super.key, required this.videoId, this.title = 'Trailer'});

  @override
  State<TrailerScreen> createState() => _TrailerScreenState();
}

class _TrailerScreenState extends State<TrailerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerScaffold(
      controller: _controller,
      builder: (context, player) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title),
        ),
        body: Center(child: player),
      ),
    );
  }
}

/// Extract the 11-char YouTube id from a watch / embed / youtu.be / shorts URL.
String? youtubeIdFrom(String? url) {
  if (url == null) return null;
  final m = RegExp(r'(?:embed/|watch\?v=|youtu\.be/|shorts/|v/)([A-Za-z0-9_-]{11})').firstMatch(url);
  return m?.group(1);
}
