import 'dart:io';

import 'package:cnattendance/model/group_chat_message.dart';
import 'package:cnattendance/provider/groupchatcontroller.dart';
import 'package:cnattendance/screen/profile/group_info_screen.dart';
import 'package:cnattendance/widget/chat/chat_file_bubble.dart';
import 'package:cnattendance/widget/chat/chat_image_bubble.dart';
import 'package:cnattendance/widget/chat/chat_location_bubble.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
  bool _showAttachments = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      GroupChatController(),
      tag: 'group_chat_${widget.groupId}',
    );
    _controller.currentGroupId.value = widget.groupId;
    _controller.currentGroupName.value = widget.groupName;
    _controller.loadCurrentUser();
    _controller.loadMessages(widget.groupId);
    _controller.scrollController.addListener(_controller.onScroll);
  }

  @override
  void dispose() {
    _controller.scrollController.removeListener(_controller.onScroll);
    super.dispose();
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
          title: Obx(() {
            final group = _controller.currentGroup.value;
            return GestureDetector(
              onTap: () => Get.to(() => GroupInfoScreen(groupId: widget.groupId)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white12,
                    backgroundImage: group?.avatar != null ? NetworkImage(group!.avatar!) : null,
                    child: group?.avatar == null
                        ? const Icon(Icons.group, size: 18, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group?.name ?? _controller.currentGroupName.value,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (group != null)
                        Text(
                          '${group.memberCount} members',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          actions: [
            IconButton(
              icon: const Icon(Icons.wallpaper_rounded, color: Colors.white),
              onPressed: _showBackgroundOptions,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
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
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (_controller.chatMessages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white24, size: 56),
                          const SizedBox(height: 12),
                          const Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.white38, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Say hello to the group!',
                            style: TextStyle(color: Colors.white24, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Obx(() => DecoratedBox(
                        decoration: _groupBackgroundDecoration(_controller.backgroundPath.value),
                        child: ListView.builder(
                          controller: _controller.scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          itemCount: _controller.chatMessages.length,
                          itemBuilder: (context, index) {
                          final message = _controller.chatMessages[index];
                          final isMe = message.senderId == _controller.currentUserId.value;

                          final prev = index > 0 ? _controller.chatMessages[index - 1] : null;
                          final next = index < _controller.chatMessages.length - 1
                              ? _controller.chatMessages[index + 1]
                              : null;

                          final showDate = _isDifferentDay(prev?.createdAt, message.createdAt);
                          final showSender = !isMe && (prev == null || prev.senderId != message.senderId || _isDifferentDay(prev.createdAt, message.createdAt));
                          final isGroupStart = showSender || showDate;
                          final isGroupEnd = next == null || next.senderId != message.senderId || _isDifferentDay(message.createdAt, next.createdAt);

                          return Column(
                            children: [
                              if (showDate && message.createdAt != null)
                                _DateSeparator(date: message.createdAt!),
                              _MessageBubble(
                                message: message,
                                isMe: isMe,
                                showSender: showSender,
                                isGroupStart: isGroupStart,
                                isGroupEnd: isGroupEnd,
                                onTap: () => _handleMessageTap(message),
                                onLongPress: () => _handleMessageLongPress(message),
                              ),
                            ],
                          );
                        },
                        ),
                      )),
                      Obx(() {
                        if (!_controller.isAtBottom.value) {
                          return Positioned(
                            bottom: 8,
                            right: 16,
                            child: FloatingActionButton.small(
                              backgroundColor: const Color(0xFF036eb7),
                              onPressed: _controller.scrollToBottom,
                              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  );
                }),
              ),
              _ChatInputBar(
                controller: _controller,
                groupId: widget.groupId,
                picker: _picker,
                showAttachments: _showAttachments,
                onToggleAttachments: () => setState(() => _showAttachments = !_showAttachments),
                onPickImage: _pickImage,
                onPickFile: _pickFile,
                onPickLocation: _pickLocation,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMessageTap(GroupChatMessage message) {
    if (message.isImage && message.mediaUrl != null) {
      _showImagePreview(message.mediaUrl!, message.mediaWidth, message.mediaHeight);
    }
  }

  void _handleMessageLongPress(GroupChatMessage message) {
    if (!_controller.canModifyMessage(message)) {
      return;
    }
    Get.bottomSheet(
      _GroupActionSheet(
        children: [
          if (message.isText && !message.isDeleted)
            _GroupActionTile(
              icon: Icons.edit_rounded,
              label: 'Edit message',
              onTap: () {
                Get.back();
                _showEditMessageDialog(message);
              },
            ),
          _GroupActionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete message',
            isDestructive: true,
            onTap: () {
              Get.back();
              _controller.deleteMessage(widget.groupId, message);
            },
          ),
        ],
      ),
    );
  }

  void _showEditMessageDialog(GroupChatMessage message) {
    final editController = TextEditingController(text: message.message ?? '');
    Get.dialog(
      AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final text = editController.text.trim();
              Get.back();
              _controller.editMessage(widget.groupId, message, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBackgroundOptions() {
    Get.bottomSheet(
      _GroupActionSheet(
        children: [
          _GroupActionTile(
            icon: Icons.photo_library_rounded,
            label: 'Change background photo',
            onTap: () async {
              Get.back();
              final picked = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 88,
              );
              if (picked != null) {
                await _controller.setBackground(widget.groupId, picked.path);
              }
            },
          ),
          _GroupActionTile(
            icon: Icons.restart_alt_rounded,
            label: 'Reset to original background',
            onTap: () {
              Get.back();
              _controller.resetBackground(widget.groupId);
            },
          ),
        ],
      ),
    );
  }

  void _showImagePreview(String url, int? width, int? height) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(url, fit: BoxFit.contain, width: double.infinity, height: double.infinity,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Get.back(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _showAttachments = false);
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _controller.sendImageMessage(widget.groupId, picked.path);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _showAttachments = false);
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      _controller.sendFileMessage(
        widget.groupId,
        result.files.single.path!,
        fileName: result.files.single.name,
      );
    }
  }

  void _pickLocation() {
    setState(() => _showAttachments = false);
    _showLocationPicker();
  }

  void _showLocationPicker() {
    final latController = TextEditingController();
    final lngController = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF0A1E3D),
        title: const Text('Send Location', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Latitude',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
              cursorColor: Colors.white,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lngController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Longitude',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
              ),
              cursorColor: Colors.white,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final lat = double.tryParse(latController.text);
              final lng = double.tryParse(lngController.text);
              if (lat != null && lng != null) {
                Get.back();
                _controller.sendLocationMessage(widget.groupId, lat, lng);
              } else {
                showToast('Invalid coordinates');
              }
            },
            child: const Text('Send', style: TextStyle(color: Colors.amber)),
          ),
        ],
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
}

class _DateSeparator extends StatelessWidget {
  final String date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    String label;
    try {
      final dt = DateTime.parse(date);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        label = 'Today';
      } else {
        final yesterday = now.subtract(const Duration(days: 1));
        if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
          label = 'Yesterday';
        } else {
          label = DateFormat('MMMM dd, yyyy').format(dt);
        }
      }
    } catch (_) {
      label = date;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final GroupChatMessage message;
  final bool isMe;
  final bool showSender;
  final bool isGroupStart;
  final bool isGroupEnd;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.isGroupStart = true,
    this.isGroupEnd = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : (isGroupEnd ? 4 : 18)),
      bottomRight: Radius.circular(isMe ? (isGroupEnd ? 4 : 18) : 18),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        top: isGroupStart ? 4 : 1,
        bottom: isGroupEnd ? 6 : 1,
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 44, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                  color: _senderColor(message.senderName),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe && isGroupEnd)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white12,
                    backgroundImage: message.senderAvatar != null ? NetworkImage(message.senderAvatar!) : null,
                    child: message.senderAvatar == null
                        ? const Icon(Icons.person, size: 14, color: Colors.white38)
                        : null,
                  ),
                )
              else if (!isMe)
                const SizedBox(width: 34),
              Flexible(
                child: GestureDetector(
                  onTap: onTap,
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: isMe ? MediaQuery.of(context).size.width * 0.75 : MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: EdgeInsets.all(message.isImage ? 4 : 12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF1A3A6B) : Colors.white.withOpacity(0.08),
                      borderRadius: borderRadius,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isDeleted)
                          const Text(
                            'Message deleted',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (!message.isDeleted && message.isText && message.message != null)
                          Text(
                            message.message!,
                            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                          ),
                        if (!message.isDeleted && message.isImage && message.mediaUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ChatImageBubble(
                              imageUrl: message.mediaUrl!,
                              width: message.mediaWidth,
                              height: message.mediaHeight,
                            ),
                          ),
                        if (!message.isDeleted && message.isFile)
                          ChatFileBubble(
                            fileUrl: message.mediaUrl ?? '',
                            fileName: message.fileName ?? '',
                            isIncoming: !isMe,
                          ),
                        if (!message.isDeleted && message.isVoice)
                          _VoiceBubble(mediaUrl: message.mediaUrl, durationSeconds: message.durationSeconds),
                        if (!message.isDeleted && message.isLocation)
                          ChatLocationBubble(
                            latitude: message.latitude ?? 0,
                            longitude: message.longitude ?? 0,
                            isIncoming: !isMe,
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message.createdAt != null)
                              Text(
                                _formatTime(message.createdAt!),
                                style: TextStyle(
                                  color: isMe ? Colors.white38 : Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.check, size: 14, color: Colors.white38),
                            ],
                            if (message.isEdited && !message.isDeleted) ...[
                              const SizedBox(width: 5),
                              const Text('Edited', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!isMe && !isGroupEnd)
                const SizedBox(width: 34),
            ],
          ),
        ],
      ),
    );
  }

  Color _senderColor(String name) {
    final hash = name.hashCode;
    final colors = [
      Colors.amber[200],
      Colors.green[200],
      Colors.purple[200],
      Colors.orange[200],
      Colors.teal[200],
      Colors.pink[200],
      Colors.cyan[200],
    ];
    return colors[hash.abs() % colors.length]!;
  }

  String _formatTime(String iso) {
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(iso));
    } catch (_) {
      return '';
    }
  }
}

