import { mount, shallowMount } from '@vue/test-utils';
import { merge, omit } from 'lodash-es';
import ProfilesList from 'ee/security_configuration/dast_profiles/components/dast_profiles_list.vue';
import Component from 'ee/security_configuration/dast_profiles/components/dast_scanner_profiles_list.vue';
import { scannerProfiles } from '../mocks/mock_data';

describe('EE - DastScannerProfileList', () => {
  let wrapper;

  const defaultProps = {
    profiles: [],
    tableLabel: 'Scanner profiles',
    fields: [{ key: 'profileName' }, { key: 'scanType' }],
    profilesPerPage: 10,
    errorMessage: '',
    noProfilesMessage: 'no scanner profiles created yet',
    errorDetails: [],
    hasMoreProfilesToLoad: false,
    isLoading: false,
  };

  const wrapperFactory =
    (mountFn = shallowMount) =>
    (options = {}) => {
      wrapper = mountFn(
        Component,
        merge(
          {
            propsData: defaultProps,
          },
          options,
        ),
      );
    };
  const createFullComponent = wrapperFactory(mount);

  const findProfileList = () => wrapper.findComponent(ProfilesList);

  it('renders profile list properly', () => {
    createFullComponent({
      propsData: { profiles: scannerProfiles },
    });

    expect(findProfileList().exists()).toBe(true);
  });

  it('passes down the props properly', () => {
    createFullComponent();

    expect(findProfileList().props()).toEqual(omit(defaultProps, 'fullPath'));
  });

  it('sets listeners on profile list component', () => {
    const deleteProfileHandler = jest.fn();
    createFullComponent({
      listeners: {
        'delete-profile': deleteProfileHandler,
      },
    });
    findProfileList().vm.$emit('delete-profile');

    expect(deleteProfileHandler).toHaveBeenCalled();
  });
});
