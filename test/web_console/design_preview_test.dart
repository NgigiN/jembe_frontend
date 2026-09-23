import 'package:farm_tracker/core/navigation/web_app_router.dart';
import 'package:farm_tracker/features/farms/domain/entities/farm_role.dart';
import 'package:farm_tracker/features/feed/presentation/pages/feed_page.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_dashboard_page.dart';
import 'package:farm_tracker/features/web_console/presentation/pages/web_reports_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'design_preview.dart';
import 'sample_data.dart';

void main() {
  setUpAll(loadConsoleFonts);

  testWidgets('dashboard', (tester) async {
    await capture(
      tester,
      previewShell(
        DashboardView(
          farmName: sampleFarmName,
          subtitle: 'Nakuru · Wednesday 23 September',
          counts: sampleCounts,
          totals: sampleTotals,
          entries: sampleFeed,
          breakdown: sampleBreakdown,
        ),
        location: WebRoutePath.dashboard,
      ),
      'dashboard',
    );
  });

  testWidgets('feed', (tester) async {
    await capture(
      tester,
      previewShell(
        FeedView(
          farmName: sampleFarmName,
          role: FarmRole.owner,
          entries: sampleFeed,
        ),
        location: WebRoutePath.feed,
      ),
      'feed',
    );
  });

  testWidgets('feed-worker', (tester) async {
    await capture(
      tester,
      previewShell(
        FeedView(
          farmName: sampleFarmName,
          role: FarmRole.worker,
          currentUserName: 'Otieno Baraka',
          entries: sampleFeed,
        ),
        location: WebRoutePath.feed,
        sidebar: const ConsoleSidebarProps(
          role: FarmRole.worker,
          userName: 'Otieno Baraka',
          userEmail: 'otieno.b@gmail.com',
        ),
      ),
      'feed-worker',
    );
  });

  testWidgets('reports', (tester) async {
    await capture(
      tester,
      previewShell(
        ReportsView(
          farmName: sampleFarmName,
          year: 2026,
          details: sampleCostDetails,
          breakdowns: sampleBreakdown,
          summaries: sampleMonths,
        ),
        location: WebRoutePath.reports,
      ),
      'reports',
    );
  });

  testWidgets('loading', (tester) async {
    await capture(
      tester,
      previewShell(
        const DashboardView(
          farmName: sampleFarmName,
          subtitle: 'Nakuru · Wednesday 23 September',
          counts: null,
          totals: null,
          entries: null,
          breakdown: null,
        ),
        location: WebRoutePath.dashboard,
      ),
      'loading',
    );
  });

  testWidgets('error', (tester) async {
    await capture(
      tester,
      previewShell(
        const DashboardView(
          farmName: sampleFarmName,
          subtitle: 'Nakuru · Wednesday 23 September',
          counts: null,
          totals: null,
          entries: null,
          breakdown: null,
          errorMessage: 'GET /api/v1/dashboard · 503 · request 8f1c2a',
        ),
        location: WebRoutePath.dashboard,
      ),
      'error',
    );
  });

  testWidgets('dashboard-dark', (tester) async {
    await capture(
      tester,
      previewShell(
        DashboardView(
          farmName: sampleFarmName,
          subtitle: 'Nakuru · Wednesday 23 September',
          counts: sampleCounts,
          totals: sampleTotals,
          entries: sampleFeed,
          breakdown: sampleBreakdown,
        ),
        location: WebRoutePath.dashboard,
        brightness: Brightness.dark,
      ),
      'dashboard-dark',
    );
  });
}
