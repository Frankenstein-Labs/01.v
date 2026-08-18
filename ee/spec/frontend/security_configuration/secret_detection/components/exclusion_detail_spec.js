import { shallowMount } from '@vue/test-utils';
import ExclusionDetail from 'ee/security_configuration/secret_detection/components/exclusion_detail.vue';

describe('ExclusionDetail', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ExclusionDetail, {
      propsData: {
        label: 'type',
        value: 'Path',
      },
    });
  };
  beforeEach(() => {
    createComponent();
  });

  it('renders component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('matches the snapshot', () => {
    expect(wrapper.element).toMatchSnapshot();
  });
});
