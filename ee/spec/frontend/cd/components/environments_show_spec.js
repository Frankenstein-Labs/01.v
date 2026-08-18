import { shallowMount } from '@vue/test-utils';
import EnvironmentsShow from 'ee/cd/components/environments_show.vue';

describe('EnvironmentsShow', () => {
  let wrapper;

  const createComponent = (id = '1') => {
    wrapper = shallowMount(EnvironmentsShow, {
      mocks: { $route: { params: { id } } },
    });
  };

  it('renders the environment id from the route', () => {
    createComponent('42');

    expect(wrapper.text()).toBe('Environment 42');
  });
});
