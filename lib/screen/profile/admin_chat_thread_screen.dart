import 'package:cnattendance/model/admin_chat_message.dart';
import 'package:cnattendance/provider/admin_chat_controller.dart';
import 'package:cnattendance/widget/chat/admin_chat_composer_widget.dart';
import 'package:cnattendance/widget/chat/chat_file_bubble.dart';
import 'package:cnattendance/widget/chat/chat_image_bubble.dart';
import 'package:cnattendance/widget/chat/chat_location_bubble.dart';
import 'package:cnattendance/widget/chat/chat_voice_bubble.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AdminChatThreadScreen extends StatelessWidget {
  const AdminChatThreadScreen({super.key});

  static const Color _pageBackground = AppColors.customFF06142F;
  static const Color _headerBackground = AppColors.customFF06142F;
  static const Color _sentBubble = AppColors.customFF1689F9;
  static const Color _receivedBubble = AppColors.customFF13264D;

  bool _hasValidNetworkImage(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Widget _buildAvatar(String imageUrl, {double size = 36}) {
    if (!_hasValidNetworkImage(imageUrl)) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.customFF1A2B52,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.admin_panel_settings_rounded,
            size: size * .55, color: AppColors.white70),
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.customFF1A2B52,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.admin_panel_settings_rounded,
              size: size * .55, color: AppColors.white70),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(AdminChatController model) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _headerBackground,
      foregroundColor: AppColors.white,
      titleSpacing: 2,
      leadingWidth: 46,
      title: Obx(
        () => Row(
          children: [
            _buildAvatar(model.adminAvatar.value, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    model.adminName.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Admin support',
                    style: TextStyle(
                      color: AppColors.white70,
                      fontSize: 13,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime dateTime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.customFF102246,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            DateFormat("MMM d 'AT' h:mm a").format(dateTime).toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(AdminChatMessage message, bool isIncoming) {
    if (message.type == 'image' && message.mediaUrl.trim().isNotEmpty) {
      return ChatImageBubble(
        imageUrl: message.mediaUrl,
        width: message.mediaWidth,
        height: message.mediaHeight,
      );
    }

    if (message.type == 'voice' && message.mediaUrl.trim().isNotEmpty) {
      return ChatVoiceBubble(
        mediaUrl: message.mediaUrl,
        mediaPath: message.mediaPath,
        isIncoming: isIncoming,
        durationSeconds: message.durationSeconds,
      );
    }

    if (message.type == 'location' &&
        message.latitude != null &&
        message.longitude != null) {
      return ChatLocationBubble(
        latitude: message.latitude!,
        longitude: message.longitude!,
        isIncoming: isIncoming,
      );
    }

    if (message.type == 'file' && message.mediaUrl.trim().isNotEmpty) {
      return ChatFileBubble(
        fileUrl: message.mediaUrl,
        fileName: message.fileName,
        isIncoming: isIncoming,
      );
    }

    return Text(
      message.message,
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 16,
        height: 1.28,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, AdminChatMessage message) {
    final isIncoming = message.isFromAdmin;
    final isImage =
        message.type == 'image' && message.mediaUrl.trim().isNotEmpty;
    final isRichBubble =
        isImage || message.type == 'voice' || message.type == 'location';
    final bubbleColor = isIncoming ? _receivedBubble : _sentBubble;

    return Align(
      alignment: isIncoming ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .72,
        ),
        child: Container(
          padding: isImage
              ? EdgeInsets.zero
              : EdgeInsets.symmetric(
                  horizontal: isRichBubble ? 10 : 14,
                  vertical: isRichBubble ? 10 : 10,
                ),
          decoration: BoxDecoration(
            color: isImage ? Colors.transparent : bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isIncoming ? 6 : 18),
              bottomRight: Radius.circular(isIncoming ? 18 : 6),
            ),
          ),
          child: _buildMessageContent(message, isIncoming),
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    BuildContext context,
    AdminChatController model,
    int index,
  ) {
    final message = model.messages[index];
    final isIncoming = message.isFromAdmin;
    var showDate = index == 0;

    if (index > 0) {
      final previous = model.messages[index - 1].dateTime;
      final currentDate = DateTime(
        message.dateTime.year,
        message.dateTime.month,
        message.dateTime.day,
      );
      final previousDate = DateTime(
        previous.year,
        previous.month,
        previous.day,
      );
      showDate = !currentDate.isAtSameMomentAs(previousDate);
    }

    return Column(
      children: [
        if (showDate) _buildDateSeparator(message.dateTime),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                isIncoming ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              if (isIncoming) ...[
                _buildAvatar(model.adminAvatar.value, size: 28),
                const SizedBox(width: 6),
              ],
              Flexible(child: _buildMessageBubble(context, message)),
              if (isIncoming) const SizedBox(width: 34),
              if (!isIncoming) const SizedBox(width: 42),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = Get.put(
      AdminChatController(),
      tag: _controllerTag(),
    );
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: _buildHeader(model),
      body: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.customFF06142F,
                    AppColors.customFF071B3B,
                    AppColors.customFF051026,
                  ],
                ),
              ),
              child: Obx(() {
                if (model.isLoading.value && model.messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.white),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.white,
                  backgroundColor: AppColors.blueGrey,
                  onRefresh: model.loadMessages,
                  child: ListView.builder(
                    controller: model.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 10, bottom: 12),
                    itemCount: model.messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageRow(context, model, index),
                  ),
                );
              }),
            ),
          ),
          AdminChatComposerWidget(model: model),
        ],
      ),
    );
  }

  String _controllerTag() {
    final arguments = Get.arguments is Map ? Get.arguments as Map : {};
    final adminId = arguments['adminId']?.toString().trim() ?? '';
    final conversationId = arguments['conversationId']?.toString().trim() ?? '';
    if (conversationId.startsWith('employee_admin_')) {
      return conversationId;
    }
    if (adminId.isNotEmpty && conversationId.isNotEmpty) {
      return 'admin:$adminId:$conversationId';
    }
    if (adminId.isNotEmpty) {
      return 'admin:$adminId';
    }

    final username =
        arguments['adminUsername']?.toString().trim().isNotEmpty == true
            ? arguments['adminUsername']!.toString().trim()
            : arguments['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) {
      return 'admin:$username';
    }

    return 'admin:${arguments['name']?.toString().trim() ?? 'default'}';
  }
}
