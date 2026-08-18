import { shallowMount } from '@vue/test-utils';
import WelcomePage from '~/vue_shared/new_namespace/components/welcome.vue';
import TopLevelGroupLimitAlert from 'ee_component/groups/components/top_level_group_limit_alert.vue';

describe('Welcome page', () => {
  let wrapper;

  const createComponent = ({ inject }) => {
    wrapper = shallowMount(WelcomePage, {
      slots: {},
      propsData: { title: 'foo', panels: [] },
      provide: {
        ...inject,
      },
    });
  };

  describe('when `enforceTopLevelGroupLimit` is not provided', () => {
    it('does not render the TopLevelGroupLimitAlert component', () => {
      createComponent({});
      expect(wrapper.findComponent(TopLevelGroupLimitAlert).exists()).toBe(false);
    });
  });

  describe('when `enforceTopLevelGroupLimit` is true', () => {
    it('renders the TopLevelGroupLimitAlert component', () => {
      createComponent({ inject: { enforceTopLevelGroupLimit: true } });
      expect(wrapper.findComponent(TopLevelGroupLimitAlert).exists()).toBe(true);
    });
  });
});
