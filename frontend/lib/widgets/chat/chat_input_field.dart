import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ChatInputField extends StatefulWidget {
  final void Function(String text) onSend;
  final VoidCallback onAttach;
  final bool enabled;

  const ChatInputField({super.key, required this.onSend, required this.onAttach, this.enabled = true});

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final _controller = TextEditingController();
  final _speech = stt.SpeechToText();
  bool _hasText = false;
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _speech
        .initialize(onStatus: _onSpeechStatus, onError: (_) => setState(() => _isListening = false))
        .then((available) {
      if (mounted) setState(() => _speechAvailable = available);
    });
  }

  /// Fires when the OS speech recognizer itself stops (e.g. it detected a
  /// pause and ended the session on its own, separate from our listen()
  /// call's pauseFor timer). Covers that path too so auto-send is reliable
  /// no matter which mechanism ends listening first.
  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (_isListening) _finishListening();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable || !widget.enabled) return;
    if (_isListening) {
      await _finishListening(); // user tapped the mic again to end early
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
        // The plugin marks the LAST callback for a listening session with
        // finalResult: true — that's our definitive "the user is done
        // talking" signal, more reliable than only listening for the
        // status event, so we auto-send right here.
        if (result.finalResult) _finishListening();
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3), // stops automatically after ~3s of silence
    );
  }

  /// Stops the mic (if still active) and, if we ended up with real text,
  /// sends it immediately — no manual tap needed. Safe to call more than
  /// once for the same utterance: _submit() is a no-op once the field is
  /// already empty, so a stray duplicate call (status event firing after
  /// finalResult already handled it) can't send the same message twice.
  Future<void> _finishListening() async {
    if (_speech.isListening) await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
    if (_hasText) _submit();
  }

  void _submit() {
    if (!_hasText || !widget.enabled) return;
    widget.onSend(_controller.text.trim());
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Listening… sends automatically when you stop talking', style: AppTextStyles.bodySm.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: widget.enabled ? widget.onAttach : null,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary),
                  tooltip: 'Attach a document',
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isListening ? AppColors.lavender100 : AppColors.lavender50,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _isListening ? AppColors.brand : AppColors.lavender100),
                    ),
                    child: TextField(
                      controller: _controller,
                      enabled: widget.enabled,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      style: AppTextStyles.bodyMd,
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Speak now…' : 'Ask about your documents…',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                if (_speechAvailable) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.enabled ? _toggleListening : null,
                    icon: Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded, color: _isListening ? AppColors.error : AppColors.textSecondary),
                    tooltip: _isListening ? 'Stop and send' : 'Ask with your voice',
                  ),
                ],
                const SizedBox(width: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(color: _hasText && widget.enabled ? AppColors.brand : AppColors.lavender50, shape: BoxShape.circle),
                  child: IconButton(
                    onPressed: _submit,
                    icon: Icon(Icons.arrow_upward_rounded, color: _hasText && widget.enabled ? Colors.white : AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
