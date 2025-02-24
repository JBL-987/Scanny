import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:scanny/auth/auth_service.dart';
import 'package:scanny/pages/object_scanner.dart';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

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
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
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
          content: Text('Tidak ada kamera yang tersedia'),
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

  Widget _buildScannerAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 150, // Reduced size
              height: 150, // Reduced size
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
            Positioned(
              child: Container(
                width: 130, // Adjusted for new container size
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0),
                      Colors.blue,
                      Colors.blue.withOpacity(0),
                    ],
                  ),
                ),
              ),
              top:
                  15 +
                  120 * _animationController.value, // Adjusted for new size
            ),
            Transform.rotate(
              angle: 2 * math.pi * _animationController.value,
              child: Container(
                width: 165, // Adjusted size
                height: 165, // Adjusted size
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 2,
                  ),
                ),
              ),
            ),
            ...List.generate(4, (index) {
              return Positioned(
                left: 75, // Adjusted for new center
                top: 75, // Adjusted for new center
                child: Transform.rotate(
                  angle:
                      (2 * math.pi / 4) * index +
                      (_animationController.value * 2 * math.pi),
                  child: Container(
                    width: 8, // Smaller dots
                    height: 8, // Smaller dots
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Chatta Smart Scanner',
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
              : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        'Deteksi objek secara real-time dengan teknologi AI',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(flex: 1),
                      Center(child: _buildScannerAnimation()),
                      const Spacer(flex: 1),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _FeatureItem(
                              icon: Icons.camera,
                              title: 'Deteksi Real-time',
                              description: 'Deteksi objek secara langsung',
                            ),
                            const Divider(color: Colors.white24, height: 16),
                            _FeatureItem(
                              icon: Icons.zoom_in,
                              title: 'Zoom Control',
                              description: 'Kontrol zoom dengan gesture',
                            ),
                            const Divider(color: Colors.white24, height: 16),
                            _FeatureItem(
                              icon: Icons.flash_on,
                              title: 'Flash Control',
                              description:
                                  'Kontrol flash untuk pencahayaan lebih baik',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _navigateToScanner,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 20),
                            SizedBox(width: 8),
                            Text('Mulai Scan', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
