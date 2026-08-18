import { createRouter } from 'ee/compliance_dashboard/router';
import StandardsReport from 'ee/compliance_dashboard/components/standards_adherence_report/report.vue';
import StandardsAdherenceUpsell from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_upsell.vue';
import { ROUTE_STANDARDS_ADHERENCE } from 'ee/compliance_dashboard/constants';

describe('compliance dashboard router', () => {
  const basePath = '/-/compliance_dashboard';
  const baseProps = {
    groupPath: 'example-group',
    routes: [ROUTE_STANDARDS_ADHERENCE],
  };

  // Version-agnostic route resolution: vue-router 3 nests the resolved
  // route under `route`, while vue-router 4 (the Vue 3 jest lane) returns
  // the route location directly and has no `match()`.
  const resolveRoute = (router, path) => {
    const resolved = router.resolve(path);
    return resolved.route ?? resolved;
  };

  const componentForRoute = (router, path) => {
    const { matched } = resolveRoute(router, path);
    const leaf = matched[matched.length - 1];
    return leaf.components.default;
  };

  it('renders the upsell component when the adherence report is not enabled', () => {
    const router = createRouter(basePath, {
      ...baseProps,
      adherenceReportEnabled: false,
      adherenceReportUpgradePath: '/groups/example-group/-/billings',
    });

    expect(componentForRoute(router, `/${ROUTE_STANDARDS_ADHERENCE}`)).toBe(
      StandardsAdherenceUpsell,
    );
  });

  it('renders the real report when the adherence report is enabled', () => {
    const router = createRouter(basePath, {
      ...baseProps,
      adherenceReportEnabled: true,
    });

    expect(componentForRoute(router, `/${ROUTE_STANDARDS_ADHERENCE}`)).toBe(StandardsReport);
  });

  it('keeps the standards_adherence route registered under its own name regardless of the flag', () => {
    const router = createRouter(basePath, {
      ...baseProps,
      adherenceReportEnabled: false,
      adherenceReportUpgradePath: '/groups/example-group/-/billings',
    });

    const { matched } = resolveRoute(router, `/${ROUTE_STANDARDS_ADHERENCE}`);
    const names = matched.map((route) => route.name);

    expect(names).toContain(ROUTE_STANDARDS_ADHERENCE);
  });
});
