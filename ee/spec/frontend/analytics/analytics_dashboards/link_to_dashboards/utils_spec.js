import { hasDashboard } from 'ee/analytics/analytics_dashboards/link_to_dashboards/utils';

describe('link_to_dashboards/utils', () => {
  describe('hasDashboard', () => {
    it.each`
      description                                      | groupOrProject                                                                                                   | expected
      ${'dashboard with matching slug exists'}         | ${{ customizableDashboards: { nodes: [{ slug: 'duo_and_sdlc_trends' }, { slug: 'value_streams_dashboard' }] } }} | ${true}
      ${'dashboard with matching slug does not exist'} | ${{ customizableDashboards: { nodes: [{ slug: 'value_streams_dashboard' }] } }}                                  | ${false}
      ${'customizableDashboards is undefined'}         | ${{}}                                                                                                            | ${false}
      ${'customizableDashboards.nodes is undefined'}   | ${{ customizableDashboards: {} }}                                                                                | ${false}
      ${'customizableDashboards.nodes is empty'}       | ${{ customizableDashboards: { nodes: [] } }}                                                                     | ${false}
    `('returns $expected when $description', ({ groupOrProject, expected }) => {
      expect(hasDashboard(groupOrProject, 'duo_and_sdlc_trends')).toBe(expected);
    });
  });
});
