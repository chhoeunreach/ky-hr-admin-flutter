import 'package:flutter/material.dart';

import 'daily_records_api.dart';
import 'record_theme.dart';
import 'daily_summaries.dart';
import 'employee_records.dart';
import 'record_widgets.dart';
import 'work_labels.dart';
import 'work_record_editor.dart';

class WorkRecordsScreen extends StatefulWidget {
  const WorkRecordsScreen({super.key, required this.api});
  final DailyRecordsApi api;

  @override
  State<WorkRecordsScreen> createState() => _WorkRecordsScreenState();
}

class _WorkRecordsScreenState extends State<WorkRecordsScreen> {
  final _list = GlobalKey<RecordListState>();
  final _search = TextEditingController();
  String _view = '';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applySearch() {
    setState(() => _query = _search.text.trim());
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    const kinds = {
      '': 'All records',
      'activity': 'Daily Activity',
      'incident': 'Incident Report',
      'assigned': 'Assigned incidents',
      'todo': 'To-do / Task',
      'note': 'Personal Note',
      'archive': 'Archived notes',
    };
    return RecordScaffold(
      appBar: AppBar(
        title: Text(workText(context, 'My Records')),
        actions: [
          IconButton(
            tooltip: workText(context, 'My Submitted Reports'),
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.of(context).push<void>(recordRoute(
              builder: (_) => DailySummariesScreen(api: widget.api),
            )),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(children: [
            DropdownButtonFormField<String>(
              initialValue: _view,
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: workText(context, 'Record type')),
              items: [
                for (final item in kinds.entries)
                  DropdownMenuItem(
                      value: item.key,
                      child: Text(workText(context, item.value),
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _view = value ?? ''),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applySearch(),
              decoration: InputDecoration(
                labelText: workText(context, 'Search titles'),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.search), onPressed: _applySearch),
              ),
            ),
          ]),
        ),
        Expanded(
            child: RecordList(
          key: _list,
          query: (_view, _query),
          empty: workText(context, 'No matching records.'),
          load: (page) => widget.api.get('work-records', {
            'page': '$page',
            if (_view == 'assigned')
              'assigned': '1'
            else if (_view == 'archive') ...{
              'archive': 'archived',
              'kind': 'note'
            } else if (_view.isNotEmpty)
              'kind': _view,
            if (_query.isNotEmpty) 'search': _query,
          }),
          itemBuilder: (context, record) {
            final classification = workMap(record['classification']);
            final category = classificationName(
                context, recordMap(classification['category']));
            return ListTile(
              leading: Icon(recordFlag(record['pinned'])
                  ? Icons.push_pin_outlined
                  : (record['title'].toString().contains('➔') ||
                          record['title'].toString().contains('សាខា')
                      ? Icons.alt_route_rounded
                      : Icons.description_outlined)),
              trailing: const Icon(Icons.chevron_right),
              title: Text(record['title'].toString()),
              subtitle: Text([
                workText(context, recordLabel(record['kind'])),
                if (category.isNotEmpty) category,
                if (record['status'] != null)
                  workText(context, recordLabel(record['status'])),
                recordDate(record['occurred_at'] ?? record['created_at']),
              ].join(' · ')),
              onTap: () async {
                await Navigator.of(context).push<void>(recordRoute(
                  builder: (_) => DailyRecordScreen(
                      api: widget.api,
                      id: recordNumber(record['id']),
                      workRecords: true,
                      assigned: _view == 'assigned'),
                ));
                if (mounted) await _list.currentState?.refresh();
              },
            );
          },
        )),
      ]),
    );
  }
}
