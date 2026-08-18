import { shallowMount } from '@vue/test-utils';
import Text from 'ee/vulnerabilities/components/generic_report/types/report_type_value.vue';

describe('ee/vulnerabilities/components/generic_report/types/report_type_value.vue', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  describe.each`
    fieldType    | value
    ${'string'}  | ${'some string'}
    ${'number'}  | ${8}
    ${'boolean'} | ${true}
    ${'boolean'} | ${false}
  `('with value of type "$fieldType"', ({ fieldType, value }) => {
    const createWrapper = () => {
      return shallowMount(Text, {
        propsData: {
          type: 'text',
          name: `${fieldType} field`,
          value,
        },
      });
    };

    beforeEach(() => {
      wrapper = createWrapper();
    });

    it(`renders ${fieldType} type`, () => {
      expect(wrapper.text()).toBe(value.toString());
    });
  });
});
