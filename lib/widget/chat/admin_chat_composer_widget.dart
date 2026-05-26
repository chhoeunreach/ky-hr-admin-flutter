import 'package:cnattendance/provider/admin_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class AdminChatComposerWidget extends StatelessWidget {
  final AdminChatController model;

  const AdminChatComposerWidget({
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        color: const Color(0xff06142f),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: SafeArea(
          top: false,
          child: model.isRecording.value || model.hasPendingVoiceRecording.value
              ? _RecordingControls(model: model)
              : _MessageControls(model: model),
        ),
      ),
    );
  }
}

class _MessageControls extends StatelessWidget {
  final AdminChatController model;

  const _MessageControls({required this.model});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          _ComposerIconButton(
            icon: Icons.attach_file_rounded,
            onPressed: model.isSending.value ? null : model.pickAndSendFile,
          ),
          const SizedBox(width: 6),
          _ComposerIconButton(
            icon: Icons.photo_camera_rounded,
            onPressed: model.isSending.value ? null : model.pickAndSendPhoto,
          ),
          const SizedBox(width: 6),
          _ComposerIconButton(
            icon: Icons.mic_rounded,
            onPressed: model.isSending.value ? null : model.startVoiceRecording,
          ),
          const SizedBox(width: 6),
          _ComposerIconButton(
            icon: Icons.location_on_rounded,
            onPressed: model.isSending.value ? null : model.sendCurrentLocation,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              autofocus: false,
              maxLines: 4,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              controller: model.chatController,
              cursorColor: const Color(0xff0084ff),
              decoration: InputDecoration(
                hintText: translate('chat_screen.send_message'),
                hintStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: const Color(0xff14264c),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            isLoading: model.isSending.value,
            onPressed: model.isSending.value
                ? null
                : () {
                    if (model.chatController.text.trim().isNotEmpty) {
                      model.sendMessage(model.chatController.text.trim());
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _RecordingControls extends StatelessWidget {
  final AdminChatController model;

  const _RecordingControls({required this.model});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          _ComposerIconButton(
            icon: Icons.close_rounded,
            color: const Color(0xffef4444),
            backgroundColor: const Color(0xff2d1830),
            onPressed:
                model.isSending.value ? null : model.cancelVoiceRecording,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xff14264c),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xff24406f)),
              ),
              child: Row(
                children: [
                  Icon(
                    model.isRecording.value ? Icons.mic : Icons.check_circle,
                    color: const Color(0xffef4444),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(model.recordingSeconds.value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (model.isRecording.value)
                    IconButton(
                      constraints:
                          const BoxConstraints.tightFor(width: 34, height: 34),
                      padding: EdgeInsets.zero,
                      onPressed: model.isSending.value
                          ? null
                          : model.stopVoiceRecording,
                      icon: const Icon(
                        Icons.stop_circle,
                        color: Color(0xffef4444),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            isLoading: model.isSending.value,
            onPressed: model.isSending.value ? null : model.sendVoiceRecording,
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color backgroundColor;

  const _ComposerIconButton({
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xff48a7ff),
    this.backgroundColor = const Color(0xff102246),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onPressed == null ? const Color(0xff0c1c3a) : backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onPressed == null ? Colors.white30 : color,
          size: 22,
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _SendButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(21),
      onTap: onPressed,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: onPressed == null && !isLoading
              ? const Color(0xff234067)
              : const Color(0xff1684f8),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x551684f8),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}
