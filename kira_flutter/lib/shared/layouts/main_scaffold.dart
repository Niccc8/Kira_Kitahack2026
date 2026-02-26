/// Main Scaffold Layout
/// 
/// Wrapper layout with gradient background, bottom nav, and AI chat.
library;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/floating_ai_button.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/report_export_notifier.dart';
import '../../features/chat/presentation/kira_ai_chat.dart';
import '../../data/services/genkit_service.dart';

/// Main scaffold wrapper for all screens
class MainScaffold extends StatefulWidget {
  final Widget child;
  final bool showBottomNav;
  final bool showAiButton;
  final bool showProfileAvatar;

  const MainScaffold({
    super.key,
    required this.child,
    this.showBottomNav = true,
    this.showAiButton = true,
    this.showProfileAvatar = true,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _isAiChatOpen = false;

  void _openAiChat() {
    setState(() => _isAiChatOpen = true);
  }

  void _closeAiChat() {
    setState(() => _isAiChatOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              KiraColors.gradientTop,
              KiraColors.gradientMid,
              KiraColors.gradientBottom,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Main content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: widget.child,
                ),
              ),
              
              // Profile avatar
              if (widget.showProfileAvatar)
                const ProfileAvatar(),
              
              // Export report button (slides in beside AI button on Reports page)
              if (widget.showAiButton)
                const _AnimatedExportButton(),

              // Floating AI button
              if (widget.showAiButton)
                FloatingAiButton(onPressed: _openAiChat),
              
              // AI Chat overlay
              if (_isAiChatOpen)
                KiraAIChat(
                  userId: FirebaseAuth.instance.currentUser?.uid ?? 'user123', // Fallback for demo
                  onClose: _closeAiChat,
                  onSendMessage: (message, receiptId) {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user123';
                    return GenkitService().sendChatMessage(
                      userId: uid,
                      message: message,
                      receiptId: receiptId,
                    );
                  },
                  onProcessImage: (imageBytes) async {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'user123';
                    // Step 1: OCR — process the image via Genkit
                    final receipt = await GenkitService().processReceiptHttp(imageBytes, uid);
                    
                    // Step 2: Chat — ask Kira about the newly processed receipt
                    final reply = await GenkitService().sendChatMessage(
                      userId: uid,
                      message: 'I just scanned a receipt. Please analyze it and suggest ways to reduce its carbon footprint.',
                      receiptId: receipt.id,
                    );
                    return reply;
                  },
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav 
          ? const KiraBottomNav() 
          : null,
      extendBody: true,
    );
  }
}

/// Animated export button that appears beside the AI chatbot button
/// only when the Reports screen is active.
class _AnimatedExportButton extends StatefulWidget {
  const _AnimatedExportButton();

  @override
  State<_AnimatedExportButton> createState() => _AnimatedExportButtonState();
}

class _AnimatedExportButtonState extends State<_AnimatedExportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Listen to notifier changes
    reportExportNotifier.addListener(_onNotifierChanged);
    reportExportingNotifier.addListener(_onExportingChanged);

    // Set initial state
    if (reportExportNotifier.value != null) {
      _controller.value = 1.0;
    }
  }

  void _onNotifierChanged() {
    if (reportExportNotifier.value != null) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _onExportingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    reportExportNotifier.removeListener(_onNotifierChanged);
    reportExportingNotifier.removeListener(_onExportingChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 90, // Same vertical as AI button
      right: 20 + KiraSpacing.fabSize + 12, // Left of AI button with gap
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: GestureDetector(
              onTap: () {
                final callback = reportExportNotifier.value;
                if (callback != null && !reportExportingNotifier.value) {
                  callback();
                }
              },
              child: Container(
                width: KiraSpacing.fabSize,
                height: KiraSpacing.fabSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      KiraColors.success.withValues(alpha: 0.9),
                      KiraColors.success,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: KiraColors.success.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: KiraColors.success.withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Center(
                  child: reportExportingNotifier.value
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.file_download_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
