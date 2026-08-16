import 'dart:io';

import 'package:cnattendance/model/social_reward.dart';
import 'package:cnattendance/repositories/social_rewards_repository.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class SocialSubmissionScreen extends StatefulWidget {
  final int employeeId;

  const SocialSubmissionScreen({
    Key? key,
    required this.employeeId,
  }) : super(key: key);

  @override
  State<SocialSubmissionScreen> createState() => _SocialSubmissionScreenState();
}

class _SocialSubmissionScreenState extends State<SocialSubmissionScreen> {
  final _fbPostController = TextEditingController();
  final _fbStoryController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _repository = SocialRewardsRepository();
  final _imagePicker = ImagePicker();

  File? _fbPostPhoto;
  File? _fbStoryPhoto;
  File? _tiktokPhoto;
  SocialReward? _todayReward;
  List<SocialReward> _posts = [];
  bool _isValidForm = false;
  bool _isLoading = true;
  bool _isEditingToday = false;

  bool get _hasSubmittedToday => _todayReward != null;
  int get _totalPoints =>
      _posts.fold(0, (total, reward) => total + reward.rewardPoints);

  @override
  void initState() {
    super.initState();
    _loadTracker();
  }

  void _validateInputs() {
    setState(() {
      final hasRequiredPhotos = _isEditingToday
          ? _hasPhoto(_fbPostPhoto, _todayReward?.fbPostPhotoUrl) &&
              _hasPhoto(_fbStoryPhoto, _todayReward?.fbStoryPhotoUrl) &&
              _hasPhoto(_tiktokPhoto, _todayReward?.tiktokPhotoUrl)
          : _fbPostPhoto != null &&
              _fbStoryPhoto != null &&
              _tiktokPhoto != null;

      _isValidForm = _hasStructuredUrlPrefix(_fbPostController.text) &&
          _hasStructuredUrlPrefix(_fbStoryController.text) &&
          _hasStructuredUrlPrefix(_tiktokController.text) &&
          hasRequiredPhotos;
    });
  }

