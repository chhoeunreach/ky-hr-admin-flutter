import 'package:flutter_translate/flutter_translate.dart';

String attendanceVerifyFailureMessage(String rawMessage) {
  final prompt = translate('attendance_messages.verify_please_check');
  final message = rawMessage.trim();
  if (message.isEmpty || message.toLowerCase() == 'null') {
    return prompt;
  }
  if (message.contains(prompt)) {
    return message;
  }
  return '$message\n\n$prompt';
}
