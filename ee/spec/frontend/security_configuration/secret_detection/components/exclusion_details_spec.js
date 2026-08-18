import { shallowMount } from '@vue/test-utils';
import ExclusionDetails from 'ee/security_configuration/secret_detection/components/exclusion_details.vue';
import { projectSecurityExclusions } from '../mock_data';

const [exclusion] = projectSecurityExclusions;

describe('ExclusionDetails', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ExclusionDetails, {
      propsData: {
        exclusion,
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
