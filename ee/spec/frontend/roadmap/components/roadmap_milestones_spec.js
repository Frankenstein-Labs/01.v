import { GlFormGroup, GlFormRadioGroup, GlToggle } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoadmapMilestones from 'ee/roadmap/components/roadmap_milestones.vue';
import { MILESTONES_ALL, MILESTONES_OPTIONS, MILESTONES_GROUP } from 'ee/roadmap/constants';

describe('RoadmapMilestones', () => {
  let wrapper;

  const createComponent = ({ isShowingMilestones = true } = {}) => {
    wrapper = shallowMountExtended(RoadmapMilestones, {
      propsData: {
        milestonesType: MILESTONES_ALL,
        isShowingMilestones,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findToggle = () => wrapper.findComponent(GlToggle);

  beforeEach(() => {
    createComponent();
  });

  describe('template', () => {
    it('renders form group', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(findFormGroup().attributes('label')).toBe('Milestones');
    });

    it.each`
      isShowingMilestones
      ${true}
      ${false}
    `('displays radio form group depending on isShowingMilestones', ({ isShowingMilestones }) => {
      createComponent({ isShowingMilestones });

      expect(findFormRadioGroup().exists()).toBe(isShowingMilestones);
      if (isShowingMilestones) {
        expect(findFormRadioGroup().props('options')).toEqual(MILESTONES_OPTIONS);
      }
    });
  });

  it('emits `set-milestones-settings` event when radio group changes', () => {
    createComponent();
    findFormRadioGroup().vm.$emit('change', MILESTONES_GROUP);

    expect(wrapper.emitted('set-milestones-settings')).toEqual([
      [
        {
          milestonesType: MILESTONES_GROUP,
        },
      ],
    ]);
  });

  it('emits `set-milestones-settings` event when milestones visibility is toggled', () => {
    createComponent();
    findToggle().vm.$emit('change');

    expect(wrapper.emitted('set-milestones-settings')).toEqual([
      [
        {
          isShowingMilestones: false,
        },
      ],
    ]);
  });
});
