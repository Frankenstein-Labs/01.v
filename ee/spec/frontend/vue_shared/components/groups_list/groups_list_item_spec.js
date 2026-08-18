import GroupsListItemPlanBadge from 'ee_component/vue_shared/components/groups_list/groups_list_item_plan_badge.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupsListItem from '~/vue_shared/components/groups_list/groups_list_item.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { groups } from 'jest/vue_shared/components/groups_list/mock_data';

describe('GroupsListItem', () => {
  let wrapper;

  const [group] = groups;

  const defaultPropsData = { group };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(GroupsListItem, {
      propsData: { ...defaultPropsData, ...propsData },
      stubs: {
        GroupsListItemPlanBadge: stubComponent(GroupsListItemPlanBadge),
      },
    });
  };

  it('renders plan badge and passes group prop', async () => {
    createComponent();

    await waitForPromises();

    expect(wrapper.findComponent(GroupsListItemPlanBadge).props()).toEqual({
      group,
    });
  });
});
