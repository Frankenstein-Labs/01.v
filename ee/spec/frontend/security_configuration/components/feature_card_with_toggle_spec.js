import { GlAlert, GlCard, GlIcon, GlLink, GlLoadingIcon, GlPopover, GlToggle } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import SetCvsForContainerScanningMutation from 'ee/security_configuration/graphql/set_cvs_for_container_scanning.mutation.graphql';
import FeatureCardWithToggle from 'ee/security_configuration/components/feature_card_with_toggle.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const defaultProvide = {
  projectFullPath: 'group/project',
};

const defaultI18n = {
  name: 'Continuous Vulnerability Scanning for Container Scanning',
  description: 'Automatically detects new container vulnerabilities based on SBOM data.',
  toastMessageEnabled: 'Continuous Vulnerability Scanning for Container Scanning is enabled',
  toastMessageDisabled: 'Continuous Vulnerability Scanning for Container Scanning is disabled',
};

const defaultFeature = {
  type: 'cvs_for_container_scanning',
  name: 'Continuous Vulnerability Scanning for Container Scanning',
  description: 'Automatically detects new container vulnerabilities based on SBOM data.',
  helpPath: '/help/user/application_security/continuous_vulnerability_scanning/_index.md',
  canUserConfigure: true,
};

const mockMutationResponse = (enabled = true, errors = []) => ({
  data: {
    setCvsForContainerScanning: {
      cvsForContainerScanningEnabled: enabled,
      errors,
    },
  },
});

