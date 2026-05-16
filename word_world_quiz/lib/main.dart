import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'question_bank.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const WordWorldQuizApp());
}

class WordWorldQuizApp extends StatelessWidget {
  const WordWorldQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Word_World_Quiz',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: 'Roboto')),
      ),
      home: const StartScreen(),
    );
  }
}

// --- Global State ---
int highestLevel = 1;
int highestScore = 0;
int currentBonusPoints = 0;
double gameVolume = 0.5;

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with TickerProviderStateMixin {
  late AnimationController _colorController;
  late Animation<Alignment> _alignmentTop;
  late Animation<Alignment> _alignmentBottom;

  InterstitialAd? _exitInterstitialAd;
  bool _isExitAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _checkDailyReward();
    _loadExitAd();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _alignmentTop = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
    ).animate(_colorController);
    _alignmentBottom = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.bottomLeft,
    ).animate(_colorController);
  }

  void _loadExitAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-4161234516980389/7132313078',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _exitInterstitialAd = ad;
          _isExitAdLoaded = true;
        },
        onAdFailedToLoad: (LoadAdError error) => _isExitAdLoaded = false,
      ),
    );
  }

  void _handleExit() {
    if (_isExitAdLoaded && _exitInterstitialAd != null) {
      _exitInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          SystemNavigator.pop();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          SystemNavigator.pop();
        },
      );
      _exitInterstitialAd!.show();
    } else {
      SystemNavigator.pop();
    }
  }

  void _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highestLevel = prefs.getInt('highestLevel') ?? 1;
      highestScore = prefs.getInt('highestScore') ?? 0;
      currentBonusPoints = prefs.getInt('pendingBonus') ?? 0;
    });
  }

  void _checkDailyReward() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVisit = prefs.getString('last_visit') ?? "";
    final today = DateTime.now().toString().split(' ')[0];

    if (lastVisit != today) {
      prefs.setString('last_visit', today);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDailyRewardDialog());
    }
  }

  void _showDailyRewardDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Daily Reward! 🎁", textAlign: TextAlign.center),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars, size: 80, color: Colors.amber),
            SizedBox(height: 15),
            Text("Welcome back! Adding to your next game session:", textAlign: TextAlign.center),
            Text("200 POINTS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                setState(() => currentBonusPoints += 200);
                await prefs.setInt('pendingBonus', currentBonusPoints);
                if (mounted) Navigator.pop(c);
              },
              child: const Text("AWESOME"),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStartGame() async {
    final prefs = await SharedPreferences.getInstance();
    int? savedLevel = prefs.getInt('saved_level');

    if (savedLevel != null && savedLevel > 1) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Resume Game?"),
          content: Text("You were at Level $savedLevel. Continue?"),
          actions: [
            TextButton(
              onPressed: () {
                prefs.remove('saved_level');
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen(resume: false)));
              },
              child: const Text("FRESH START"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen(resume: true)));
              },
              child: const Text("RESUME"),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GameScreen(resume: false)));
    }
  }

  @override
  void dispose() {
    _colorController.dispose();
    _exitInterstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _colorController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _alignmentTop.value,
                end: _alignmentBottom.value,
                colors: const [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
              ),
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'WordWorldQuiz',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 15, color: Colors.black45, offset: Offset(3, 3))],
                ),
              ),
              const SizedBox(height: 50),
              _menuButton("START GAME", Icons.play_arrow, Colors.white, _handleStartGame),
              _menuButton("TROPHY ROOM", Icons.emoji_events, Colors.white, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen()))),
              _menuButton("SETTINGS", Icons.settings, Colors.white, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => setState(() {}))),
              _menuButton("EXIT", Icons.exit_to_app, Colors.redAccent, _handleExit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(String text, IconData icon, Color color, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(fixedSize: const Size(250, 60), backgroundColor: color, foregroundColor: color == Colors.white ? Colors.black87 : Colors.white),
        onPressed: action,
        icon: Icon(icon),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final bool resume;
  const GameScreen({super.key, required this.resume});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  late ConfettiController _confettiController;

  // --- AD UNITS ---
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isRewardedAdLoaded = false;
  InterstitialAd? _transitionAd;
  bool _isTransitionAdLoaded = false;

  int level = 1;
  int lives = 5;
  int score = 0;
  int hints = 3;
  int skips = 2;
  Timer? _timer;
  int _timeLeft = 15;
  bool isPaused = false;

  Map<String, dynamic>? currentQuestion;
  final Set<String> _usedQuestions = {};
  final Map<String, List<Map<String, dynamic>>> _questionPool = questionBank;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    
    // Load Ads
    _loadBannerAd();
    _loadRewardedAd();
    _loadTransitionAd();
    
    _initializeGame();
    _playBackgroundMusic();
  }

  // --- NEW: Load Banner Ad (From your Screenshot ID) ---
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-4161234516980389/7938898133', // Your ID from the image
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    RewardedInterstitialAd.load(
      adUnitId: 'ca-app-pub-4161234516980389/1347394110',
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          setState(() => _isRewardedAdLoaded = true);
        },
        onAdFailedToLoad: (error) => setState(() => _isRewardedAdLoaded = false),
      ),
    );
  }

  void _loadTransitionAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-4161234516980389/7450865512',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _transitionAd = ad;
          _isTransitionAdLoaded = true;
        },
        onAdFailedToLoad: (error) => _isTransitionAdLoaded = false,
      ),
    );
  }

  void _showTransitionAd() {
    if (_isTransitionAdLoaded && _transitionAd != null) {
      _timer?.cancel();
      _transitionAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadTransitionAd();
          startTimer();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadTransitionAd();
          startTimer();
        },
      );
      _transitionAd!.show();
    }
  }

  void _handleAdReward(VoidCallback onRewardEarned) {
    if (_isRewardedAdLoaded && _rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          setState(() => onRewardEarned());
          _loadRewardedAd();
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ad loading... please try again.")));
    }
  }

  // --- Game Mechanics ---
  void _playBackgroundMusic() async {
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(gameVolume);
    try { await _musicPlayer.play(AssetSource('audio/bg_music_1.wav')); } catch (e) { debugPrint("Audio Error: $e"); }
  }

  void _playSound(String fileName) async {
    await _effectPlayer.setVolume(gameVolume);
    try { await _effectPlayer.play(AssetSource('audio/$fileName')); } catch (e) { debugPrint("Effect Error: $e"); }
  }

  void _initializeGame() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (widget.resume) {
        level = prefs.getInt('saved_level') ?? 1;
        score = prefs.getInt('saved_score') ?? 0;
        lives = prefs.getInt('saved_lives') ?? 5;
        hints = prefs.getInt('saved_hints') ?? 3;
        skips = prefs.getInt('saved_skips') ?? 2;
        List<String>? used = prefs.getStringList('used_questions');
        if (used != null) _usedQuestions.addAll(used);
      } else {
        score = currentBonusPoints;
        currentBonusPoints = 0;
        prefs.setInt('pendingBonus', 0);
        _usedQuestions.clear();
      }
    });
    _generateNextQuestion();
    startTimer();
  }

  void _generateNextQuestion() {
    String diff = (level <= 110) ? "Easy" : (level <= 210) ? "Medium" : "Hard";
    var available = _questionPool[diff]!.where((item) => !_usedQuestions.contains(item['q'])).toList();
    if (available.isEmpty) { _usedQuestions.clear(); available = List.from(_questionPool[diff]!); }
    available.shuffle();
    var picked = available.first;
    _usedQuestions.add(picked['q']);
    setState(() {
      currentQuestion = {
        "q": picked['q'], "a": picked['a'],
        "o": List<String>.from(picked['o'])..shuffle(),
        "h": picked['h'] ?? "No hint available",
      };
    });
  }

  void startTimer() {
    _timeLeft = (level <= 50) ? 15 : (level <= 210) ? 10 : 7;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!isPaused && mounted) {
        setState(() {
          if (_timeLeft > 0) { _timeLeft--; } else {
            lives--;
            if (lives <= 0) _gameOver(); else nextLevel();
          }
        });
      }
    });
  }

  void nextLevel() {
    if (level >= 360) { _showVictory(); return; }
    setState(() {
      level++;
      if ((level - 1) % 70 == 0 && level > 1) { _showTransitionAd(); }
      _generateNextQuestion();
    });
    _saveProgress();
    startTimer();
  }

  void _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('saved_level', level);
    await prefs.setInt('saved_score', score);
    await prefs.setInt('saved_lives', lives);
    await prefs.setInt('saved_hints', hints);
    await prefs.setInt('saved_skips', skips);
    await prefs.setStringList('used_questions', _usedQuestions.toList());
    if (score > highestScore) { highestScore = score; await prefs.setInt('highestScore', score); }
    if (level > highestLevel) { highestLevel = level; await prefs.setInt('highestLevel', level); }
  }

  void _gameOver() async {
    _timer?.cancel();
    _musicPlayer.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_level');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("GAME OVER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(_isRewardedAdLoaded ? "Final Score: $score\nWatch an ad to get 3 lives back?" : "Final Score: $score"),
        actions: [
          if (_isRewardedAdLoaded)
            ElevatedButton(onPressed: () { Navigator.pop(c); _handleAdReward(() { lives = 3; _playBackgroundMusic(); startTimer(); }); }, child: const Text("WATCH AD (+3 LIVES)")),
          TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text("RETURN TO MENU")),
        ],
      ),
    );
  }

  void _showVictory() {
    _timer?.cancel();
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
      title: const Text("🎉 CONGRATULATIONS!"),
      content: Text("You completed all 360 levels!\nFinal Score: $score"),
      actions: [TextButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text("CHAMPION RETURN"))],
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _musicPlayer.dispose();
    _effectPlayer.dispose();
    _confettiController.dispose();
    _rewardedInterstitialAd?.dispose();
    _transitionAd?.dispose();
    _bannerAd?.dispose(); // Clean up the banner
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentQuestion == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(duration: const Duration(milliseconds: 800), color: _getDynamicLevelColor()),
          Align(alignment: Alignment.topCenter, child: ConfettiWidget(confettiController: _confettiController, blastDirectionality: BlastDirectionality.explosive)),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                const SizedBox(height: 20),
                // Main gameplay wrapped in Expanded to push Banner to the bottom
                Expanded(
                  child: Column(
                    children: [
                      _questionCard(),
                      _optionsList(),
                      _bottomControls(),
                    ],
                  ),
                ),
                // --- BANNER AD PLACEMENT ---
                if (_isBannerAdLoaded && _bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
          ),
          if (isPaused) _pauseOverlay(),
        ],
      ),
    );
  }

  Color _getDynamicLevelColor() {
    final List<Color> palettes = [Colors.lightBlueAccent.shade100, Colors.tealAccent.shade100, Colors.orangeAccent.shade100, Colors.pinkAccent.shade100, Colors.greenAccent.shade100, Colors.purpleAccent.shade100];
    return palettes[(level - 1) % palettes.length];
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statChip(Icons.emoji_events, "Score: $score", Colors.deepPurple),
          IconButton(icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 30), onPressed: () => setState(() => isPaused = !isPaused)),
          _statChip(Icons.favorite, "Lives: $lives", Colors.red),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _questionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Column(
        children: [
          Text("LEVEL $level", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text("⏱ $_timeLeft", style: const TextStyle(fontSize: 20, color: Colors.orange, fontWeight: FontWeight.bold)),
          const Divider(),
          Text(currentQuestion!['q'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _optionsList() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (c, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: isPaused ? null : () {
              if (currentQuestion!['o'][i] == currentQuestion!['a']) {
                _playSound('win.wav');
                setState(() => score += (10 * level));
                _confettiController.play();
                nextLevel();
              } else {
                _playSound('lose.wav');
                setState(() => lives--);
                if (lives <= 0) _gameOver(); else nextLevel();
              }
            },
            child: Text(currentQuestion!['o'][i], style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }

  Widget _bottomControls() {
    return Container(
      height: 90,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _btn(Icons.lightbulb, "Hint ($hints)", () {
            if (hints > 0 && !isPaused) {
              _playSound('win.wav');
              setState(() => hints--);
              showDialog(context: context, builder: (c) => AlertDialog(title: const Text("HINT"), content: Text(currentQuestion!['h']), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))]));
            }
          }),
          _btn(Icons.shopping_basket, "Store", _showShop),
          _btn(Icons.fast_forward, "Skip ($skips)", () { if (skips > 0 && !isPaused) { _playSound('win.wav'); setState(() => skips--); nextLevel(); } }),
        ],
      ),
    );
  }

  void _showShop() {
    setState(() => isPaused = true);
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Bonus Store 🛒"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _shopItem(Icons.favorite, "Extra Life", () => _handleAdReward(() => lives++)),
        _shopItem(Icons.lightbulb, "Extra Hint", () => _handleAdReward(() => hints++)),
        _shopItem(Icons.fast_forward, "Extra Skip", () => _handleAdReward(() => skips++)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("CLOSE"))],
    )).then((_) => setState(() => isPaused = false));
  }

  Widget _shopItem(IconData icon, String title, VoidCallback onBuy) {
    return ListTile(leading: Icon(icon, color: Colors.deepPurple), title: Text(title), trailing: ElevatedButton(onPressed: onBuy, child: const Text("ADD")));
  }

  Widget _btn(IconData icon, String label, VoidCallback tap) {
    return InkWell(onTap: tap, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.deepPurple), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]));
  }

  Widget _pauseOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("PAUSED", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            ElevatedButton.icon(onPressed: () => setState(() => isPaused = false), icon: const Icon(Icons.play_arrow), label: const Text("RESUME")),
            const SizedBox(height: 15),
            OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)), onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), icon: const Icon(Icons.menu), label: const Text("BACK TO MENU")),
          ],
        ),
      ),
    );
  }
}

