import { mount } from '@vue/test-utils';
import App from './App.vue';
import HelloWorld from './components/HelloWorld.vue';

describe('App', () => {
  it('renders HelloWorld component', () => {
    const wrapper = mount(App);

    expect(wrapper.findComponent(HelloWorld).exists()).toBe(true);
  });
});
