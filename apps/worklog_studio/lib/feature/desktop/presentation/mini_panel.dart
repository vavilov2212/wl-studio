import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:worklog_studio/feature/common/presentation/components/inline_field_controller.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_panel_command_bus.dart';
import 'package:worklog_studio/feature/desktop/bloc/mini_tracker_cubit.dart';
import 'package:worklog_studio/feature/desktop/presentation/components/mini_active_session_card.dart';
import 'package:worklog_studio/feature/desktop/presentation/components/mini_recent_activity_section.dart';
import 'package:worklog_studio/feature/desktop/presentation/components/mini_search_results_section.dart';
import 'package:worklog_studio/core/services/desktop/desktop_service_registry.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class MiniPanel extends StatefulWidget {
  const MiniPanel({super.key});

  @override
  State<MiniPanel> createState() => _MiniPanelState();
}

class _MiniPanelState extends State<MiniPanel> {
  bool _isVisible = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _commentController = TextEditingController();
  final InlineFieldController _commentFieldController = InlineFieldController();
  final FocusNode _commentFocusNode = FocusNode();
  StreamSubscription<MiniPanelCommand>? _commandSub;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {});
    });
    _commentFieldController.addListener(_onCommentEditModeChanged);
    _commandSub = context.read<MiniPanelCommandBus>().stream.listen(
      _handleCommand,
    );
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _commentController.dispose();
    _commentFieldController.removeListener(_onCommentEditModeChanged);
    _commentFieldController.dispose();
    _commentFocusNode.dispose();
    _commandSub?.cancel();
    super.dispose();
  }

  void _onCommentEditModeChanged() {
    if (!mounted) return;
    if (!_commentFieldController.isEditing) {
      final cubit = context.read<MiniTrackerCubit>();
      if ((cubit.state.activeEntry?.comment ?? '') != _commentController.text) {
        cubit.updateComment(_commentController.text);
      }
    }
  }

  void _handleCommand(MiniPanelCommand command) {
    if (!mounted) return;
    switch (command) {
      case MiniPanelCommand.seedComment:
        // seedComment is directed at the activity window only; the mini
        // panel has no passive-seed flow and can ignore it.
        break;
      case MiniPanelCommand.focusComment:
        _commentFieldController.enterEditMode(_commentController.text);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _commentFocusNode.requestFocus();
        });
      case MiniPanelCommand.acceptComment:
        _commentFieldController.handleEditorCommit(_commentController.text);
      case MiniPanelCommand.dismissComment:
        final persisted =
            context.read<MiniTrackerCubit>().state.activeEntry?.comment ?? '';
        _commentController.text = persisted;
        _commentFieldController.handleEditorCancel();
      case MiniPanelCommand.autoDismissComment:
        final persisted =
            context.read<MiniTrackerCubit>().state.activeEntry?.comment ?? '';
        if (_commentController.text != persisted) {
          // There's an unsaved edit - commit it rather than silently discard.
          _commentFieldController.handleEditorCommit(_commentController.text);
        } else {
          _commentController.text = persisted;
          _commentFieldController.handleEditorCancel();
        }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MiniTrackerCubit, MiniTrackerState>(
      builder: (context, state) {
        final theme = context.theme;
        final palette = theme.colorsPalette;

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isVisible ? 1.0 : 0.0,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorsPalette.background.canvas,
              borderRadius: BorderRadius.circular(theme.spacings.md),
              boxShadow: [theme.shadows.md],
              border: Border.all(
                color: palette.border.primary.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.spacings.md),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniPanelHeader(theme: theme),
                  SizedBox(height: theme.spacings.lg),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacings.lg,
                    ),
                    child: PrimaryInput(
                      label: null,
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      hintText: 'Search or start a task…',
                      autofocus: true,
                      suffixWidget:
                          (_searchFocusNode.hasFocus || _query.isNotEmpty)
                          ? MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: _clearSearch,
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: theme.colorsPalette.text.secondary,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.search,
                              size: 16,
                              color: theme.colorsPalette.text.muted,
                            ),
                      onChanged: (value) {
                        setState(() => _query = value.trim());
                      },
                    ),
                  ),
                  SizedBox(height: theme.spacings.lg),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorsPalette.background.canvas,
                      ),
                      child: _query.isEmpty
                          ? SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacings.lg,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MiniActiveSessionCard(
                                      isRunning: state.isRunning,
                                      activeEntry: state.activeEntry,
                                      state: state,
                                      commentController: _commentController,
                                      commentFieldController:
                                          _commentFieldController,
                                      commentFocusNode: _commentFocusNode,
                                    ),
                                    SizedBox(height: theme.spacings.lg),
                                    MiniRecentActivitySection(
                                      state: state,
                                      onEntrySelected: _clearSearch,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: theme.spacings.lg,
                                ),
                                child: MiniSearchResultsSection(
                                  state: state,
                                  query: _query,
                                  onEntrySelected: _clearSearch,
                                ),
                              ),
                            ),
                    ),
                  ),
                  _MiniPanelFooter(theme: theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniPanelHeader extends StatelessWidget {
  final AppThemeExtension theme;

  const _MiniPanelHeader({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorsPalette.background.surface,
        border: Border.all(color: theme.colorsPalette.accent.primaryMuted),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.spacings.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Worklog Studio',
              style: theme.commonTextStyles.captionSemiBold,
            ),
            const Expanded(flex: 1, child: SizedBox.shrink()),
            PrimaryButton(
              type: ButtonType.ghost,
              size: ButtonSize.sm,
              leftIcon: WorklogStudioAssets.vectors.plus24Svg,
              onTap: () {},
            ),
            SizedBox(width: theme.spacings.xxs),
            PrimaryButton(
              type: ButtonType.ghost,
              size: ButtonSize.sm,
              leftIconWidget: const Icon(Icons.desktop_windows, size: 16),
              onTap: () {
                DesktopServiceRegistry.instance.openMainWindowFromTray();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPanelFooter extends StatelessWidget {
  final AppThemeExtension theme;

  const _MiniPanelFooter({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorsPalette.accent.primaryMuted,
        border: Border.all(color: theme.colorsPalette.accent.primaryMuted),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacings.lg,
          vertical: theme.spacings.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Today 06h 15m   |   Total 24h 30m',
              style: theme.commonTextStyles.caption.copyWith(
                color: theme.colorsPalette.text.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
