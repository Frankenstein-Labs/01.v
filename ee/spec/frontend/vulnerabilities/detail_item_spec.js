import { mount } from '@vue/test-utils';
import DetailItem from 'ee/vulnerabilities/components/detail_item.vue';

describe('DetailItem', () => {
  let wrapper;

  const defaultProps = {
    sprintfMessage: '%{labelStart}Scanner%{labelEnd}: %{scanner}',
  };

  const createWrapper = (props = {}) => {
    wrapper = mount(DetailItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      slots: {
        default: '<span>Test content</span>',
      },
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders correct message', () => {
      expect(wrapper.text()).toBe('Scanner: Test content');
    });
  });
});
