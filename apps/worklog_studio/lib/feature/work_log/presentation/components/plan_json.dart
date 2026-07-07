import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/entity/user/data/repository/user_repository.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class PlanJson extends StatefulWidget {
  const PlanJson({super.key});

  @override
  State<PlanJson> createState() => _PlanJsonState();
}

class _PlanJsonState extends State<PlanJson> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    getIt<UserRepository>().sessionStorageRepository.load('plan.json').then((
      value,
    ) {
      _controller.text = value as String;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void generatePlan() async {
    // Initialize the Gemini Developer API backend service
    // Create a `GenerativeModel` instance with a model that supports your use case
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
    );

    final input = await getIt<UserRepository>().sessionStorageRepository.load(
      'raw.txt',
    );

    final prompt = [
      Content.text(
        'Ты помощник разработчика. Разбери текст и верни ТОЛЬКО валидный JSON. Не объединяй записи и не суммируй их затраченное время, каждая запись - это отдельное вхождение json. Обрати внимание на формат даты - он очень важен. Формат: {   "actions": [     { "issue": "DEV-123", "date": "8/дек/2025 00:00 AM", "hours": 2, "comment": "..." }   ] } Текст: $input',
      ),
    ];

    try {
      final res = await model.generateContent(prompt);

      _controller.text = res.text!;
    } catch (e) {
      print('❌ LLM error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: MaterialButton(
              onPressed: generatePlan,
              child: const Text('Запросить план'),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'Вставь текст сюда…',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                onTap: () async => await getIt<UserRepository>()
                    .sessionStorageRepository
                    .save(_controller.text),
                title: 'Сохранить',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
