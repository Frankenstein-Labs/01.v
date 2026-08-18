import { shallowMount } from '@vue/test-utils';
import Code from 'ee/vulnerabilities/components/generic_report/types/report_type_code.vue';
import CodeBlock from '~/vue_shared/components/code_block.vue';

const TEST_DATA = {
  value: '<h1>Foo</h1>',
};

describe('ee/vulnerabilities/components/generic_report/types/report_type_code.vue', () => {
  /** @type {import('@vue/test-utils').Wrapper} */
  let wrapper;

  const createWrapper = () => {
    return shallowMount(Code, {
      propsData: {
        ...TEST_DATA,
      },
    });
  };

  const findCodeBlock = () => wrapper.findComponent(CodeBlock);

  beforeEach(() => {
    wrapper = createWrapper();
  });

  it('renders a code-block', () => {
    expect(findCodeBlock().exists()).toBe(true);
  });

  it('passes the given value to the code-block component', () => {
    expect(findCodeBlock().props('code')).toBe(TEST_DATA.value);
  });
});
