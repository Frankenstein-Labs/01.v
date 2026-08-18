import { shallowMount } from '@vue/test-utils';
import ContributionsByUsersTable from 'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_by_user_table.vue';
import GroupMembersTable from 'ee/analytics/contribution_analytics/components/group_members_table.vue';
import { MOCK_CONTRIBUTIONS } from 'ee_jest/analytics/contribution_analytics/mock_data';

describe('ContributionsByUsersTable', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(ContributionsByUsersTable, {
      propsData: {
        data: [...MOCK_CONTRIBUTIONS],
        options: props.options,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the GroupMembersTable component', () => {
    expect(wrapper.findComponent(GroupMembersTable).exists()).toBe(true);
  });

  it('passes the data prop correctly to GroupMembersTable', () => {
    expect(wrapper.findComponent(GroupMembersTable).props('contributions')).toEqual(
      MOCK_CONTRIBUTIONS,
    );
  });
});
