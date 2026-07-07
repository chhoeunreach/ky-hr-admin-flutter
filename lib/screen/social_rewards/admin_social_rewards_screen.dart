import 'package:cnattendance/model/social_reward.dart';
import 'package:cnattendance/provider/social_rewards_controller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminSocialRewardsScreen extends StatelessWidget {
  const AdminSocialRewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = Get.put(SocialRewardsController());

    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Text('Social Rewards'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: model.onCreateClicked,
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Obx(
          () => SafeArea(
            child: RefreshIndicator(
              onRefresh: model.getRewards,
              child: model.rewards.isEmpty && !model.isLoading.value
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.verified_outlined,
                            color: Colors.white70, size: 42),
                        SizedBox(height: 12),
                        Text(
                          'No social reward entries yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: model.rewards.length,
                      itemBuilder: (context, index) {
                        final item = model.rewards[index];
                        return _RewardTile(
                          reward: item,
                          onTap: () => model.onRewardClicked(item),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.reward,
    required this.onTap,
  });

  final SocialReward reward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        tileColor: Colors.white12,
        onTap: onTap,
        textColor: Colors.white,
        iconColor: Colors.white,
        title: Text(
          reward.displayEmployee,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${reward.logDate} - ${reward.rewardPoints} point',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        leading: Card(
          color: reward.isLocked ? Colors.green : Colors.orange,
          shape: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Icon(
              reward.isLocked ? Icons.lock : Icons.lock_open,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
