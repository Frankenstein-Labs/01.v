import { shallowMount } from '@vue/test-utils';
import SiteProfileSelector from 'ee/security_configuration/dast_profiles/dast_profile_selector/site_profile_selector.vue';
import EmptyState from 'ee/security_configuration/dast_profiles/dast_profile_selector/empty_state.vue';
import { siteProfiles } from 'ee_jest/security_configuration/dast_profiles/mocks/mock_data';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

describe('SiteProfileSelector', () => {
  let wrapper;

  const createComponent = (props) => {
    wrapper = extendedWrapper(
      shallowMount(SiteProfileSelector, {
        propsData: {
          profiles: [],
          props,
        },
        stubs: {
          EmptyState,
        },
      }),
    );
  };

  const findSelectProfileBtn = () => wrapper.findComponentByTestId('select-profile-action-btn');

  it('renders properly with no profiles', () => {
    createComponent({});

    expect(wrapper.element).toMatchSnapshot();
  });

  it('renders properly with profiles', () => {
    createComponent({
      profiles: siteProfiles,
      selectedProfile: siteProfiles[0],
    });
    expect(wrapper.element).toMatchSnapshot();
  });

  it('action button should emit correct event', () => {
    createComponent();

    expect(findSelectProfileBtn().exists()).toBe(true);

    findSelectProfileBtn().vm.$emit('click');
    expect(wrapper.emitted('open-drawer')).toHaveLength(1);
  });
});
