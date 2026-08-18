import { GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import StatusIcon from 'ee/security_orchestration/components/policies/status_icon.vue';

describe('StatusIcon', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(StatusIcon, {
      propsData,
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);

  describe('disabled icon', () => {
    it.each`
      enabled  | ariaLabel                   | name                     | variant       | text
      ${false} | ${'The policy is disabled'} | ${'check-circle-dashed'} | ${'disabled'} | ${'Not enabled'}
      ${true}  | ${'The policy is enabled'}  | ${'check-circle-filled'} | ${'success'}  | ${'Enabled'}
    `('renders status icon', ({ enabled, ariaLabel, name, variant, text }) => {
      createComponent({ enabled });

      expect(findIcon().props('ariaLabel')).toBe(ariaLabel);
      expect(findIcon().props('name')).toBe(name);
      expect(findIcon().props('variant')).toBe(variant);
      expect(wrapper.text()).toBe(text);
    });
  });
});
