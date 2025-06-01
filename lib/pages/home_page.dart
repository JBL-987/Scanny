import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:scanny/auth/auth_service.dart';
import 'package:scanny/pages/object_scanner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<CameraDescription> cameras = [];
  bool _isLoading = true;
  late AnimationController _animationController;

  void logout() {
    final _auth = Authservice();
    _auth.signOut();
  }

  @override
  void initState() {
    super.initState();
    _initializeCameras();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint('Error getting cameras: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToScanner() async {
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No camera available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ObjectScanner(cameras: cameras)),
    );
  }

  Widget _buildFriendlyCamera() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive camera size based on screen width
        double screenWidth = MediaQuery.of(context).size.width;
        double cameraSize = screenWidth * 0.4; // 40% of screen width
        cameraSize = cameraSize.clamp(120.0, 180.0); // Min 120, Max 180

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              width: cameraSize,
              height: cameraSize,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 248, 225, 1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color.fromRGBO(255, 193, 7, 1),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(
                      255,
                      193,
                      7,
                      1,
                    ).withOpacity(_animationController.value * 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📷', style: TextStyle(fontSize: cameraSize * 0.33)),
                  SizedBox(height: cameraSize * 0.04),
                  Text(
                    'Smart Camera',
                    style: TextStyle(
                      fontSize: (cameraSize * 0.09).clamp(14.0, 16.0),
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(66, 66, 66, 1),
                    ),
                  ),
                  SizedBox(height: cameraSize * 0.02),
                  Container(
                    width: cameraSize * 0.44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(76, 175, 80, 1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 253, 245, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(255, 248, 225, 1),
        elevation: 0,
        title: Row(
          children: [
            const Text('🌟', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Scanny',
                style: TextStyle(
                  fontSize: screenWidth < 350 ? 16 : 18,
                  color: const Color.fromRGBO(66, 66, 66, 1),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Text('🎯', style: TextStyle(fontSize: 24)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 152, 0, 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Text('👋', style: TextStyle(fontSize: 20)),
              onPressed: logout,
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color.fromRGBO(255, 193, 7, 1),
              strokeWidth: 5,
            ),
            const SizedBox(height: 16),
            Text(
              '🔄 Loading camera...',
              style: TextStyle(
                color: const Color.fromRGBO(255, 193, 7, 1),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.05, // 5% of screen width
            ),
            child: Column(
              children: [
                SizedBox(height: isSmallScreen ? 12 : 20),

                // Welcome message container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 248, 225, 1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 224, 130, 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Discover amazing things around you!',
                          style: TextStyle(
                            color: const Color.fromRGBO(66, 66, 66, 1),
                            fontSize: screenWidth < 350 ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isSmallScreen ? 20 : 40),

                // Camera widget
                Center(child: _buildFriendlyCamera()),

                SizedBox(height: isSmallScreen ? 20 : 40),

                // Features container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_emotions,
                            color: Colors.orange.shade400,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cool Features',
                            style: TextStyle(
                              fontSize: screenWidth < 350 ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      _FeatureItem(
                        emoji: '👁️',
                        title: 'See instantly',
                        description: 'Know what things are right away',
                        color: Colors.purple.shade400,
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      _FeatureItem(
                        emoji: '🔍',
                        title: 'Easy Zoom',
                        description: 'Make things bigger with your finger',
                        color: Colors.teal.shade400,
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      _FeatureItem(
                        emoji: '🔦',
                        title: 'FlashLight',
                        description: "Turn on light when it's dark",
                        color: Colors.amber.shade400,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isSmallScreen ? 16 : 24),

                // Start button
                SizedBox(
                  width: double.infinity,
                  height: isSmallScreen ? 50 : 60,
                  child: ElevatedButton(
                    onPressed: _navigateToScanner,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(255, 193, 7, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                      shadowColor: const Color.fromRGBO(255, 193, 7, 0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '🚀',
                          style: TextStyle(fontSize: isSmallScreen ? 24 : 28),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Let\'s Start!',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '⭐',
                          style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isSmallScreen ? 16 : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final Color color;

  const _FeatureItem({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 350;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              emoji,
              style: TextStyle(fontSize: isSmallScreen ? 20 : 24),
            ),
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: const Color.fromRGBO(66, 66, 66, 1),
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: const Color.fromRGBO(117, 117, 117, 1),
                    fontSize: isSmallScreen ? 12 : 14,
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