// PROTOTYPE: This feature is not wired into any app route and is kept for reference only.
import 'package:flutter/material.dart';
import 'package:worklog_studio/core/services/service_locator/service_locator.dart';
import 'package:worklog_studio/entity/user/data/repository/user_repository.dart';
import 'package:worklog_studio_style_system/ui_kit/ui_kit.dart';

class RawTxt extends StatefulWidget {
  const RawTxt({super.key});

  @override
  State<RawTxt> createState() => _RawTxtState();
}

class _RawTxtState extends State<RawTxt> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    getIt<UserRepository>().sessionStorageRepository.load('raw.txt').then((
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              type: ButtonType.primary,
              onTap: () async => await getIt<UserRepository>()
                  .sessionStorageRepository
                  .save(_controller.text),
              title: 'Сохранить',
            ),
          ),
        ),
      ],
    );
  }
}