// ... AchievementsScreen and SettingsScreen remain the same as your original code ...
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }
  @override
  void dispose() { _bgController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Trophy Room", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Stack(
        children: [
          AnimatedBuilder(animation: _bgController, builder: (c, child) => Container(decoration: BoxDecoration(gradient: SweepGradient(center: Alignment.center, transform: GradientRotation(_bgController.value * 2 * pi), colors: const [Colors.purple, Colors.orange, Colors.blue, Colors.purple])))),
          Center(
            child: Container(
              margin: const EdgeInsets.all(30), padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(30)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
                  const Text("HALL OF FAME", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const Divider(height: 30),
                  _statRow("Best Level", "$highestLevel"),
                  const SizedBox(height: 10),
                  _statRow("Highest Score", "$highestScore"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _statRow(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple))]);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Game Lab 🧪", style: TextStyle(color: Colors.white)), backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.deepPurple.shade900, Colors.purple.shade500])),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _settingsCard("Master Volume", Icons.volume_up, Colors.orangeAccent, Slider(value: gameVolume, onChanged: (v) => setState(() => gameVolume = v))),
              const SizedBox(height: 15),
              _settingsCard("Reset Progress", Icons.delete_forever, Colors.redAccent, ElevatedButton(onPressed: () async {
                final prefs = await SharedPreferences.getInstance(); await prefs.clear();
                setState(() { highestLevel = 1; highestScore = 0; currentBonusPoints = 0; });
              }, child: const Text("WIPE ALL DATA"))),
            ],
          ),
        ),
      ),
    );
  }
  Widget _settingsCard(String title, IconData icon, Color color, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
      child: Column(children: [Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Text(title, style: const TextStyle(color: Colors.white))]), child]),
    );
  }
}