class _VoiceBubble extends StatelessWidget {
  final String? mediaUrl;
  final int? durationSeconds;

  const _VoiceBubble({this.mediaUrl, this.durationSeconds});

  @override
  Widget build(BuildContext context) {
    final duration = durationSeconds != null ? '${durationSeconds! ~/ 60}:${(durationSeconds! % 60).toString().padLeft(2, '0')}' : '0:00';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_filled, color: Colors.amber[200], size: 28),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voice message', style: TextStyle(color: Colors.white, fontSize: 14)),
            Text(duration, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

BoxDecoration _groupBackgroundDecoration(String path) {
  if (path.trim().isNotEmpty && File(path).existsSync()) {
    return BoxDecoration(
      image: DecorationImage(
        image: FileImage(File(path)),
        fit: BoxFit.cover,
        colorFilter: const ColorFilter.mode(
          Color(0xaa06142f),
          BlendMode.darken,
        ),
      ),
    );
  }
  return const BoxDecoration();
}

class _GroupActionSheet extends StatelessWidget {
  final List<Widget> children;

  const _GroupActionSheet({required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xff0d1f41),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _GroupActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _GroupActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xffff6b6b) : Colors.white;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  final GroupChatController controller;
  final int groupId;
  final ImagePicker picker;
  final bool showAttachments;
  final VoidCallback onToggleAttachments;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;
  final VoidCallback onPickLocation;

  const _ChatInputBar({
    required this.controller,
    required this.groupId,
    required this.picker,
    required this.showAttachments,
    required this.onToggleAttachments,
    required this.onPickImage,
    required this.onPickFile,
    required this.onPickLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAttachments)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentButton(icon: Icons.image, label: 'Photo', color: Colors.purple[300]!, onTap: onPickImage),
                _AttachmentButton(icon: Icons.insert_drive_file, label: 'File', color: Colors.blue[300]!, onTap: onPickFile),
                _AttachmentButton(icon: Icons.location_on, label: 'Location', color: Colors.green[300]!, onTap: onPickLocation),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onToggleAttachments,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: showAttachments ? const Color(0xFF036eb7) : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    showAttachments ? Icons.close : Icons.add,
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: controller.chatController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    cursorColor: Colors.white,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (value) => controller.sendTextMessage(groupId, value),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Obx(() => controller.isSending.value
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                    )
                  : GestureDetector(
                      onTap: () {
                        final text = controller.chatController.text;
                        if (text.isNotEmpty) {
                          controller.sendTextMessage(groupId, text);
                        }
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFF036eb7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