describe('FeatureCardWithToggle', () => {
  let wrapper;
  let mutationHandler;

  const createComponent = ({
    initialValue = true,
    provide = {},
    feature = defaultFeature,
    mutationHandlerImpl,
    toastShow = jest.fn(),
  } = {}) => {
    mutationHandler = mutationHandlerImpl || jest.fn().mockResolvedValue(mockMutationResponse());

    wrapper = shallowMountExtended(FeatureCardWithToggle, {
      provide: { ...defaultProvide, ...provide },
      propsData: {
        feature,
        mutation: SetCvsForContainerScanningMutation,
        initialValue,
        mutationResponseKey: 'setCvsForContainerScanning',
        enabledKey: 'cvsForContainerScanningEnabled',
        toggleTestId: 'cvs-container-scanning-toggle',
        i18n: defaultI18n,
      },
      apolloProvider: createMockApollo([[SetCvsForContainerScanningMutation, mutationHandler]]),
      mocks: { $toast: { show: toastShow } },
      stubs: { GlCard },
    });
  };

  const findToggle = () => wrapper.findComponent(GlToggle);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findFeatureStatus = () => wrapper.findByTestId('feature-status');
  const findLockIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findHelpLink = () => wrapper.findComponent(GlLink);

  describe('rendering', () => {
    it('shows feature name and description', () => {
      createComponent();

      expect(wrapper.text()).toContain(defaultFeature.name);
      expect(wrapper.text()).toContain('Automatically detects new container vulnerabilities');
    });

    describe('status indicator', () => {
      it('shows enabled status when toggle is on', () => {
        createComponent({ initialValue: true });

        expect(findFeatureStatus().text()).toContain('Enabled');
      });

      it('shows not enabled status when toggle is off', () => {
        createComponent({ initialValue: false });

        expect(findFeatureStatus().text()).toContain('Not enabled');
      });
    });

    describe('help link', () => {
      it('renders a Learn more link when helpPath is present', () => {
        createComponent();

        expect(findHelpLink().attributes('href')).toBe(defaultFeature.helpPath);
        expect(findHelpLink().attributes('target')).toBe('_blank');
        expect(findHelpLink().text()).toContain('Learn more');
      });

      it('does not render a Learn more link when helpPath is missing', () => {
        createComponent({ feature: { ...defaultFeature, helpPath: undefined } });

        expect(findHelpLink().exists()).toBe(false);
      });
    });
  });

  describe('permissions', () => {
    describe('when user can configure the feature', () => {
      beforeEach(() => {
        createComponent({ initialValue: false });
      });

      it('enables the toggle', () => {
        expect(findToggle().props('disabled')).toBe(false);
      });

      it('does not render the lock icon', () => {
        expect(findLockIcon().exists()).toBe(false);
      });

      it('does not render the popover', () => {
        expect(findPopover().exists()).toBe(false);
      });
    });

    describe('when user cannot configure the feature', () => {
      beforeEach(() => {
        createComponent({
          initialValue: false,
          feature: { ...defaultFeature, canUserConfigure: false },
        });
      });

      it('disables the toggle', () => {
        expect(findToggle().props('disabled')).toBe(true);
      });

      it('renders the lock icon with a unique id derived from feature type', () => {
        expect(findLockIcon().props('name')).toBe('lock');
        expect(findLockIcon().attributes('id')).toBe(`${defaultFeature.type}-lock-icon`);
      });

      it('renders the popover targeting the lock icon', () => {
        expect(findPopover().props('target')).toBe(`${defaultFeature.type}-lock-icon`);
        expect(findPopover().text()).toContain(
          'Only security managers, maintainers, and owners can toggle this feature.',
        );
      });
    });
  });

  describe('toggling the feature', () => {
    it('renders toggle with correct initial value', () => {
      createComponent({ initialValue: false });

      expect(findToggle().props('value')).toBe(false);
    });

    it('calls the mutation with correct variables', async () => {
      createComponent();

      findToggle().vm.$emit('change', false);
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        input: { projectPath: defaultProvide.projectFullPath, enable: false },
      });
    });

    it('disables toggle and shows loading icon while mutation is running', async () => {
      createComponent();

      findToggle().vm.$emit('change', false);
      await nextTick();

      expect(findToggle().props('disabled')).toBe(true);
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('re-enables toggle and hides loading icon after mutation completes', async () => {
      createComponent();

      findToggle().vm.$emit('change', false);
      await waitForPromises();

      expect(findToggle().props('disabled')).toBe(false);
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('updates toggle value and shows toast on success', async () => {
      const toastShow = jest.fn();
      createComponent({
        mutationHandlerImpl: jest.fn().mockResolvedValue(mockMutationResponse(false)),
        toastShow,
      });

      findToggle().vm.$emit('change', false);
      await waitForPromises();

      expect(findToggle().props('value')).toBe(false);
      expect(toastShow).toHaveBeenCalledWith(defaultI18n.toastMessageDisabled);
    });
  });

  describe('error handling', () => {
    it('does not show an error alert by default', () => {
      createComponent();

      expect(findAlert().exists()).toBe(false);
    });

    it('reverts toggle to previous value and shows error alert on GraphQL error', async () => {
      createComponent({
        mutationHandlerImpl: jest
          .fn()
          .mockResolvedValue(mockMutationResponse(true, ['Something went wrong'])),
      });

      findToggle().vm.$emit('change', false);
      await waitForPromises();

      expect(findToggle().props('value')).toBe(true);
      expect(findAlert().text()).toContain('Something went wrong');
    });

    it('reverts toggle and shows error alert on network error', async () => {
      createComponent({
        mutationHandlerImpl: jest.fn().mockRejectedValue(new Error('Network error')),
      });

      findToggle().vm.$emit('change', false);
      await waitForPromises();

      expect(findToggle().props('value')).toBe(true);
      expect(findAlert().exists()).toBe(true);
    });

    it('dismisses error alert when dismissed', async () => {
      createComponent({
        mutationHandlerImpl: jest
          .fn()
          .mockResolvedValue(mockMutationResponse(true, ['Something went wrong'])),
      });

      findToggle().vm.$emit('change', false);
      await waitForPromises();

      expect(findAlert().exists()).toBe(true);

      await findAlert().vm.$emit('dismiss');

      expect(findAlert().exists()).toBe(false);
    });
  });
});
