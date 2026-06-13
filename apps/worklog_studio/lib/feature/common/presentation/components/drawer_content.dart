import 'package:flutter/material.dart';
import 'package:worklog_studio_style_system/worklog_studio_style_system.dart';

class DrawerContent extends StatelessWidget {
﻿final Widget? meta;
﻿final Widget content;
﻿final Widget? footer;

﻿const DrawerContent({
﻿super.key,
﻿this.meta,
﻿required this.content,
﻿this.footer,
﻿});

﻿@override
﻿Widget build(BuildContext context) {
﻿final theme = context.theme;

﻿// Single scroll region — meta, content, and footer are all slivers
﻿// so the entire drawer body scrolls as one unit regardless of screen height.
﻿return CustomScrollView(
﻿slivers: [
﻿if (meta != null)
﻿SliverToBoxAdapter(
﻿child: Padding(
﻿padding: EdgeInsets.fromLTRB(
﻿  theme.spacings.xl,
﻿  theme.spacings.md,
﻿    theme.spacings.xl,
﻿    theme.spacings.none,
﻿    ),
﻿    child: meta!,
﻿    ),
﻿  ),
﻿SliverToBoxAdapter(child: content),
﻿if (footer != null)
﻿  SliverFillRemaining(
﻿      hasScrollBody: false,
﻿        child: Align(
﻿            alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(theme.spacings.xl),
                child: footer!,
              ),
            ),
          ),
      ],
    );
  }
}
