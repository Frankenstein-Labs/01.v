import { GlToggle } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoadmapLabels from 'ee/roadmap/components/roadmap_toggle_labels.vue';

describe('RoadmapLabels', () => {
  let wrapper;

  const createComponent = ({ isShowingLabels = false } = {}) => {
    wrapper = shallowMountExtended(RoadmapLabels, {
      propsData: {
        isShowingLabels,
      },
    });
  };

  const findToggle = () => wrapper.findComponent(GlToggle);

  beforeEach(() => {
    createComponent();
  });

  describe('template', () => {
    it('renders toggle', () => {
      expect(findToggle().exists()).toBe(true);
      expect(findToggle().attributes('label')).toBe('Show labels');
    });

    it.each`
      isShowingLabels
      ${true}
      ${false}
    `('displays toggle value depending on isShowingLabels', ({ isShowingLabels }) => {
      createComponent({ isShowingLabels });

      expect(findToggle().props('value')).toBe(isShowingLabels);
    });

    it('emits `set-labels-visibility` event on click toggle', () => {
      expect(wrapper.emitted('set-labels-visibility')).toBeUndefined();
      findToggle().vm.$emit('change', true);
      expect(wrapper.emitted('set-labels-visibility')).toEqual([[{ isShowingLabels: true }]]);
    });
  });
});
