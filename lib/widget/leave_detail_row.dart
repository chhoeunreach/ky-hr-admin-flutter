import 'package:cnattendance/widget/cancel_leave_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class LeaveDetailRow extends StatelessWidget {
  final int id;
  final String leaveTypeId;
  final String name;
  final String from;
  final String to;
  final String status;
  final String authorization;
  final String requestedAt;

  LeaveDetailRow(
      {required this.id,
      required this.leaveTypeId,
      required this.name,
      required this.from,
      required this.to,
      required this.status,
      required this.authorization,
      required this.requestedAt});

  @override
  Widget build(BuildContext context) {


    void onLeaveCancelledClicked(int id){

        showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            builder: (context) {
              return CancelLeaveBottomSheet(id,leaveTypeId);
            });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.white12,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                textBaseline: TextBaseline.alphabetic,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      "$from - $to",
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  Text(
                    authorization == '' ? "N/A" : "By: $authorization",
                    style: TextStyle(color: HexColor("#036eb7"), fontSize: 11),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      requestedAt,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (status.toLowerCase() == "pending") {
                        onLeaveCancelledClicked(id);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        color: getStatus(),
                        child: Text(
                          status,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Color getStatus() {
    switch (status) {
      case "Approved":
        return Colors.green;
      case "Rejected":
        return Colors.redAccent;
      case "Pending":
        return Colors.orange;
      case "Cancelled":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
