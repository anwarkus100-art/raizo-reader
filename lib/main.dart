import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'audio_handler.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => EbookAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.arsolutionbd.raizo.audio',
      androidNotificationChannelName: 'Raizo Reader Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  runApp(const RaizoReaderApp());
}

class RaizoReaderApp extends StatelessWidget {
  const RaizoReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Raizo Reader',
        themeMode: mode,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        builder: (context, child) => Scaffold(
          body: Column(
            children: [
              // The footer already handles the bottom system inset, so the
              // routes above it must not add it a second time.
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: child ?? const SizedBox(),
                ),
              ),
              const PermanentFooter(),
            ],
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class PermanentFooter extends StatelessWidget {
  const PermanentFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF181A20) : const Color(0xFFECEFF4),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: dark ? Colors.white24 : Colors.black12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Free tool by A&R Solution BD',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : Colors.black87,
                ),
              ),
              InkWell(
                onTap: () => launchUrl(
                  Uri.parse('mailto:anwar.kus@gmail.com?subject=Raizo%20Reader'),
                ),
                child: Text(
                  'anwar.kus@gmail.com',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 11,
                    color: dark ? Colors.lightBlueAccent : Colors.blue[800],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Set once in main() before runApp().
late EbookAudioHandler audioHandler;

class Lang {
  final String name, code, flag;
  final List<String> fallbacks;
  const Lang(this.name, this.code, this.flag, [this.fallbacks = const []]);
}

const List<Lang> languages = [
  Lang('বাংলা (Bengali)', 'bn-BD', '🇧🇩', ['bn-IN', 'bn']),
  Lang('العربية (Arabic)', 'ar-SA', '🇸🇦', ['ar', 'ar-XA', 'ar-EG']),
  Lang('English', 'en-US', '🇺🇸', ['en-GB', 'en']),
  Lang('中文 (Mandarin)', 'zh-CN', '🇨🇳', ['zh-TW', 'zh']),
  Lang('हिन्दी (Hindi)', 'hi-IN', '🇮🇳', ['hi']),
  Lang('Español (Spanish)', 'es-ES', '🇪🇸', ['es-MX', 'es']),
  Lang('Français (French)', 'fr-FR', '🇫🇷', ['fr']),
  Lang('Русский (Russian)', 'ru-RU', '🇷🇺', ['ru']),
  Lang('Português', 'pt-BR', '🇧🇷', ['pt']),
  Lang('اردو (Urdu)', 'ur-PK', '🇵🇰', ['ur']),
  Lang('Indonesia', 'id-ID', '🇮🇩', ['id']),
  Lang('日本語 (Japanese)', 'ja-JP', '🇯🇵', ['ja']),
];

class Seg {
  final int page;
  final String text;
  const Seg(this.page, this.text);
}

class EbookAudioHandler extends BaseAudioHandler with SeekHandler {
  final FlutterTts _tts = FlutterTts();
  List<Seg> segments = [];
  int index = 0;
  bool playing = false;
  String? bookId;

  final ValueNotifier<int> segNotifier = ValueNotifier(0);
  final ValueNotifier<bool> playNotifier = ValueNotifier(false);

  EbookAudioHandler() {
    _tts.setLanguage('bn-BD');
    _tts.setSpeechRate(0.5);
    _tts.awaitSpeakCompletion(true);
    _tts.setCompletionHandler(() {
      if (playing && index < segments.length - 1) {
        index++;
        segNotifier.value = index;
        saveAudioState();
        _speak();
      } else {
        stop();
      }
    });
    _tts.setErrorHandler((message) {
      stop();
    });
  }

  Future<void> saveAudioState() async {
    if (bookId == null || segments.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final i = index.clamp(0, segments.length - 1);
    await prefs.setInt('${bookId}_ai', i);
    await prefs.setInt('${bookId}_ap', segments[i].page);
  }

  /// Loads a new book. The previous book's position was already saved on
  /// every segment change, so nothing is written here.
  void load(String id, String title, List<Seg> list, int start) {
    playing = false;
    playNotifier.value = false;
    _tts.stop();
    WakelockPlus.disable();
    bookId = id;
    segments = list;
    index = (start >= 0 && start < list.length) ? start : 0;
    segNotifier.value = index;
    mediaItem.add(MediaItem(id: id, title: title, album: 'Raizo Reader'));
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  Future<bool> setLang(Lang l) async {
    for (final c in [l.code, ...l.fallbacks]) {
      if (await _tts.isLanguageAvailable(c) == true) {
        await _tts.setLanguage(c);
        if (playing) {
          await _tts.stop();
          _speak();
        }
        return true;
      }
    }
    return false;
  }

  Future<void> setRate(double r) => _tts.setSpeechRate(r);

  Future<void> jump(int i) async {
    if (i < 0 || i >= segments.length) return;
    index = i;
    segNotifier.value = i;
    await saveAudioState();
    if (playing) {
      await _tts.stop();
      _speak();
    } else {
      play();
    }
  }

  Future<void> jumpPage(int p) async {
    final i = segments.indexWhere((s) => s.page >= p);
    if (i != -1) await jump(i);
  }

  Future<void> _speak() async {
    if (segments.isEmpty || index >= segments.length) return;
    final s = segments[index];
    final m = mediaItem.value;
    if (m != null) {
      mediaItem.add(m.copyWith(
        artist: 'Page ${s.page} • Line ${index + 1}/${segments.length}',
      ));
    }
    await _tts.speak(s.text);
  }

  @override
  Future<void> play() async {
    if (segments.isEmpty) return;
    playing = true;
    playNotifier.value = true;
    WakelockPlus.enable();
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
      playing: true,
      processingState: AudioProcessingState.ready,
    ));
    await _speak();
  }

  @override
  Future<void> pause() async {
    playing = false;
    playNotifier.value = false;
    await _tts.stop();
    await saveAudioState();
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> stop() async {
    playing = false;
    playNotifier.value = false;
    WakelockPlus.disable();
    await _tts.stop();
    await saveAudioState();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
    ));
  }

  @override
  Future<void> skipToNext() async => jump(index + 1);

  @override
  Future<void> skipToPrevious() async => jump(index - 1);
}
import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart' as epub;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'audio_handler.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

/// Converts HTML / XHTML / FB2 markup to plain text without needing a strict
/// XML parser (real-world HTML is usually not well-formed XML).
String htmlToText(String html) {
  var s = html
      .replaceAll(
        RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true),
        '',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|h[1-6]|li|tr|section|article)>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
  return s
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n')
      .trim();
}

