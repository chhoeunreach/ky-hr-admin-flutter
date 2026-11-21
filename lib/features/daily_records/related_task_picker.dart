import 'package:flutter/material.dart';

import 'daily_records_api.dart';
import 'record_widgets.dart';
import 'work_labels.dart';

Future<RecordData?> pickRelatedTask(
        BuildContext context, DailyRecordsApi api) =>
    showModalBottomSheet<RecordData>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .7,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              RecordHeading(workText(context, 'Related task')),
              Expanded(
                child: RecordList(
                  load: (page) =>
                      api.get('tasks', {'page': '$page', 'tab': 'history'}),
                  empty: workText(context, 'No matching records.'),
                  itemBuilder: (context, item) => ListTile(
                    title: Text(item['title'].toString()),
                    subtitle:
                        Text(workText(context, recordLabel(item['status']))),
                    enabled: item['archived_at'] == null &&
                        item['superseded_at'] == null,
                    onTap: () => Navigator.pop(context, item),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
