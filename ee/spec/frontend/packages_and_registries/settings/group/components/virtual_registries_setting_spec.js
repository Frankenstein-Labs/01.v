import { GlSprintf, GlLink } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import VirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/components/virtual_registries_setting.vue';
import CleanupPolicyDetails from 'ee_component/packages_and_registries/settings/group/components/cleanup_policy_details.vue';

import getGroupVirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/graphql/queries/get_group_virtual_registries_setting.query.graphql';
import updateVirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/graphql/mutations/update_virtual_registries_setting.mutation.graphql';
import SettingsSection from '~/vue_shared/components/settings/settings_section.vue';
import { updateVirtualRegistriesSettingOptimisticResponse } from 'ee_component/packages_and_registries/settings/group/graphql/utils/optimistic_responses';

import {
  groupVirtualRegistriesSettingMock,
  mutationErrorMock,
  virtualRegistriesSettingMutationMock,
} from '../mock_data';

jest.mock('~/alert');
jest.mock('ee_component/packages_and_registries/settings/group/graphql/utils/optimistic_responses');

describe('VirtualRegistriesSetting', () => {
  let wrapper;
  let apolloProvider;
  let queryResolver;
  let updateSettingsMutationResolver;

  const defaultProvide = {
    groupPath: 'testGroupPath',
  };

  Vue.use(VueApollo);

  const mountComponent = ({ provide = defaultProvide } = {}) => {
    const requestHandlers = [
      [getGroupVirtualRegistriesSetting, queryResolver],
      [updateVirtualRegistriesSetting, updateSettingsMutationResolver],
    ];

    apolloProvider = createMockApollo(requestHandlers);

    wrapper = shallowMountExtended(VirtualRegistriesSetting, {
      apolloProvider,
      provide,
      stubs: {
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    queryResolver = jest.fn().mockResolvedValue(groupVirtualRegistriesSettingMock);
    updateSettingsMutationResolver = jest
      .fn()
      .mockResolvedValue(virtualRegistriesSettingMutationMock());
  });

  const findSettingsSection = () => wrapper.findComponent(SettingsSection);
  const findEnableVirtualRegistriesSettingToggle = () =>
    wrapper.findComponentByTestId('virtual-registries-setting-toggle');
  const findTestingAgreementLink = () => wrapper.findComponent(GlLink);
  const findCleanupPolicyDetails = () => wrapper.findComponent(CleanupPolicyDetails);

  const fillApolloCache = () => {
    apolloProvider.defaultClient.cache.writeQuery({
      query: getGroupVirtualRegistriesSetting,
      variables: {
        fullPath: defaultProvide.groupPath,
      },
      ...groupVirtualRegistriesSettingMock,
    });
  };

  it('renders a settings section', () => {
    mountComponent();

    expect(findSettingsSection().exists()).toBe(true);
  });

  it('has the correct header text and description', () => {
    mountComponent();

    expect(findSettingsSection().props('heading')).toContain('Virtual registry');
    expect(findSettingsSection().props('description')).toContain(
      'Manage packages across multiple sources and streamline development workflows using virtual registries.',
    );
  });

  describe('toggle', () => {
    beforeEach(async () => {
      mountComponent();
      await waitForPromises();
    });

    it('exists', () => {
      expect(findEnableVirtualRegistriesSettingToggle().exists()).toBe(true);
    });

    it('has enabled virtual registry help text with testing agreement link', () => {
      expect(findEnableVirtualRegistriesSettingToggle().text()).toContain(
        'When you enable this feature, you accept the GitLab Testing Agreement.',
      );
      expect(findTestingAgreementLink().attributes('href')).toBe(
        'https://handbook.gitlab.com/handbook/legal/testing-agreement/',
      );
    });

    it('has disabled virtual registry help text', () => {
      expect(findEnableVirtualRegistriesSettingToggle().text()).toContain(
        'Disabling removes access. Existing registries are preserved and available again when re-enabled.',
      );
    });
  });

  describe.each`
    toggleName                   | toggleFinder                                | localErrorMock                          | optimisticResponse
    ${'enable virtual registry'} | ${findEnableVirtualRegistriesSettingToggle} | ${virtualRegistriesSettingMutationMock} | ${updateVirtualRegistriesSettingOptimisticResponse}
  `('$toggleName settings update', ({ optimisticResponse, toggleFinder, localErrorMock }) => {
    describe('success state', () => {
      it('emits a success event', async () => {
        mountComponent();

        fillApolloCache();
        toggleFinder().vm.$emit('change', false);

        await waitForPromises();

        expect(wrapper.emitted('success')).toEqual([[]]);
      });

      it('calls mutation with correct variables including fullPath', async () => {
        mountComponent();

        fillApolloCache();
        toggleFinder().vm.$emit('change', false);

        await waitForPromises();

        expect(updateSettingsMutationResolver).toHaveBeenCalledWith({
          input: {
            fullPath: 'testGroupPath',
            enabled: false,
          },
        });
      });

      it('has an optimistic response', async () => {
        mountComponent();
        await waitForPromises();

        fillApolloCache();

        expect(toggleFinder().props('value')).toBe(true);

        toggleFinder().vm.$emit('change', false);

        expect(optimisticResponse).toHaveBeenCalledWith(
          expect.objectContaining({
            enabled: false,
          }),
        );
      });
    });

    describe('errors', () => {
      it('mutation payload with root level errors', async () => {
        updateSettingsMutationResolver = jest.fn().mockResolvedValue(mutationErrorMock);

        mountComponent();

        fillApolloCache();

        toggleFinder().vm.$emit('change', false);

        await waitForPromises();

        expect(wrapper.emitted('error')).toEqual([[]]);
      });

      it.each`
        type         | mutationResolverMock
        ${'local'}   | ${jest.fn().mockResolvedValue(localErrorMock({ errors: ['foo'] }))}
        ${'network'} | ${jest.fn().mockRejectedValue()}
      `('mutation payload with $type error', async ({ mutationResolverMock }) => {
        updateSettingsMutationResolver = mutationResolverMock;
        mountComponent();

        fillApolloCache();
        toggleFinder().vm.$emit('change', false);

        await waitForPromises();

        expect(wrapper.emitted('error')).toEqual([[]]);
      });
    });
  });

  describe('when isLoading is true', () => {
    it('disables virtual registry toggle', () => {
      mountComponent({ isLoading: true });

      expect(findEnableVirtualRegistriesSettingToggle().props('disabled')).toBe(true);
    });
  });

  describe('cleanup policy details', () => {
    beforeEach(async () => {
      mountComponent();
      await waitForPromises();
    });

    it('renders cleanup policy details component', () => {
      expect(findCleanupPolicyDetails().exists()).toBe(true);
    });

    it('passes virtualRegistriesSettingEnabled as true when virtual registry is enabled', async () => {
      fillApolloCache();
      await waitForPromises();

      expect(findCleanupPolicyDetails().props('virtualRegistriesSettingEnabled')).toBe(true);
    });

    it('passes virtualRegistriesSettingEnabled as false when virtual registry is disabled', async () => {
      queryResolver = jest.fn().mockResolvedValue({
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            __typename: 'Group',
            virtualRegistriesSetting: {
              __typename: 'VirtualRegistriesSetting',
              enabled: false,
            },
          },
        },
      });

      mountComponent();
      await waitForPromises();

      expect(findCleanupPolicyDetails().props('virtualRegistriesSettingEnabled')).toBe(false);
    });
  });
});
