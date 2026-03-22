import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyllo_ai/providers/data_provider.dart';
import 'package:fyllo_ai/providers/auth_provider.dart';
import 'package:fyllo_ai/services/scan_service.dart';
import 'package:fyllo_ai/models/expense_model.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:fyllo_ai/widgets/notifications/fyllo_snackbar.dart';
import 'package:fyllo_ai/utils/app_constants.dart';
import 'package:fyllo_ai/utils/currency_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyllo_ai/utils/error_util.dart';

class AICameraOverlay extends StatefulWidget {
  const AICameraOverlay({super.key});

  @override
  State<AICameraOverlay> createState() => _AICameraOverlayState();
}

class _AICameraOverlayState extends State<AICameraOverlay> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isProcessing = false;
  final ScanService _scanService = ScanService();
  
  // Focus indicator animation
  Offset? _focusPoint;
  AnimationController? _focusAnimationController;
  Animation<double>? _focusAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initFocusAnimation();
  }

  void _initFocusAnimation() {
    _focusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _focusAnimation = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _focusAnimationController!,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    
    final firstCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );

    try {
      _initializeControllerFuture = _controller!.initialize().then((_) async {
         await _controller?.setFlashMode(FlashMode.off);
         // Set to auto focus initially so it's ready for tap-to-focus
         await _controller?.setFocusMode(FocusMode.auto);
         if (mounted) setState(() {});
      });
    } catch (e) {
      print("Camera Init Error: $e");
    }
  }

  Future<void> _onTapToFocus(TapDownDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final offset = details.localPosition;
      final screenSize = MediaQuery.of(context).size;
      
      // Calculate blue frame boundaries
      final frameWidth = screenSize.width * 0.85;
      final frameHeight = screenSize.height * 0.6;
      final frameLeft = (screenSize.width - frameWidth) / 2;
      final frameTop = (screenSize.height - frameHeight) / 2;
      final frameRight = frameLeft + frameWidth;
      final frameBottom = frameTop + frameHeight;
      
      // Only allow focus if tap is within the blue frame structure
      if (offset.dx < frameLeft || offset.dx > frameRight ||
          offset.dy < frameTop || offset.dy > frameBottom) {
        // Tap is outside frame, ignore
        return;
      }
      
      setState(() {
        _focusPoint = offset;
      });
      
      _focusAnimationController?.reset();
      _focusAnimationController?.forward();
      
      // Fix: Normalize coordinates correctly for the camera sensor
      // Most camera sensors are rotated 90 degrees, so we map X/Y accordingly
      double fullWidth = screenSize.width;
      double fullHeight = screenSize.height;
      
      final double x = offset.dx / fullWidth;
      final double y = offset.dy / fullHeight;
      
      // Convert screen coordinates to camera sensor coordinates
      final Offset sensorPoint = Offset(y, 1.0 - x);

      await _controller!.setFocusPoint(sensorPoint);
      await _controller!.setExposurePoint(sensorPoint);
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
      
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _focusPoint = null;
          });
        }
      });
    } catch (e) {
      debugPrint("Focus Error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanService.dispose();
    _focusAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _takePictureAndProcess() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Check internet
      await _checkInternet();

      final image = await _controller!.takePicture();
      final File imageFile = File(image.path);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      String? userId = authProvider.user?.uid;
      
      if (userId == null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          userId = currentUser.uid;
        } else {
          throw Exception("AUTH_ERROR");
        }
      }

      final dataProvider = Provider.of<DataProvider>(context, listen: false);

      final Map<String, dynamic> aiData = await _scanService.processReceipt(imageFile, userId);

      final newExpense = Expense(
        id: '',
        userId: userId,
        amount: (aiData['amount'] is int) 
            ? (aiData['amount'] as int).toDouble() 
            : (aiData['amount'] as double? ?? 0.0),
        category: aiData['category'] ?? 'General',
        merchantName: aiData['merchant'] ?? 'Unknown',
        date: DateTime.tryParse(aiData['date'] ?? '') ?? DateTime.now(),
        summary: aiData['summary'] ?? '',
        aiAnalysis: aiData['aiAnalysis'] ?? aiData['auditorExplanation'] ?? 'No analysis available.',
        taxImpact: aiData['taxImpact'] ?? 'Unknown',
        deductionType: aiData['deductionType'] ?? 'General',
      );

      await dataProvider.addExpense(newExpense);

      if (mounted) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final jurisdiction = doc.exists ? doc.get('jurisdiction') : 'USA';
        final symbol = CurrencyUtil.getCurrencySymbol(jurisdiction);

        FylloSnackBar.showSuccess(
          context,
          "Expense analyzed: $symbol${newExpense.amount.toStringAsFixed(2)}",
          icon: Icons.auto_awesome_rounded,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        FylloSnackBar.showError(context, ErrorUtil.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return;
      }
    } on SocketException catch (_) {
      throw Exception("CONNECTION_ERROR");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapToFocus,
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && _controller != null) {
                  return SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize!.height,
                        height: _controller!.value.previewSize!.width,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(color: FylloColors.defaultCyan),
                  );
                }
              },
            ),
          ),
          
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // The visual frame - Expanded Size
          Center(
            child: IgnorePointer(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.90, // Expanded from 0.85 to 0.90
                height: MediaQuery.of(context).size.height * 0.75, // Expanded from 0.60 to 0.75
                decoration: BoxDecoration(
                  border: Border.all(
                    color: FylloColors.defaultCyan.withOpacity(0.6),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(24), // Slightly rounder corners
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        width: 40, // Larger corner markers
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: FylloColors.defaultCyan, width: 5),
                            left: BorderSide(color: FylloColors.defaultCyan, width: 5),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: FylloColors.defaultCyan, width: 5),
                            right: BorderSide(color: FylloColors.defaultCyan, width: 5),
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      left: -2,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: FylloColors.defaultCyan, width: 5),
                            left: BorderSide(color: FylloColors.defaultCyan, width: 5),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: FylloColors.defaultCyan, width: 5),
                            right: BorderSide(color: FylloColors.defaultCyan, width: 5),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_focusPoint != null && _focusAnimation != null)
            Positioned(
              left: _focusPoint!.dx - 40,
              top: _focusPoint!.dy - 40,
              child: AnimatedBuilder(
                animation: _focusAnimation!,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _focusAnimation!.value,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: FylloColors.defaultCyan,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.center_focus_strong,
                          color: FylloColors.defaultCyan,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: FylloColors.defaultCyan.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: FylloColors.defaultCyan,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "Tap to focus",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: FylloColors.defaultCyan.withOpacity(0.3),
                        ),
                      ),
                      child: _isProcessing 
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: FylloColors.defaultCyan,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Consulting Neural Finance Engine...",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                color: FylloColors.defaultCyan,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Align receipt within frame",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                    ),
                    const SizedBox(height: 24),
                    
                    GestureDetector(
                      onTap: _isProcessing ? null : _takePictureAndProcess,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: Colors.transparent,
                          boxShadow: [
                            BoxShadow(
                              color: FylloColors.defaultCyan.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isProcessing ? Colors.grey : FylloColors.defaultCyan,
                          ),
                          child: _isProcessing 
                            ? const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.black,
                                size: 32,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}