import 'package:cnattendance/provider/admin_chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

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
        color: AppColors.customFF06142F,
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
              style: const TextStyle(color: AppColors.white, fontSize: 16),
              controller: model.chatController,
              cursorColor: AppColors.customFF0084FF,
              decoration: InputDecoration(
                hintText: translate('chat_screen.send_message'),
                hintStyle: const TextStyle(
                  color: AppColors.white54,
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
                fillColor: AppColors.customFF14264C,
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
            color: AppColors.dangerToken,
            backgroundColor: AppColors.customFF2D1830,
            onPressed:
                model.isSending.value ? null : model.cancelVoiceRecording,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.customFF14264C,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.customFF24406F),
              ),
              child: Row(
                children: [
                  Icon(
                    model.isRecording.value ? Icons.mic : Icons.check_circle,
                    color: AppColors.dangerToken,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(model.recordingSeconds.value),
                    style: const TextStyle(
                      color: AppColors.white,
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
                        color: AppColors.dangerToken,
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
    this.color = AppColors.customFF48A7FF,
    this.backgroundColor = AppColors.customFF102246,
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
          color: onPressed == null ? AppColors.customFF0C1C3A : backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: onPressed == null ? AppColors.white30 : color,
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
              ? AppColors.customFF234067
              : AppColors.customFF1684F8,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: AppColors.custom551684F8,
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
                    color: AppColors.white,
                  ),
                )
              : const Icon(Icons.send_rounded,
                  color: AppColors.white, size: 21),
        ),
      ),
    );
  }
}
