import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

void main() {
  runApp(CatchTheBallDeluxeApp());
}

class CatchTheBallDeluxeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catch the Ball Deluxe',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TutorialScreen()));
    });
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon.png', width: 100),
            SizedBox(height: 20),
            Text('Catch the Ball Deluxe', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class TutorialScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('How to Play', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Text('Drag the paddle to catch falling balls.', style: TextStyle(fontSize: 18)),
            Text('Avoid obstacles and grab power-ups!', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen())),
              child: Text('Start Game'),
            ),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  double paddleX = 0;
  double paddleWidth = 100;
  double paddleHeight = 20;
  double ballX = 0;
  double ballY = 0;
  double ballRadius = 10;
  double ballSpeed = 5;
  int score = 0;
  int highScore = 0;
  int level = 1;
  bool isGameOver = false;
  bool hasPowerUp = false;
  Color paddleColor = Colors.blue;
  List<Map<String, dynamic>> leaderboard = [];
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    loadHighScore();
    resetBall();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1))
      ..addListener(() {
        if (!isGameOver) {
          setState(() {
            ballY += ballSpeed;
            if (ballY + ballRadius > MediaQuery.of(context).size.height - paddleHeight &&
                ballX > paddleX &&
                ballX < paddleX + paddleWidth) {
              score++;
              _audioPlayer.play(AssetSource('sounds/catch.wav'));
              if (score > highScore) {
                highScore = score;
                saveHighScore();
              }
              if (score % 10 == 0) levelUp();
              resetBall();
              if (Random().nextInt(10) < 2) applyPowerUp();
            }
            if (ballY > MediaQuery.of(context).size.height) {
              _audioPlayer.play(AssetSource('sounds/miss.wav'));
              setState(() {
                isGameOver = true;
                updateLeaderboard();
              });
            }
          });
        }
      });
    _controller.repeat();
    _audioPlayer.play(AssetSource('sounds/background.mp3'), mode: PlayerMode.mediaPlayer);
  }

  void resetBall() {
    ballX = Random().nextDouble() * (MediaQuery.of(context).size.width - 2 * ballRadius) + ballRadius;
    ballY = 0;
    ballSpeed = 5 + level * 0.5;
  }

  void levelUp() {
    level++;
    paddleWidth = paddleWidth.clamp(50, 100);
  }

  void applyPowerUp() {
    hasPowerUp = true;
    paddleWidth = 150;
    _audioPlayer.play(AssetSource('sounds/powerup.wav'));
    Future.delayed(Duration(seconds: 5), () {
      setState(() {
        hasPowerUp = false;
        paddleWidth = 100;
      });
    });
  }

  void loadHighScore() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('highScore') ?? 0;
      leaderboard = (prefs.getStringList('leaderboard') ?? []).asMap().entries.map((e) => {
            'score': int.parse(e.value.split(':')[0]),
            'date': e.value.split(':')[1],
          }).toList();
    });
  }

  void saveHighScore() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('highScore', highScore);
  }

  void updateLeaderboard() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    leaderboard.add({'score': score, 'date': DateTime.now().toString()});
    leaderboard.sort((a, b) => b['score'].compareTo(a['score']));
    leaderboard = leaderboard.take(5).toList();
    prefs.setStringList('leaderboard', leaderboard.map((e) => '${e['score']}:${e['date']}').toList());
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Level $level'),
        actions: [
          IconButton(
            icon: Icon(Icons.color_lens),
            onPressed: () {
              setState(() {
                paddleColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.leaderboard),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Leaderboard'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: leaderboard
                        .asMap()
                        .entries
                        .map((e) => Text('${e.key + 1}. ${e.value['score']} - ${e.value['date'].substring(0, 10)}'))
                        .toList(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            paddleX = details.localPosition.dx - paddleWidth / 2;
            paddleX = paddleX.clamp(0, MediaQuery.of(context).size.width - paddleWidth);
          });
        },
        child: Stack(
          children: [
            CustomPaint(
              painter: GamePainter(paddleX, paddleWidth, paddleHeight, ballX, ballY, ballRadius, paddleColor),
              child: Container(),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Text(
                'Score: $score\nHigh Score: $highScore',
                style: TextStyle(fontSize: 20, color: Colors.black),
              ),
            ),
            if (isGameOver)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Game Over!',
                      style: TextStyle(fontSize: 40, color: Colors.red),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isGameOver = false;
                          score = 0;
                          level = 1;
                          paddleWidth = 100;
                          resetBall();
                        });
                      },
                      child: Text('Restart'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final double paddleX, paddleWidth, paddleHeight, ballX, ballY, ballRadius;
  final Color paddleColor;

  GamePainter(this.paddleX, this.paddleWidth, this.paddleHeight, this.ballX, this.ballY, this.ballRadius, this.paddleColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paddlePaint = Paint()..color = paddleColor;
    final ballPaint = Paint()..color = Colors.red;

    canvas.drawRect(
      Rect.fromLTWH(paddleX, size.height - paddleHeight, paddleWidth, paddleHeight),
      paddlePaint,
    );
    canvas.drawCircle(
      Offset(ballX, ballY),
      ballRadius,
      ballPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
