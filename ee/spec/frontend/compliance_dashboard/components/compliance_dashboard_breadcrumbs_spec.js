import { GlBreadcrumb } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ComplianceDashboardBreadcrumbs from 'ee/compliance_dashboard/components/compliance_dashboard_breadcrumbs.vue';
import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_NEW_FRAMEWORK,
  ROUTE_NEW_FRAMEWORK_SUCCESS,
  ROUTE_EDIT_FRAMEWORK,
} from 'ee/compliance_dashboard/constants';
import { mockedRoutes } from '../mock_data';

describe('ComplianceDashboardBreadcrumbs', () => {
  let wrapper;

  const breadcrumbItemsDictionary = {
    [ROUTE_STANDARDS_ADHERENCE]: [
      { text: 'Compliance center', to: '/' },
      { text: 'Status', to: { name: 'standards_adherence' } },
    ],
    [ROUTE_VIOLATIONS]: [
      { text: 'Compliance center', to: '/' },
      { text: 'Violations', to: { name: 'violations' } },
    ],
    [ROUTE_FRAMEWORKS]: [
      { text: 'Compliance center', to: '/' },
      { text: 'Frameworks', to: { name: 'frameworks' } },
    ],
    [ROUTE_PROJECTS]: [
      { text: 'Compliance center', to: '/' },
      { text: 'Projects', to: { name: 'projects' } },
    ],
    [ROUTE_NEW_FRAMEWORK]: [
      { text: 'Compliance center', to: '/' },
      { text: 'Frameworks', to: { name: 'frameworks' } },
      { text: 'New', to: { name: 'new_framework' } },
    ],
    [ROUTE_NEW_FRAMEWORK_SUCCESS]: [
      { text: 'Compliance center', to: '/' },
      { text: 'Frameworks', to: { name: 'frameworks' } },
      { text: 'Success', to: { name: 'new_framework_success' } },
    ],
    [ROUTE_EDIT_FRAMEWORK]: [
      { text: 'Compliance center', to: '/' },
      { text: 'Frameworks', to: { name: 'frameworks' } },
      { text: 'Edit', to: { name: 'frameworks/:id' } },
    ],
  };

  const createComponent = ($route, props = {}) => {
    wrapper = shallowMountExtended(ComplianceDashboardBreadcrumbs, {
      mocks: {
        $route,
      },
      propsData: { staticBreadcrumbs: [], ...props },
    });
  };

  const findGlBreadcrumb = () => wrapper.findComponent(GlBreadcrumb);

  describe.each(mockedRoutes)('when route path is $fullPath', ({ name, fullPath }) => {
    it('passes the correct breadcrumbs items to GlBreadcrumb', () => {
      const staticBreadcrumb = { text: 'Static breadcrumb', href: '/static' };
      createComponent(
        { name, fullPath },
        {
          staticBreadcrumbs: [staticBreadcrumb],
        },
      );

      expect(findGlBreadcrumb().props('items')).toStrictEqual([
        staticBreadcrumb,
        ...breadcrumbItemsDictionary[name],
      ]);
    });
  });
});
