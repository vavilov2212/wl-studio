import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/entity/user/data/repository/user_repository.dart';
import 'package:worklog_studio/core/environment/app_environment.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_config.dart';
import 'package:worklog_studio/feature/app/layout/app_bar/app_bar_provider.dart';
import 'package:worklog_studio/feature/app/layout/scaffold/app_scaffold.dart';
import 'package:worklog_studio/feature/work_log/presentation/components/raw_data_view.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class DataLayout extends StatefulWidget {
  const DataLayout({super.key});

  @override
  State<DataLayout> createState() => DataLayoutState();
}

class DataLayoutState extends State<DataLayout> {
  static const _api = 'http://localhost:3000';

  Map<String, dynamic>? plan;
  int index = 0;
  String state = 'idle';
  bool fillDate = true;
  bool fillHours = true;
  bool fillComment = true;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _fetchState();
  }

  Future<void> _loadPlan() async {
    try {
      final jsonStr = await getIt<UserRepository>().sessionStorageRepository
          .load('plan.json');
      setState(() {
        plan = jsonDecode(jsonStr!);
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _fetchState() async {
    final res = await http.get(Uri.parse('$_api/state'));
    final data = jsonDecode(res.body);
    setState(() => state = data['state']);
  }

  Future<void> _call(String path, [Map<String, dynamic>? body]) async {
    setState(() => loading = true);
    final res = await http.post(
      Uri.parse('$_api/$path'),
      headers: {'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
    final data = jsonDecode(res.body);
    setState(() {
      state = data['state'];
      loading = false;
    });
  }

  Map<String, dynamic> get action => plan!['actions'][index];
  @override
  Widget build(BuildContext context) {
    return AppBarProvider(
      config: AppBarConfig(
        title: Text(AppEnvironment.instance().config.flavor.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_frames_outlined),
            tooltip: 'Show Drawer',
            onPressed: () {
              getIt<DrawerService>().toggle(
                layer: DrawerLayer.local,
                builder: (_) => RawDataView(),
              );
            },
          ),
        ],
      ),

      child: AppScaffold(
        body: plan == null
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Text('FSM state: $state')],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),

                    Expanded(
                      flex: 3,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, _index) {
                          final _action = plan!['actions'][_index];
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(8),
                              ),
                              color: _index != index
                                  ? Colors.grey.shade300
                                  : Colors.green.shade300,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Issue: ${_action['issue']}'),
                                  Text('Hours: ${_action['hours']}'),
                                  Text('Date: ${_action['date']}'),
                                  Text('Comment: ${_action['comment']}'),
                                ],
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, _) => SizedBox(height: 12),
                        itemCount: plan!['actions'].length,
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Issue: ${action['issue']}'),
                          Text('Hours: ${action['hours']}'),
                          Text('Date: ${action['date']}'),
                          Text('Comment: ${action['comment']}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    if (loading) const LinearProgressIndicator(),

                    Wrap(
                      spacing: 8,
                      children: [
                        PrimaryButton(
                          type: ButtonType.ghost,
                          onTap: () => _call('start'),
                          title: 'Start',
                        ),
                        PrimaryButton(
                          type: ButtonType.secondary,
                          onTap: () =>
                              _call('openIssue', {'issue': action['issue']}),
                          title: 'Open issue',
                        ),
                        PrimaryButton(
                          type: ButtonType.secondary,
                          onTap: () => _call('openLogWork'),
                          title: 'Log work',
                        ),
                        if (fillDate)
                          PrimaryButton(
                            type: ButtonType.secondary,
                            onTap: () =>
                                _call('fillDate', {'date': action['date']}),
                            title: 'Fill date',
                          ),
                        if (fillHours)
                          PrimaryButton(
                            type: ButtonType.secondary,
                            onTap: () =>
                                _call('fillHours', {'hours': action['hours']}),
                            title: 'Fill hours',
                          ),
                        if (fillComment)
                          PrimaryButton(
                            type: ButtonType.secondary,
                            onTap: () => _call('fillComment', {
                              'comment': action['comment'],
                            }),
                            title: 'Fill comment',
                          ),
                        PrimaryButton(
                          onTap: () => _call('submit'),
                          title: 'Submit',
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CheckboxListTile(
                              value: fillDate,
                              onChanged: (v) => setState(() => fillDate = v!),
                              title: const Text('Fill date'),
                            ),
                            CheckboxListTile(
                              value: fillHours,
                              onChanged: (v) => setState(() => fillHours = v!),
                              title: const Text('Fill hours'),
                            ),
                            CheckboxListTile(
                              value: fillComment,
                              onChanged: (v) =>
                                  setState(() => fillComment = v!),
                              title: const Text('Fill comment'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Row(
                      spacing: 12,
                      children: [
                        PrimaryButton(
                          type: ButtonType.secondary,
                          onTap: index - 1 > 0
                              ? () => setState(() => index--)
                              : null,
                          title: 'Previous issue',
                        ),
                        PrimaryButton(
                          type: ButtonType.secondary,
                          onTap: index + 1 < plan!['actions'].length
                              ? () => setState(() => index++)
                              : null,
                          title: 'Next issue',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
