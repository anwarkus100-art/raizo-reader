import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audio_service/audio_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xml/xml.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

late EbookAudioHandler _audioHandler;
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _audioHandler = await AudioService.init(
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
              Expanded(child: child ?? const SizedBox()),
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
            border: Border(top: BorderSide(color: dark ? Colors.white24 : Colors.black12)),
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
                onTap: () => launchUrl(Uri.parse('mailto:anwar.kus@gmail.com?subject=Raizo%20Reader')),
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
  }

  Future<void> saveAudioState() async {
    if (bookId == null || segments.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final i = index.clamp(0, segments.length - 1);
    await prefs.setInt('${bookId}_ai', i);
    await prefs.setInt('${bookId}_ap', segments[i].page);
  }

  void load(String id, String title, List<Seg> list, int start) {
    stop();
    bookId = id;
    segments = list;
    index = (start >= 0 && start < list.length) ? start : 0;
    segNotifier.value = index;
    mediaItem.add(MediaItem(id: id, title: title, album: 'Raizo Reader'));
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
      mediaItem.add(m.copyWith(artist: 'Page ${s.page} • Line ${index + 1}/${segments.length}'));
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
      controls: [MediaControl.skipToPrevious, MediaControl.pause, MediaControl.skipToNext],
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
    playbackState.add(playbackState.value.copyWith(playing: false, processingState: AudioProcessingState.idle));
  }

  @override
  Future<void> skipToNext() async => jump(index + 1);

  @override
  Future<void> skipToPrevious() async => jump(index - 1);
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

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <Map<String, dynamic>>[];
    for (final k in prefs.getKeys().where((k) => k.endsWith('_meta'))) {
      final raw = prefs.getString(k);
      if (raw != null) list.add(jsonDecode(raw));
    }
    list.sort((a, b) => ((b['ts'] ?? 0) as int).compareTo((a['ts'] ?? 0) as int));
    if (mounted) setState(() => books = list);
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub', 'txt', 'fb2', 'html'],
    );
    if (res?.files.single.path != null) {
      await _openBook(File(res!.files.single.path!), false);
    }
  }

  Future<void> _openBook(File file, bool restart) async {
    if (!await file.exists()) return;
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
          final lines = txt.split(RegExp(r'\n+')).map((s) => s.trim()).where((s) => s.isNotEmpty);
          if (lines.isEmpty) {
            segs.add(Seg(i + 1, 'Page ${i + 1}'));
          } else {
            for (final l in lines) {
              segs.add(Seg(i + 1, l));
            }
          }
        }
        doc.dispose();
      } else if (ext == 'epub') {
        final book = await EpubReader.readBook(await file.readAsBytes());
        final chs = book.Chapters ?? [];
        for (int i = 0; i < chs.length; i++) {
          final txt = XmlDocument.parse(chs[i].HtmlContent ?? '').innerText;
          pages.add(txt);
          for (final l in txt.split(RegExp(r'\n+')).map((s) => s.trim()).where((s) => s.isNotEmpty)) {
            segs.add(Seg(i + 1, l));
          }
        }
      } else {
        final raw = await file.readAsString(encoding: utf8);
        final txt = (ext == 'fb2' || ext == 'html') ? XmlDocument.parse(raw).innerText : raw;
        pages.add(txt);
        for (final l in txt.split(RegExp(r'\n+')).map((s) => s.trim()).where((s) => s.isNotEmpty)) {
          segs.add(Seg(1, l));
        }
      }

      if (pages.isEmpty) pages.add('Empty Document');
      final prefs = await SharedPreferences.getInstance();
      final p = restart ? 1 : (prefs.getInt('${id}_p') ?? 1);
      final ai = restart ? 0 : (prefs.getInt('${id}_ai') ?? 0);
      final z = restart ? 1.0 : (prefs.getDouble('${id}_z') ?? 1.0);

      await prefs.setString('${id}_meta', jsonEncode({
        'id': id,
        'title': name,
        'path': file.path,
        'ext': ext,
        'page': p,
        'total': pages.length,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }));

      setState(() => loading = false);
      if (!mounted) return;
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
      setState(() => loading = false);
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
            onPressed: () => themeNotifier.value = dark ? ThemeMode.light : ThemeMode.dark,
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
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  ),
                  const SizedBox(height: 20),
                  const Text('Continue Reading', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                  leading: CircleAvatar(child: Text((b['ext'] ?? 'B').toString().toUpperCase())),
                                  title: Text(b['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('Last Page: ${b['page'] ?? 1} / ${b['total'] ?? 1}'),
                                  onTap: () => _openBook(File(b['path']), false),
                                  trailing: TextButton(
                                    onPressed: () => _openBook(File(b['path']), true),
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

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
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
    _audioHandler.load(widget.id, widget.title, widget.segs, widget.initAudio);
  }

  @override
  void dispose() {
    _saveState();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _saveState();
      _audioHandler.saveAudioState();
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${widget.id}_p', page);
    await prefs.setDouble('${widget.id}_z', zoom);
    final raw = prefs.getString('${widget.id}_meta');
    if (raw != null) {
      final m = jsonDecode(raw);
      m['page'] = page;
      m['ts'] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString('${widget.id}_meta', jsonEncode(m));
    }
  }

  void _goPage(int p) {
    final t = p.clamp(1, widget.pages.length);
    setState(() => page = t);
    if (widget.ext == 'pdf') {
      _pdfCtrl.jumpToPage(t);
    } else if (_pageCtrl.hasClients) {
      _pageCtrl.jumpToPage(t - 1);
    }
    _saveState();
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
          IconButton(icon: const Icon(Icons.zoom_out), onPressed: () => _setZoom(-0.25)),
          IconButton(icon: const Icon(Icons.zoom_in), onPressed: () => _setZoom(0.25)),
          PopupMenuButton<Lang>(
            icon: Text(lang.flag, style: const TextStyle(fontSize: 18)),
            onSelected: (l) async {
              if (await _audioHandler.setLang(l)) setState(() => lang = l);
            },
            itemBuilder: (_) => languages
                .map((l) => PopupMenuItem(value: l, child: Text('${l.flag} ${l.name}')))
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
                  onPressed: () => _audioHandler.jumpPage(page),
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
                          if (widget.initPage > 1) _pdfCtrl.jumpToPage(widget.initPage);
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
                            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                            style: TextStyle(fontSize: 16 * zoom, height: 1.5),
                          ),
                        ),
                      ),
                ValueListenableBuilder<int>(
                  valueListenable: _audioHandler.segNotifier,
                  builder: (_, active, __) => ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.segs.length,
                    itemBuilder: (_, i) {
                      final s = widget.segs[i];
                      final cur = i == active;
                      return ListTile(
                        selected: cur,
                        selectedTileColor: Colors.indigo.withOpacity(0.15),
                        title: Text(
                          s.text,
                          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                          style: TextStyle(fontWeight: cur ? FontWeight.bold : FontWeight.normal),
                        ),
                        subtitle: Text('Page ${s.page}'),
                        onTap: () => _audioHandler.jump(i),
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
                          _audioHandler.setRate(v);
                        },
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _audioHandler.playNotifier,
                  builder: (_, playing, __) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(icon: const Icon(Icons.skip_previous), onPressed: _audioHandler.skipToPrevious),
                      FilledButton.icon(
                        onPressed: playing ? _audioHandler.pause : _audioHandler.play,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                        label: Text(playing ? 'Pause' : 'Listen Audio'),
                      ),
                      IconButton(icon: const Icon(Icons.skip_next), onPressed: _audioHandler.skipToNext),
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
