enum AppRoute { dashboard, history, reports, projects, tasks, settingsGeneral, settingsHotkeys }

bool isSettingsRoute(AppRoute route) =>
    route == AppRoute.settingsGeneral || route == AppRoute.settingsHotkeys;
