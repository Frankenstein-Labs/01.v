import { GlIcon, GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import WorkItemWeightConflictWarning from 'ee/work_items/components/work_item_weight_conflict_warning.vue';

describe('WorkItemWeightConflictWarning component', () => {
  let wrapper;

  const createComponent = ({ weight = null, rolledUpWeight = null } = {}) => {
    wrapper = shallowMount(WorkItemWeightConflictWarning, {
      propsData: {
        weight,
        rolledUpWeight,
      },
    });
  };

  const findGlIcon = () => wrapper.findComponent(GlIcon);
  const findGlPopover = () => wrapper.findComponent(GlPopover);

  it.each([
    [null, 5, false],
    [3, null, false],
    [1, 1, false],
    [5, 1, true],
    [1, 0, true],
  ])(
    'renders icon and popover when weight %s and rolledUpWeight %s conflict',
    (weight, rolledUpWeight, visible) => {
      createComponent({ weight, rolledUpWeight });

      expect(findGlIcon().exists()).toBe(visible);
      expect(findGlPopover().exists()).toBe(visible);
    },
  );

  it('shows both weights in the popover', () => {
    createComponent({ weight: 5, rolledUpWeight: 9 });

    expect(findGlPopover().text()).toContain(
      'Assigned weight does not match total of its child items.',
    );
    expect(findGlPopover().text()).toContain('Assigned weight 5');
    expect(findGlPopover().text()).toContain('Total of child items 9');
  });
});
