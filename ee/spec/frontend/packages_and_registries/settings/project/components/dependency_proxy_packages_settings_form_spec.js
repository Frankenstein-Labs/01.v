import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlButton, GlFormCheckbox } from '@gitlab/ui';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependencyProxyPackagesSettingsForm from 'ee_component/packages_and_registries/settings/project/components/dependency_proxy_packages_settings_form.vue';
import updateDependencyProxyPackagesSettings from 'ee_component/packages_and_registries/settings/project/graphql/mutations/update_dependency_proxy_packages_settings.mutation.graphql';
import MavenForm from 'ee_component/packages_and_registries/settings/project/components/maven_form.vue';
import {
  dependencyProxyPackagesSettingsData,
  dependencyProxyPackagesSettingMutationMock,
  mutationErrorMock,
} from '../mock_data';

Vue.use(VueApollo);

describe('Dependency proxy packages settings form', () => {
  let wrapper;
  let apolloProvider;
  let updateSettingsMutationResolver;
  let show;

  const defaultProps = {
    data: { ...dependencyProxyPackagesSettingsData },
  };

  const { enabled, mavenExternalRegistryUrl, mavenExternalRegistryUsername } =
    dependencyProxyPackagesSettingsData;

  const defaultProvidedValues = {
    projectPath: 'path',
  };

  const trackingPayload = {
    label: 'dependendency_proxy_packages_settings',
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEnableProxyCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findForm = () => wrapper.find('form');
  const findMavenForm = () => wrapper.findComponent(MavenForm);
  const findSubmitButton = () => wrapper.findComponent(GlButton);

  const mountComponent = ({ props = defaultProps } = {}) => {
    wrapper = shallowMountExtended(DependencyProxyPackagesSettingsForm, {
      provide: defaultProvidedValues,
      propsData: { ...props },
      apolloProvider,
      mocks: {
        $toast: {
          show,
        },
      },
    });
  };

  const mountComponentWithApollo = ({ props = defaultProps } = {}) => {
    const requestHandlers = [
      [updateDependencyProxyPackagesSettings, updateSettingsMutationResolver],
    ];

    apolloProvider = createMockApollo(requestHandlers);
    mountComponent({
      propsData: {
        ...props,
      },
    });
  };

  describe('form', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('renders the fields', () => {
      expect(findEnableProxyCheckbox().attributes('checked')).toBe(String(enabled));
      expect(findEnableProxyCheckbox().text()).toBe('Enable Dependency Proxy');
      expect(findMavenForm().props('value')).toStrictEqual({
        mavenExternalRegistryUrl,
        mavenExternalRegistryUsername,
        mavenExternalRegistryPassword: null,
      });
    });

    it('renders submit button', () => {
      expect(findSubmitButton().text()).toBe('Save changes');
      expect(findSubmitButton().attributes('disabled')).toBeUndefined();
      expect(findSubmitButton().props('loading')).toBe(false);
    });

    it('does not show an alert', () => {
      expect(findAlert().exists()).toBe(false);
    });

    describe('when proxy toggle', () => {
      it('is disabled', () => {
        mountComponent({
          props: {
            data: {
              ...defaultProps.data,
              enabled: false,
            },
          },
        });

        expect(findEnableProxyCheckbox().attributes('checked')).not.toBeDefined();
      });
    });
  });

  describe('mutation', () => {
    beforeEach(() => {
      updateSettingsMutationResolver = jest
        .fn()
        .mockResolvedValue(dependencyProxyPackagesSettingMutationMock());
      show = jest.fn();
    });

    describe('tracking', () => {
      let trackingSpy;

      beforeEach(() => {
        trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
      });

      afterEach(() => {
        unmockTracking();
      });

      it('tracks the submit event', () => {
        mountComponentWithApollo();

        findForm().trigger('submit');

        expect(trackingSpy).toHaveBeenCalledWith(
          undefined,
          'submit_dependency_proxy_packages_settings',
          trackingPayload,
        );
      });
    });

    it('sets submit button loading & disabled prop', async () => {
      mountComponentWithApollo();

      findForm().trigger('submit');

      await nextTick();

      expect(findSubmitButton().props()).toMatchObject({
        loading: true,
        disabled: true,
      });
    });

    it('is called with the right arguments', () => {
      mountComponentWithApollo();

      apolloProvider.defaultClient.mutate = jest
        .fn()
        .mockResolvedValue(dependencyProxyPackagesSettingMutationMock());

      findMavenForm().vm.$emit('input', {
        mavenExternalRegistryUrl,
        mavenExternalRegistryUsername,
        mavenExternalRegistryPassword: 'password',
      });

      findForm().trigger('submit');

      expect(apolloProvider.defaultClient.mutate).toHaveBeenCalledWith(
        expect.objectContaining({
          mutation: updateDependencyProxyPackagesSettings,
          variables: {
            input: {
              projectPath: defaultProvidedValues.projectPath,
              enabled,
              mavenExternalRegistryUrl,
              mavenExternalRegistryUsername,
              mavenExternalRegistryPassword: 'password',
            },
          },
        }),
      );
    });

    describe('success state', () => {
      it('shows a toast with success message', async () => {
        mountComponentWithApollo();

        findForm().trigger('submit');

        await waitForPromises();

        expect(show).toHaveBeenCalledWith('Settings saved successfully.');
        expect(findSubmitButton().props()).toMatchObject({
          loading: false,
          disabled: false,
        });
      });

      it('password field is reset', async () => {
        mountComponentWithApollo();

        findMavenForm().vm.$emit('input', {
          mavenExternalRegistryUrl,
          mavenExternalRegistryUsername,
          mavenExternalRegistryPassword: 'password',
        });

        findForm().trigger('submit');

        await waitForPromises();

        expect(findMavenForm().props('value')).toMatchObject({
          mavenExternalRegistryPassword: null,
        });
      });
    });

    describe('errors', () => {
      it('shows alert with message', async () => {
        updateSettingsMutationResolver = jest.fn().mockResolvedValue(mutationErrorMock);

        mountComponentWithApollo();

        findForm().trigger('submit');

        await waitForPromises();

        expect(findAlert().text()).toBe('Error: Some error');
        expect(findAlert().props('variant')).toBe('danger');
        expect(findAlert().props('dismissible')).toBe(true);
        expect(show).not.toHaveBeenCalled();

        expect(findSubmitButton().props()).toMatchObject({
          loading: false,
          disabled: false,
        });
      });

      it('does not reset the password field', async () => {
        updateSettingsMutationResolver = jest.fn().mockResolvedValue(mutationErrorMock);
        mountComponentWithApollo();

        findMavenForm().vm.$emit('input', {
          mavenExternalRegistryUrl,
          mavenExternalRegistryUsername,
          mavenExternalRegistryPassword: 'password',
        });
        findForm().trigger('submit');

        await waitForPromises();

        expect(findMavenForm().props('value')).toMatchObject({
          mavenExternalRegistryPassword: 'password',
        });
      });

      it('mutation payload with network error', async () => {
        updateSettingsMutationResolver = jest.fn().mockRejectedValue();
        mountComponentWithApollo();

        findForm().trigger('submit');

        await waitForPromises();

        expect(findAlert().text()).toBe('Error');
        expect(findAlert().props('variant')).toBe('danger');
        expect(show).not.toHaveBeenCalled();
      });
    });
  });
});
