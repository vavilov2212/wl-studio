// PROTOTYPE: This feature is not wired into any app route and is kept for reference only.
import 'package:flutter/material.dart';
import 'package:worklog_studio/feature/work_log/presentation/components/plan_json.dart';
import 'package:worklog_studio/feature/work_log/presentation/components/raw_txt.dart';

class RawDataView extends StatefulWidget {
  const RawDataView({super.key});

  @override
  State<RawDataView> createState() => RawDataViewState();
}

class RawDataViewState extends State<RawDataView> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        children: [
          SizedBox(height: 50),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.red),
                    child: TabBar(
                      tabs: [
                        Text('Daily', style: TextStyle(color: Colors.white)),
                        Text('Plan', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(color: Colors.green),
                      child: TabBarView(
                        children: [
                          const Center(child: RawTxt()),
                          const Center(child: PlanJson()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
