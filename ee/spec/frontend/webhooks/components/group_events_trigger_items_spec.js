import { nextTick } from 'vue';
import GroupEventsTriggerItems from 'ee/webhooks/components/group_events_trigger_items.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('GroupEventsTriggerItems', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(GroupEventsTriggerItems, {
      propsData: {
        initialMemberTrigger: false,
        initialProjectTrigger: false,
        initialSubgroupTrigger: true,
        ...props,
      },
    });
  };

  const findProjectTrigger = () => wrapper.findComponentByTestId('projectEvents');
  const findMemberTrigger = () => wrapper.findComponentByTestId('memberEvents');
  const findSubgroupTrigger = () => wrapper.findComponentByTestId('subgroupEvents');

  it('renders Group Event triggers', () => {
    createComponent();

    expect(findProjectTrigger().attributes('triggername')).toBe('projectEvents');
    expect(findProjectTrigger().attributes('label')).toBe('Project events');
    expect(findMemberTrigger().attributes('triggername')).toBe('memberEvents');
    expect(findMemberTrigger().attributes('label')).toBe('Member events');
    expect(findSubgroupTrigger().attributes('triggername')).toBe('subgroupEvents');
    expect(findSubgroupTrigger().attributes('label')).toBe('Subgroup events');
  });

  it('updates group triggers data when items emits input event', async () => {
    createComponent();
    const memberTrigger = findMemberTrigger();
    const projectTrigger = findProjectTrigger();
    const subgroupTrigger = findSubgroupTrigger();

    expect(memberTrigger.props('value')).toBe(false);
    expect(projectTrigger.props('value')).toBe(false);
    expect(subgroupTrigger.props('value')).toBe(true);

    await memberTrigger.vm.$emit('input', true);
    await projectTrigger.vm.$emit('input', true);
    await subgroupTrigger.vm.$emit('input', false);

    await nextTick();
    expect(memberTrigger.props('value')).toBe(true);
    expect(projectTrigger.props('value')).toBe(true);
    expect(subgroupTrigger.props('value')).toBe(false);
  });
});
