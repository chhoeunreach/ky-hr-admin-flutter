import 'package:cnattendance/model/chat.dart';
import 'package:cnattendance/provider/chatcontroller.dart';
import 'package:cnattendance/screen/profile/employeedetailscreen.dart';
import 'package:cnattendance/widget/chat/chat_composer_widget.dart';
import 'package:cnattendance/widget/chat/chat_file_bubble.dart';
import 'package:cnattendance/widget/chat/chat_image_bubble.dart';
import 'package:cnattendance/widget/chat/chat_location_bubble.dart';
import 'package:cnattendance/widget/chat/chat_voice_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  static const Color _pageBackground = Color(0xff06142f);
  static const Color _headerBackground = Color(0xff06142f);
  static const Color _sentBubble = Color(0xff1689f9);
  static const Color _receivedBubble = Color(0xff13264d);
  static const Color _accentPurple = Color(0xffa66bff);

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
          color: Color(0xff1a2b52),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person,
          size: size * .55,
          color: Colors.white70,
        ),
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
            color: Color(0xff1a2b52),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            size: size * .55,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildHeader(ChatController model) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _headerBackground,
      shadowColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleSpacing: 2,
      leadingWidth: 46,
      title: Obx(
        () => InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _openProfile(model),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildAvatar(model.hostImage, size: 38),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xff31c65b),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.host.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      translate('chat_screen.active_now'),
                      style: const TextStyle(
                        color: Colors.white70,
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
      ),
      actions: [
        _HeaderActionButton(
          icon: Icons.call_rounded,
          iconColor: _accentPurple,
          onPressed: () {},
        ),
        _HeaderActionButton(
          icon: Icons.videocam_rounded,
          iconColor: _accentPurple,
          onPressed: () {},
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  void _openProfile(ChatController model) {
    final employeeId = model.hostEmployeeId.trim();
    if (employeeId.isEmpty) {
      Get.snackbar(
        "Profile",
        "Profile detail is not available for this chat.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    Get.to(EmployeeDetailScreen(), arguments: {"employeeId": employeeId});
  }

  Widget _buildDateSeparator(DateTime dateTime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xff102246),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            DateFormat("MMM d 'AT' h:mm a").format(dateTime).toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required BuildContext context,
    required Chat message,
    required bool isIncoming,
  }) {
    final type = message.type;
    final mediaUrl = message.mediaUrl;
    final isImage = type == "image" && mediaUrl.trim().isNotEmpty;
    final isRichBubble =
        isImage || type == "voice" || type == "location" || type == "file";
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
            boxShadow: isImage
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: _buildMessageContent(
            message: message,
            isIncoming: isIncoming,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent({
    required Chat message,
    required bool isIncoming,
  }) {
    final type = message.type;
    final mediaUrl = message.mediaUrl;
    if (type == "image" && mediaUrl.trim().isNotEmpty) {
      return ChatImageBubble(
        imageUrl: mediaUrl,
        width: message.mediaWidth,
        height: message.mediaHeight,
      );
    }

    if (type == "voice" && mediaUrl.trim().isNotEmpty) {
      return ChatVoiceBubble(
        mediaUrl: mediaUrl,
        mediaPath: message.mediaPath,
        isIncoming: isIncoming,
        durationSeconds: message.durationSeconds,
      );
    }

    if (type == "location" &&
        message.latitude != null &&
        message.longitude != null) {
      return ChatLocationBubble(
        latitude: message.latitude!,
        longitude: message.longitude!,
        isIncoming: isIncoming,
      );
    }

    if (type == "file" && mediaUrl.trim().isNotEmpty) {
      return ChatFileBubble(
        fileUrl: mediaUrl,
        fileName: "",
        isIncoming: isIncoming,
      );
    }

    return Text(
      message.message,
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        height: 1.28,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMessageRow(
      BuildContext context, ChatController model, int index) {
    final message = model.chatList[index];
    final isIncoming = message.sender == model.hostUsername;
    var showDate = index == 0;

    if (index > 0) {
      final previous = model.chatList[index - 1].dateTime;
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
                _buildAvatar(model.hostImage, size: 28),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: _buildMessageBubble(
                  context: context,
                  message: message,
                  isIncoming: isIncoming,
                ),
              ),
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
    final model = Get.put(ChatController());
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
                    Color(0xff06142f),
                    Color(0xff071b3b),
                    Color(0xff051026),
                  ],
                ),
              ),
              child: Obx(
                () => ListView.builder(
                  controller: model.scrollController,
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  itemCount: model.chatList.length,
                  itemBuilder: (context, index) =>
                      _buildMessageRow(context, model, index),
                ),
              ),
            ),
          ),
          ChatComposerWidget(model: model),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onPressed;

  const _HeaderActionButton({
    required this.icon,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xff20183e),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}
