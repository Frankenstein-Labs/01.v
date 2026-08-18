import { shallowMount } from '@vue/test-utils';

import EpicItem from 'ee/roadmap/components/epic_item.vue';
import EpicItemContainer from 'ee/roadmap/components/epic_item_container.vue';

import { mockGroupId, mockFormattedChildEpic1 } from 'ee_jest/roadmap/mock_data';

const createComponent = ({ currentGroupId = mockGroupId, children = [], childLevel = 0 } = {}) => {
  return shallowMount(EpicItemContainer, {
    stubs: {
      EpicItem: true,
    },
    provide: {
      currentGroupId,
    },
    propsData: {
      children,
      childLevel,
      filterParams: {},
    },
  });
};

describe('EpicItemContainer', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('template', () => {
    it('renders epic list container', () => {
      expect(wrapper.classes('epic-list-item-container')).toBe(true);
    });

    it('renders one Epic item element per child', () => {
      wrapper = createComponent({
        children: [mockFormattedChildEpic1],
      });

      expect(wrapper.findComponent(EpicItem).exists()).toBe(true);
      expect(wrapper.findAllComponents(EpicItem)).toHaveLength(1);
    });
  });
});