  bool _hasStructuredUrlPrefix(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  bool _hasPhoto(File? file, String? existingUrl) {
    return file != null || (existingUrl?.trim().isNotEmpty ?? false);
  }

  Future<void> _loadTracker() async {
    try {
      final responses = await Future.wait([
        _repository.getEmployeeRewards(employeeId: widget.employeeId),
        _repository.getTodayReward(employeeId: widget.employeeId),
      ]);
      if (!mounted) {
        return;
      }
      final posts = (responses[0] as SocialRewardListResponse).data;
      final todayReward =
          responses[1] as SocialReward? ?? _findTodayPost(posts);
      setState(() {
        _posts = posts;
        _todayReward = todayReward;
        _isEditingToday = false;
        _clearForm();
      });
      _validateInputs();
    } catch (e) {
      showToast(e.toString());
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  SocialReward? _findTodayPost(List<SocialReward> posts) {
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    for (final post in posts) {
      if (post.logDate == today) {
        return post;
      }
    }
    return null;
  }

  Future<void> _pickPhoto(_SocialPhotoField field) async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) {
      return;
    }

    final compressedFile = await _compressPickedPhoto(File(picked.path));

    setState(() {
      switch (field) {
        case _SocialPhotoField.facebookPost:
          _fbPostPhoto = compressedFile;
          break;
        case _SocialPhotoField.facebookStory:
          _fbStoryPhoto = compressedFile;
          break;
        case _SocialPhotoField.tiktok:
          _tiktokPhoto = compressedFile;
          break;
      }
    });
    _validateInputs();
  }

  Future<File> _compressPickedPhoto(File originalFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/social_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: 72,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );
      if (compressed == null) {
        return originalFile;
      }
      return File(compressed.path);
    } catch (_) {
      return originalFile;
    }
  }

  Future<void> _executeSubmitAction() async {
    final todayReward = _todayReward;
    try {
      EasyLoading.show(
        status: translate('loader.loading'),
        maskType: EasyLoadingMaskType.black,
      );

      final response = _isEditingToday && todayReward != null
          ? await _repository.updateDayLog(
              rewardId: todayReward.id,
              employeeId: widget.employeeId,
              fbPostUrl: _fbPostController.text.trim(),
              fbStoryUrl: _fbStoryController.text.trim(),
              tiktokUrl: _tiktokController.text.trim(),
              fbPostPhoto: _fbPostPhoto,
              fbStoryPhoto: _fbStoryPhoto,
              tiktokPhoto: _tiktokPhoto,
            )
          : await _repository.submitDayLog(
              employeeId: widget.employeeId,
              fbPostUrl: _fbPostController.text.trim(),
              fbStoryUrl: _fbStoryController.text.trim(),
              tiktokUrl: _tiktokController.text.trim(),
              fbPostPhoto: _fbPostPhoto!,
              fbStoryPhoto: _fbStoryPhoto!,
              tiktokPhoto: _tiktokPhoto!,
            );

      EasyLoading.dismiss(animation: true);
      showToast(response.message);
      if (response.status) {
        await _loadTracker();
      }
    } catch (e) {
      EasyLoading.dismiss(animation: true);
      showToast(e.toString());
    }
  }

  void _startEditToday() {
    final reward = _todayReward;
    if (reward == null) {
      return;
    }
    setState(() {
      _isEditingToday = true;
      _fbPostController.text = reward.fbPostUrl;
      _fbStoryController.text = reward.fbStoryUrl;
      _tiktokController.text = reward.tiktokUrl;
      _fbPostPhoto = null;
      _fbStoryPhoto = null;
      _tiktokPhoto = null;
    });
    _validateInputs();
  }

  void _cancelEdit() {
    setState(() {
      _isEditingToday = false;
      _clearForm();
    });
    _validateInputs();
  }

  void _clearForm() {
    _fbPostController.clear();
    _fbStoryController.clear();
    _tiktokController.clear();
    _fbPostPhoto = null;
    _fbStoryPhoto = null;
    _tiktokPhoto = null;
    _isValidForm = false;
  }

  @override
  void dispose() {
    _fbPostController.dispose();
    _fbStoryController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff050615),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xff367cf6),
        title: const Text(
          'Daily Social Media Marketing Logs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTracker,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                children: [
                  _SocialPointsDashboard(
                    totalPoints: _totalPoints,
                    totalPosts: _posts.length,
                    hasSubmittedToday: _hasSubmittedToday,
                  ),
                  const SizedBox(height: 16),
                  if (!_hasSubmittedToday || _isEditingToday)
                    _buildEntryForm()
                  else
                    _TodayCompleteCard(
                      reward: _todayReward!,
                      onEdit: _startEditToday,
                    ),
                  const SizedBox(height: 18),
                  _buildPostList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialPostInput(
          controller: _fbPostController,
          label: 'Facebook Post Link',
          icon: Icons.facebook,
          selectedPhoto: _fbPostPhoto,
          existingPhotoUrl:
              _isEditingToday ? _todayReward?.fbPostPhotoUrl : null,
          onChanged: (_) => _validateInputs(),
          onPickPhoto: () => _pickPhoto(_SocialPhotoField.facebookPost),
        ),
        const SizedBox(height: 14),
        _SocialPostInput(
          controller: _fbStoryController,
          label: 'Facebook Story Link',
          icon: Icons.auto_stories_outlined,
          selectedPhoto: _fbStoryPhoto,
          existingPhotoUrl:
              _isEditingToday ? _todayReward?.fbStoryPhotoUrl : null,
          onChanged: (_) => _validateInputs(),
          onPickPhoto: () => _pickPhoto(_SocialPhotoField.facebookStory),
        ),
        const SizedBox(height: 14),
        _SocialPostInput(
          controller: _tiktokController,
          label: 'TikTok Link',
          icon: Icons.music_note,
          selectedPhoto: _tiktokPhoto,
          existingPhotoUrl:
              _isEditingToday ? _todayReward?.tiktokPhotoUrl : null,
          onChanged: (_) => _validateInputs(),
          onPickPhoto: () => _pickPhoto(_SocialPhotoField.tiktok),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isValidForm ? _executeSubmitAction : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: const Color(0xff367cf6),
            disabledBackgroundColor: const Color(0xff262839),
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(_isEditingToday ? 'UPDATE DAY LOG' : 'SUBMIT DAY LOG'),
        ),
        if (_isEditingToday)
          TextButton(
            onPressed: _cancelEdit,
            child: const Text('Cancel edit'),
          ),
      ],
    );
  }

  Widget _buildPostList() {
    if (_posts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No post logs yet',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Post Logs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ..._posts.map(
          (reward) => _SocialRewardListTile(
            reward: reward,
            isToday: reward.id == _todayReward?.id,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SocialRewardDetailScreen(
                    reward: reward,
                    canEdit: reward.id == _todayReward?.id,
                    onEdit: () {
                      Navigator.of(context).pop();
                      _startEditToday();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SocialRewardDetailScreen extends StatelessWidget {
  const SocialRewardDetailScreen({
    super.key,
    required this.reward,
    required this.canEdit,
    required this.onEdit,
  });

  final SocialReward reward;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff050615),
      appBar: AppBar(
        title: const Text('Post Detail'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit today',
              onPressed: onEdit,
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailHeader(reward: reward),
          const SizedBox(height: 14),
          _DetailSocialRow(
            title: 'Facebook Post',
            url: reward.fbPostUrl,
            photoUrl: reward.fbPostPhotoUrl,
          ),
          _DetailSocialRow(
            title: 'Facebook Story',
            url: reward.fbStoryUrl,
            photoUrl: reward.fbStoryPhotoUrl,
          ),
          _DetailSocialRow(
            title: 'TikTok',
            url: reward.tiktokUrl,
            photoUrl: reward.tiktokPhotoUrl,
          ),
        ],
      ),
    );
  }
}

enum _SocialPhotoField { facebookPost, facebookStory, tiktok }

class _SocialPointsDashboard extends StatelessWidget {
  const _SocialPointsDashboard({
    required this.totalPoints,
    required this.totalPosts,
    required this.hasSubmittedToday,
  });

  final int totalPoints;
  final int totalPosts;
  final bool hasSubmittedToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff246bfe),
            Color(0xff111936),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff246bfe).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.campaign, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Social Reward Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DashboardMetric(
                  label: 'Total Points',
                  value: totalPoints.toString(),
                ),
              ),
              Expanded(
                child: _DashboardMetric(
                  label: 'Post Days',
                  value: totalPosts.toString(),
                ),
              ),
              Expanded(
                child: _DashboardMetric(
                  label: 'Today',
                  value: hasSubmittedToday ? 'Done' : 'Open',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasSubmittedToday
                  ? 'Today is locked. You can edit today only.'
                  : 'Submit one daily bundle with all three links and photos.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SocialPostInput extends StatelessWidget {
  const _SocialPostInput({
    required this.controller,
    required this.label,
    required this.icon,
    required this.selectedPhoto,
    required this.existingPhotoUrl,
    required this.onChanged,
    required this.onPickPhoto,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final File? selectedPhoto;
  final String? existingPhotoUrl;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        selectedPhoto != null || (existingPhotoUrl?.trim().isNotEmpty ?? false);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff121423),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xff367cf6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: const Color(0xff73a3ff), size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                hasPhoto ? Icons.verified_rounded : Icons.image_outlined,
                color: hasPhoto ? Colors.greenAccent : Colors.white38,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: onPickPhoto,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff73a3ff),
                side: BorderSide(
                  color: const Color(0xff367cf6).withValues(alpha: 0.65),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(hasPhoto ? Icons.check_circle : Icons.upload_file),
              label: Text(hasPhoto ? 'Photo ready' : 'Upload photo'),
            ),
          ),
          if (selectedPhoto != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                selectedPhoto!,
                height: 92,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ] else if (existingPhotoUrl?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                existingPhotoUrl!,
                height: 92,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayCompleteCard extends StatelessWidget {
  const _TodayCompleteCard({
    required this.reward,
    required this.onEdit,
  });

  final SocialReward reward;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff102416),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_circle, color: Colors.greenAccent),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Today's tasks completed! Earned 1 Point (\$1)",
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: onEdit,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.10),
            ),
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _SocialRewardListTile extends StatelessWidget {
  const _SocialRewardListTile({
    required this.reward,
    required this.isToday,
    required this.onTap,
  });

  final SocialReward reward;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xff121423),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (isToday ? Colors.green : const Color(0xff367cf6))
                .withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '+${reward.rewardPoints}',
              style: TextStyle(
                color: isToday ? Colors.greenAccent : const Color(0xff73a3ff),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        title: Text(
          reward.logDate,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          isToday ? 'Today - tap to view or edit' : 'Tap to view detail',
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.reward});

  final SocialReward reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff1b2446), Color(0xff121423)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${reward.logDate} - ${reward.rewardPoints} point',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSocialRow extends StatelessWidget {
  const _DetailSocialRow({
    required this.title,
    required this.url,
    required this.photoUrl,
  });

  final String title;
  final String url;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xff121423),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              url,
              style: const TextStyle(color: Colors.white70),
            ),
            if (photoUrl.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  photoUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
