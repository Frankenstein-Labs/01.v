import { GlIcon, GlToggle } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getBoardNamespaceStatusesQuery from 'ee_else_ce/work_items/board/graphql/get_namespace_statuses.query.graphql';
import WorkItemDisplaySettingsGroupBy from '~/work_items/list/components/work_item_display_settings_group_by.vue';
import workItemsGroupByVisibleGroupsQuery from '~/work_items/board/grouping/graphql/client/visible_groups.query.graphql';
import { SHOW_ALL_GROUPS } from '~/work_items/board/grouping/visibility';
import { buildStatus, buildNamespaceStatusesResponse } from 'jest/work_items/board/mock_data';

jest.mock('~/work_items/list/display_settings_preferences', () => ({
  persistMetadataPreference: jest.fn(),
  alertPreferenceError: jest.fn(),
}));

Vue.use(VueApollo);

// CE's placeholder strategy never decorates a header with an icon, so real
// status icon rendering can only be exercised here, against the EE strategy.
describe('WorkItemDisplaySettingsGroupBy', () => {
  let wrapper;

  const status = buildStatus(1, 'Triage');
  const groupByValuesHandler = jest.fn();

  const findToggles = () => wrapper.findAllComponents(GlToggle);
  const findIcon = () => wrapper.findComponent(GlIcon);

  const createComponent = ({ groupByValues = [status] } = {}) => {
    groupByValuesHandler.mockResolvedValue(buildNamespaceStatusesResponse(groupByValues));

    const apolloProvider = createMockApollo([
      [getBoardNamespaceStatusesQuery, groupByValuesHandler],
    ]);
    apolloProvider.clients.defaultClient.writeQuery({
      query: workItemsGroupByVisibleGroupsQuery,
      data: {
        workItemsGroupByVisibleGroups: SHOW_ALL_GROUPS,
        workItemsGroupByVisibleGroupsHydrated: true,
      },
    });

    wrapper = shallowMountExtended(WorkItemDisplaySettingsGroupBy, {
      apolloProvider,
      propsData: {
        fullPath: 'group/full/path',
        workItemTypeId: 'gid://gitlab/WorkItems::Type/1',
      },
    });
  };

  it('renders the status icon alongside its toggle', async () => {
    createComponent();
    await waitForPromises();

    expect(findToggles()).toHaveLength(1);
    expect(findIcon().props('name')).toBe(status.iconName);
    expect(findIcon().attributes('style')).toContain('color:');
  });
});