/// Splits text into lines for text-to-speech. Very long lines are broken at
/// sentence ends so the TTS engine never receives an oversized string.
List<Seg> toSegs(int page, String text) {
  const maxLen = 300;
  final out = <Seg>[];
  for (final line in text.split(RegExp(r'\n+'))) {
    final t = line.trim();
    if (t.isEmpty) continue;
    if (t.length <= maxLen) {
      out.add(Seg(page, t));
      continue;
    }
    var buf = '';
    for (final part in t.split(RegExp(r'(?<=[।.!?])\s+'))) {
      if (buf.isNotEmpty && buf.length + part.length + 1 > maxLen) {
        out.add(Seg(page, buf));
        buf = part;
      } else {
        buf = buf.isEmpty ? part : '$buf $part';
      }
    }
    if (buf.isNotEmpty) out.add(Seg(page, buf));
  }
  return out;
}

void _flattenChapters(
  List<epub.EpubChapter>? list,
  List<epub.EpubChapter> out,
  Set<String> seenFiles,
) {
  for (final c in list ?? const <epub.EpubChapter>[]) {
    final file = c.ContentFileName ?? '';
    // Sub-chapters often point into the same file; skip repeats.
    if (file.isEmpty || seenFiles.add(file)) out.add(c);
    _flattenChapters(c.SubChapters, out, seenFiles);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> books = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <Map<String, dynamic>>[];
    for (final k in prefs.getKeys().where((k) => k.endsWith('_meta'))) {
      final raw = prefs.getString(k);
      if (raw == null) continue;
      try {
        list.add(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    list.sort((a, b) => ((b['ts'] ?? 0) as int).compareTo((a['ts'] ?? 0) as int));
    if (mounted) setState(() => books = list);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'txt', 'fb2', 'html'],
    );
    final path = res?.files.single.path;
    if (path != null) {
      await _openBook(File(path), false);
    }
  }

  Future<void> _openBook(File file, bool restart) async {
    if (!await file.exists()) {
      _toast('This file is no longer available. Please pick it again.');
      return;
    }
    setState(() => loading = true);
    try {
      final name = file.path.split(Platform.pathSeparator).last;
      final ext = name.split('.').last.toLowerCase();
      final id = '${name}_${await file.length()}';
      final pages = <String>[];
      final segs = <Seg>[];

      if (ext == 'pdf') {
        final doc = PdfDocument(inputBytes: await file.readAsBytes());
        final extor = PdfTextExtractor(doc);
        for (int i = 0; i < doc.pages.count; i++) {
          final txt = extor.extractText(startPageIndex: i, endPageIndex: i);
          pages.add(txt);
          final pageSegs = toSegs(i + 1, txt);
          if (pageSegs.isEmpty) {
            segs.add(Seg(i + 1, 'Page ${i + 1}'));
          } else {
            segs.addAll(pageSegs);
          }
          // Let the spinner keep animating on large files.
          if (i % 10 == 9) await Future<void>.delayed(Duration.zero);
        }
        doc.dispose();
      } else if (ext == 'epub') {
        final book = await epub.EpubReader.readBook(await file.readAsBytes());
        final chapters = <epub.EpubChapter>[];
        _flattenChapters(book.Chapters, chapters, <String>{});
        for (final ch in chapters) {
          final txt = htmlToText(ch.HtmlContent ?? '');
          if (txt.isEmpty) continue;
          pages.add(txt);
          segs.addAll(toSegs(pages.length, txt));
        }
      } else {
        final raw = utf8.decode(await file.readAsBytes(), allowMalformed: true);
        final txt = (ext == 'fb2' || ext == 'html') ? htmlToText(raw) : raw;
        pages.add(txt);
        segs.addAll(toSegs(1, txt));
      }

      if (pages.isEmpty) pages.add('Empty Document');
      final prefs = await SharedPreferences.getInstance();
      final p = restart ? 1 : (prefs.getInt('${id}_p') ?? 1);
      final ai = restart ? 0 : (prefs.getInt('${id}_ai') ?? 0);
      final z = restart ? 1.0 : (prefs.getDouble('${id}_z') ?? 1.0);

      await prefs.setString(
        '${id}_meta',
        jsonEncode({
          'id': id,
          'title': name,
          'path': file.path,
          'ext': ext,
          'page': p,
          'total': pages.length,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (!mounted) return;
      setState(() => loading = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            id: id,
            title: name,
            path: file.path,
            ext: ext,
            pages: pages,
            segs: segs,
            initPage: p,
            initAudio: ai,
            initZoom: z,
          ),
        ),
      );
      _loadRecent();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _toast('Could not open this file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raizo Reader'),
        actions: [
          IconButton(
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () =>
                themeNotifier.value = dark ? ThemeMode.light : ThemeMode.dark,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Open PDF / EPUB / eBook'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Continue Reading',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: books.isEmpty
                        ? const Center(child: Text('No recent books'))
                        : ListView.builder(
                            itemCount: books.length,
                            itemBuilder: (_, i) {
                              final b = books[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      (b['ext'] ?? 'B').toString().toUpperCase(),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  title: Text(
                                    b['title'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'Last Page: ${b['page'] ?? 1} / ${b['total'] ?? 1}',
                                  ),
                                  onTap: () => _openBook(File(b['path']), false),
                                  trailing: TextButton(
                                    onPressed: () =>
                                        _openBook(File(b['path']), true),
                                    child: const Text('Start from beginning'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class ReaderScreen extends StatefulWidget {
  final String id, title, path, ext;
  final List<String> pages;
  final List<Seg> segs;
  final int initPage, initAudio;
  final double initZoom;

  const ReaderScreen({
    super.key,
    required this.id,
    required this.title,
    required this.path,
    required this.ext,
    required this.pages,
    required this.segs,
    required this.initPage,
    required this.initAudio,
    required this.initZoom,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with WidgetsBindingObserver {
  bool audioMode = false;
  Lang lang = languages.first;
  double speed = 0.5;
  late int page;
  late double zoom;
  final PdfViewerController _pdfCtrl = PdfViewerController();
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    page = widget.initPage.clamp(1, widget.pages.length);
    zoom = widget.initZoom.clamp(1.0, 3.0);
    _pageCtrl = PageController(initialPage: page - 1);
    audioHandler.load(widget.id, widget.title, widget.segs, widget.initAudio);
  }

  @override
  void dispose() {
    _saveState();
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _saveState();
      audioHandler.saveAudioState();
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${widget.id}_p', page);
    await prefs.setDouble('${widget.id}_z', zoom);
    final raw = prefs.getString('${widget.id}_meta');
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      m['page'] = page;
      m['ts'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString('${widget.id}_meta', jsonEncode(m));
    }
  }

  void _setZoom(double d) {
    setState(() => zoom = (zoom + d).clamp(1.0, 3.0));
    if (widget.ext == 'pdf') _pdfCtrl.zoomLevel = zoom;
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = lang.code.startsWith('ar') || lang.code.startsWith('ur');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _setZoom(-0.25),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _setZoom(0.25),
          ),
          PopupMenuButton<Lang>(
            icon: Text(lang.flag, style: const TextStyle(fontSize: 18)),
            onSelected: (l) async {
              final ok = await audioHandler.setLang(l);
              if (!mounted) return;
              if (ok) {
                setState(() => lang = l);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No ${l.name} voice is installed on this device.'),
                  ),
                );
              }
            },
            itemBuilder: (_) => languages
                .map((l) => PopupMenuItem(
                      value: l,
                      child: Text('${l.flag} ${l.name}'),
                    ))
                .toList(),
          ),
          IconButton(
            icon: Icon(audioMode ? Icons.menu_book : Icons.headphones),
            onPressed: () => setState(() => audioMode = !audioMode),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Page $page / ${widget.pages.length}'),
                TextButton.icon(
                  onPressed: () => audioHandler.jumpPage(page),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Read this page'),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: audioMode ? 1 : 0,
              children: [
                widget.ext == 'pdf'
                    ? SfPdfViewer.file(
                        File(widget.path),
                        controller: _pdfCtrl,
                        onDocumentLoaded: (_) {
                          if (widget.initPage > 1) {
                            _pdfCtrl.jumpToPage(widget.initPage);
                          }
                          _pdfCtrl.zoomLevel = zoom;
                        },
                        onPageChanged: (d) {
                          setState(() => page = d.newPageNumber);
                          _saveState();
                        },
                      )
                    : PageView.builder(
                        controller: _pageCtrl,
                        itemCount: widget.pages.length,
                        onPageChanged: (i) {
                          setState(() => page = i + 1);
                          _saveState();
                        },
                        itemBuilder: (_, i) => SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            widget.pages[i],
                            textDirection:
                                rtl ? TextDirection.rtl : TextDirection.ltr,
                            style: TextStyle(fontSize: 16 * zoom, height: 1.5),
                          ),
                        ),
                      ),
                ValueListenableBuilder<int>(
                  valueListenable: audioHandler.segNotifier,
                  builder: (_, active, __) => ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.segs.length,
                    itemBuilder: (_, i) {
                      final s = widget.segs[i];
                      final cur = i == active;
                      return ListTile(
                        selected: cur,
                        selectedTileColor: Colors.indigo.withValues(alpha: 0.15),
                        title: Text(
                          s.text,
                          textDirection:
                              rtl ? TextDirection.rtl : TextDirection.ltr,
                          style: TextStyle(
                            fontWeight: cur ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('Page ${s.page}'),
                        onTap: () => audioHandler.jump(i),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Speed'),
                    Expanded(
                      child: Slider(
                        value: speed,
                        min: 0.2,
                        max: 1.0,
                        onChanged: (v) {
                          setState(() => speed = v);
                          audioHandler.setRate(v);
                        },
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: audioHandler.playNotifier,
                  builder: (_, playing, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: audioHandler.skipToPrevious,
                      ),
                      FilledButton.icon(
                        onPressed: playing ? audioHandler.pause : audioHandler.play,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        label: Text(playing ? 'Pause' : 'Listen Audio'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: audioHandler.skipToNext,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
