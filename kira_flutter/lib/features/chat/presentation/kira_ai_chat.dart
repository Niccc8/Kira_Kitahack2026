/// Kira AI Chat - Bottom Sheet
/// 
/// Chat interface matching React KiraAI.jsx.
/// Supports image attachment: user picks image → stages it as preview →
/// user types optional message → sends image + message together.
library;

import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';

/// Initial welcome message from Kira
const _initialMessage = ChatMessage(
  role: ChatRole.assistant,
  content: '''Hi! I'm Kira, your carbon advisor.

I can help you:
• Reduce your carbon footprint
• Find GITA tax savings
• Understand your emissions

📎 You can also attach receipt/invoice photos for instant analysis!

What would you like to know?''',
);

/// Chat message role
enum ChatRole { user, assistant }

/// Chat message model
class ChatMessage {
  final ChatRole role;
  final String content;
  final Uint8List? imageBytes; // Optional image preview for user messages

  const ChatMessage({
    required this.role,
    required this.content,
    this.imageBytes,
  });
}

/// AI Chat bottom sheet widget
class KiraAIChat extends StatefulWidget {
  /// Callback to close the sheet
  final VoidCallback onClose;
  
  /// Optional: Custom send message handler for backend integration
  /// Returns the AI response as a Future<String>
  final Future<String> Function(String message)? onSendMessage;
  
  /// Optional: Process an attached image (OCR + chat with receipt context)
  /// Takes image bytes, returns the AI response string
  final Future<String> Function(Uint8List imageBytes)? onProcessImage;

  const KiraAIChat({
    super.key,
    required this.onClose,
    this.onSendMessage,
    this.onProcessImage,
  });

  @override
  State<KiraAIChat> createState() => _KiraAIChatState();
}

class _KiraAIChatState extends State<KiraAIChat> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [_initialMessage];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  // Staged image — picked but not yet sent
  Uint8List? _stagedImageBytes;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Send message (with optional staged image)
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    final hasImage = _stagedImageBytes != null;
    
    // Need either text or an image to send
    if (text.isEmpty && !hasImage) return;
    
    final imageToSend = _stagedImageBytes;
    final messageText = hasImage
        ? (text.isEmpty ? '📎 Attached a receipt for analysis' : text)
        : text;

    setState(() {
      _messages.add(ChatMessage(
        role: ChatRole.user,
        content: messageText,
        imageBytes: imageToSend,
      ));
      _controller.clear();
      _stagedImageBytes = null;
      _isLoading = true;
    });
    
    _scrollToBottom();
    
    String response;
    
    if (hasImage && widget.onProcessImage != null) {
      // Has an image → process via OCR pipeline
      try {
        response = await widget.onProcessImage!(imageToSend!);
      } catch (e) {
        response = 'Sorry, I couldn\'t process that image. Please try again with a clearer photo.';
        print('❌ Image processing error in chat: $e');
      }
    } else if (widget.onSendMessage != null) {
      // Text-only message → regular chat
      try {
        response = await widget.onSendMessage!(messageText);
      } catch (e) {
        response = 'Sorry, I encountered an error. Please try again.';
      }
    } else {
      // No backend → mock response
      await Future.delayed(const Duration(milliseconds: 800));
      response = hasImage ? _getMockImageResponse() : _getMockResponse();
    }
    
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.assistant, content: response));
      _isLoading = false;
    });
    
    _scrollToBottom();
  }

  /// Pick an image — stages it in the input area, does NOT auto-send
  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      
      setState(() {
        _stagedImageBytes = bytes;
      });
    } catch (e) {
      print('❌ Image picker error: $e');
    }
  }

  /// Remove the staged image
  void _removeStagedImage() {
    setState(() {
      _stagedImageBytes = null;
    });
  }

  String _getMockResponse() {
    return '''Based on your data, I recommend focusing on your Scope 2 emissions (electricity) - they make up 55% of your footprint.

**Quick wins:**
1. Switch to TNB Green plan (-80 tonnes/year)
2. LED retrofit for remaining lights (-3 tonnes)

This could reduce your carbon tax by RM 2,800. Want details on any of these?''';
  }

  String _getMockImageResponse() {
    return '''📋 **Receipt Analyzed!**

I've processed your receipt and found:
• **Vendor:** Sample Store Sdn Bhd
• **Total:** RM 450.00
• **CO₂ Impact:** ~12.5 kg

The receipt has been saved to your records. Would you like me to:
1. Find green alternatives to reduce emissions?
2. Check for GITA tax incentive eligibility?
3. Compare with your industry benchmarks?''';
  }
  
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {}, // Prevent close on sheet tap
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    decoration: BoxDecoration(
                      color: KiraColors.bgCardSolid,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      border: Border.all(color: KiraColors.glassBorder),
                    ),
                    child: Column(
                      children: [
                        // Handle
                        _buildHandle(),
                        
                        // Header
                        _buildHeader(),
                        
                        // Messages
                        Expanded(child: _buildMessages()),
                        
                        // Input (with staged image preview)
                        _buildInput(),
                        
                        // Safe area padding
                        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 20, color: KiraColors.success),
              const SizedBox(width: 8),
              Text('Kira AI', style: KiraTypography.h3),
            ],
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: KiraColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.smart_toy_outlined, size: 14, color: KiraColors.success),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser 
                    ? KiraColors.primary600 
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image preview (if user attached an image)
                  if (message.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        message.imageBytes!,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Text content
                  Text(
                    message.content,
                    style: KiraTypography.bodySmall.copyWith(
                      color: KiraColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person_outline, size: 14, color: KiraColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: KiraColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.smart_toy_outlined, size: 14, color: KiraColors.success),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _TypingDot(delay: i * 150),
              )),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Staged image preview (if picked) ──
          if (_stagedImageBytes != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KiraColors.glassBorder),
              ),
              child: Row(
                children: [
                  // Image thumbnail
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                    child: Image.memory(
                      _stagedImageBytes!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Label
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt attached',
                          style: KiraTypography.bodySmall.copyWith(
                            color: KiraColors.primary400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Type a message or send directly',
                          style: TextStyle(
                            color: KiraColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Remove button
                  GestureDetector(
                    onTap: _removeStagedImage,
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: KiraColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // ── Input row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 📎 Image attachment button
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: _stagedImageBytes != null
                        ? KiraColors.primary600.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _stagedImageBytes != null
                          ? KiraColors.primary400.withValues(alpha: 0.4)
                          : KiraColors.glassBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: _isLoading 
                        ? KiraColors.textTertiary 
                        : (_stagedImageBytes != null 
                            ? KiraColors.primary400 
                            : KiraColors.primary400),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Text input — multiline, wraps long text
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KiraColors.glassBorder),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: KiraTypography.bodyMedium,
                    maxLines: null, // Allows multiline wrapping
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: _stagedImageBytes != null
                          ? 'Add a message (optional)...'
                          : 'Ask Kira anything...',
                      hintStyle: KiraTypography.bodySmall.copyWith(
                        color: KiraColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Send button
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [KiraColors.primary500, KiraColors.primary600],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.send, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated typing dot
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: KiraColors.textSecondary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

/// Helper function to show AI chat
void showKiraAIChat(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (context) => KiraAIChat(
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}
