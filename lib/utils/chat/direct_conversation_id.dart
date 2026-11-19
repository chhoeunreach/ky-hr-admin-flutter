String directConversationId(String user1, String user2) {
  return user1.compareTo(user2) <= 0 ? '$user1$user2' : '$user2$user1';
}
