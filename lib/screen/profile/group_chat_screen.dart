import 'package:cnattendance/model/group_chat_message.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/screen/profile/group_info_screen.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GroupChatScreen extends StatefulWidget {
  final int groupId;
  final String groupName;

  const GroupChatScreen({
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late GroupChatController _controller;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      GroupChatController(),
      tag: 'group_chat_${widget.groupId}',
    );
    _controller.currentGroupId.value = widget.groupId;
    _controller.currentGroupName.value = widget.groupName;
    _controller.loadMessages(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Text(
                _controller.currentGroupName.value,
                style: TextStyle(color: Colors.white, fontSize: 16),
              )),
              Obx(() {
                final group = _controller.currentGroup.value;
                if (group != null) {
                  return Text(
                    '${group.memberCount} members',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  );
                }
                return SizedBox.shrink();
              }),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => Get.to(() => GroupInfoScreen(groupId: widget.groupId)),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Obx(() {
                  if (_controller.isLoading.value && _controller.chatMessages.isEmpty) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (_controller.chatMessages.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _controller.scrollController,
                    itemCount: _controller.chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _controller.chatMessages[index];
                      final isMe = message.senderId.toString() == _controller.sender ||
                          message.senderName == _controller.sender;

                      bool showDate = true;
                      if (index > 0) {
                        final prev = _controller.chatMessages[index - 1];
                        showDate = _isDifferentDay(prev.createdAt, message.createdAt);
                      }

                      return Column(
                        children: [
                          if (showDate && message.createdAt != null)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _formatDate(message.createdAt!),
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          _MessageBubble(
                            message: message,
                            isMe: isMe,
                          ),
                        ],
                      );
                    },
                  );
                }),
              ),
              _ChatInputBar(
                controller: _controller,
                groupId: widget.groupId,
                picker: _picker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDifferentDay(String? a, String? b) {
    if (a == null || b == null) return true;
    try {
      final da = DateTime.parse(a);
      final db = DateTime.parse(b);
      return da.day != db.day || da.month != db.month || da.year != db.year;
    } catch (_) {
      return true;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final GroupChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                  color: Colors.amber[200],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isMe) Spacer(),
              Container(
                constraints: BoxConstraints(maxWidth: 280),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? Color(0xFF1A3A6B) : Colors.white12,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isText && message.message != null)
                      Text(
                        message.message!,
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    if (message.isImage && message.mediaUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          message.mediaUrl!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.broken_image, color: Colors.white54),
                        ),
                      ),
                    if (message.isVoice)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic, color: Colors.white54, size: 20),
                          SizedBox(width: 8),
                          Text('Voice message',
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    if (message.isFile)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file, color: Colors.white54, size: 20),
                          SizedBox(width: 8),
                          Text(
                            message.fileName ?? 'File',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    if (message.isLocation)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, color: Colors.white54, size: 20),
                          SizedBox(width: 8),
                          Text('Location', style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    SizedBox(height: 4),
                    if (message.createdAt != null)
                      Text(
                        _formatTime(message.createdAt!),
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}

class _ChatInputBar extends StatelessWidget {
  final GroupChatController controller;
  final int groupId;
  final ImagePicker picker;

  const _ChatInputBar({
    required this.controller,
    required this.groupId,
    required this.picker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickImage(context),
            child: Icon(Icons.image, color: Colors.white54, size: 24),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller.chatController,
              style: TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: translate('group_chat_screen.send_message'),
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              cursorColor: Colors.white,
              onSubmitted: (value) {
                controller.sendTextMessage(groupId, value);
              },
            ),
          ),
          Obx(() => controller.isSending.value
              ? Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () {
                    final text = controller.chatController.text;
                    if (text.isNotEmpty) {
                      controller.sendTextMessage(groupId, text);
                    }
                  },
                  child: Icon(Icons.send, color: Colors.white),
                )),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      controller.sendImageMessage(groupId, picked.path);
    }
  }
}
