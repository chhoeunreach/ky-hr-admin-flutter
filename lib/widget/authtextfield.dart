import 'package:flutter/material.dart';
import 'package:cnattendance/core/theme/app_colors.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController _controller;

  AuthTextField(this._controller);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      cursorColor: AppColors.white,
      decoration: InputDecoration(
        labelStyle: TextStyle(color: AppColors.white),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: AppColors.white, width: 2)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.white, width: 2.0),
            borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
