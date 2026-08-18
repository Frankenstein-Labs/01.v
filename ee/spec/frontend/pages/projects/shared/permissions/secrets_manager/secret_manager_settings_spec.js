import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
  SECRET_MANAGER_STATUS_DEPROVISIONING,
  ENTITY_PROJECT,
  ENTITY_GROUP,
} from 'ee/ci/secrets/constants';
import getProjectSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_project_secret_manager_status.query.graphql';
import getEntitlementQuery from 'ee/ci/secrets/graphql/queries/get_secrets_manager_entitlement.graphql';
import getOpenbaoHealthQuery from 'ee/ci/secrets/graphql/queries/get_openbao_health.query.graphql';
import getEnrollmentQuery from 'ee/pages/projects/shared/permissions/secrets_manager/graphql/get_gsm_namespace_enrollment.query.graphql';
import enableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_secret_manager.mutation.graphql';
import disableSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_secret_manager.mutation.graphql';
import getGroupSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_group_secret_manager_status.query.graphql';
import enableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/enable_group_secret_manager.mutation.graphql';
import disableGroupSecretManagerMutation from 'ee/ci/secrets/graphql/mutations/disable_group_secret_manager.mutation.graphql';
import SecretsManagerBillingAlert from 'ee/ci/secrets/components/secrets_manager_billing_alert.vue';
import PermissionsSettings from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_permissions_settings.vue';
import SaasEnrollmentToggle from 'ee/pages/projects/shared/permissions/secrets_manager/components/secrets_manager_saas_enrollment_toggle.vue';
import SecretManagerSettings, {
  POLL_INTERVAL,
} from 'ee/pages/projects/shared/permissions/secrets_manager/secrets_manager_settings.vue';
import {
  entitlementResponse,
  initializeSecretManagerSettingsResponse,
  initializeGroupSecretManagerSettingsResponse,
  deprovisionSecretManagerSettingsResponse,
  deprovisionGroupSecretManagerSettingsResponse,
  enrollmentStatusResponse,
  openbaoHealthResponse,
  secretManagerSettingsResponse,
  groupSecretManagerSettingsResponse,
} from './mock_data';

Vue.use(VueApollo);
const showToast = jest.fn();

describe('SecretManagerSettings', () => {
  let wrapper;
  let mockEnableSecretManager;
  let mockEnableGroupSecretManager;
  let mockDisableSecretManager;
  let mockDisableGroupSecretManager;
  let mockSecretManagerStatus;
  let mockGetEntitlement;
  let mockOpenbaoHealth;
  let mockGetEnrollment;

  const activeResponse = secretManagerSettingsResponse(SECRET_MANAGER_STATUS_ACTIVE);
  const provisioningResponse = secretManagerSettingsResponse(SECRET_MANAGER_STATUS_PROVISIONING);
  const deprovisioningResponse = secretManagerSettingsResponse(
    SECRET_MANAGER_STATUS_DEPROVISIONING,
  );
  const inactiveResponse = secretManagerSettingsResponse(null);
  const secretsManagerStatusErrorResponse = secretManagerSettingsResponse(null, [
    { message: 'Some error occurred' },
  ]);

  const groupActiveResponse = groupSecretManagerSettingsResponse(SECRET_MANAGER_STATUS_ACTIVE);
  const groupProvisioningResponse = groupSecretManagerSettingsResponse(
    SECRET_MANAGER_STATUS_PROVISIONING,
  );
  const groupDeprovisioningResponse = groupSecretManagerSettingsResponse(
    SECRET_MANAGER_STATUS_DEPROVISIONING,
  );
  const groupInactiveResponse = groupSecretManagerSettingsResponse(null);

  const fullPath = 'gitlab-org/gitlab';
  const topLevelGroupFullPath = 'gitlab-org';

  const createComponent = async ({
    context = ENTITY_PROJECT,
    mocks = {},
    secretsManagerPaidExperience = false,
    ...props
  } = {}) => {
    const handlers = [
      [getEntitlementQuery, mockGetEntitlement],
      [getOpenbaoHealthQuery, mockOpenbaoHealth],
      [getProjectSecretManagerStatusQuery, mockSecretManagerStatus],
      [enableSecretManagerMutation, mockEnableSecretManager],
      [disableSecretManagerMutation, mockDisableSecretManager],
      [getGroupSecretManagerStatusQuery, mockSecretManagerStatus],
      [enableGroupSecretManagerMutation, mockEnableGroupSecretManager],
      [disableGroupSecretManagerMutation, mockDisableGroupSecretManager],
      [getEnrollmentQuery, mockGetEnrollment],
    ];

    const defaultProps = {
      canEnrollNamespace: true,
      canManageSecretsManager: true,
      context,
      fullPath,
      isNamespaceEnrollable: false,
      topLevelGroupFullPath,
    };

    wrapper = shallowMountExtended(SecretManagerSettings, {
      apolloProvider: createMockApollo(handlers),
      provide: {
        glFeatures: {
          secretsManagerPaidExperience,
        },
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $toast: { show: showToast },
        ...mocks,
      },
    });

    await waitForPromises();
    await nextTick();
  };

  const findBillingAlert = () => wrapper.findComponent(SecretsManagerBillingAlert);
  const findError = () => wrapper.findByTestId('secret-manager-error');
  const findLearnMoreLink = () => wrapper.findComponent(GlLink);
  const findToggle = () => wrapper.findComponentByTestId('secret-manager-toggle');
  const findToggleDescription = () => wrapper.findByTestId('provisioning-toggle-description');
  const findToggleLabel = () => wrapper.findByTestId('provisioning-toggle-label');
  const findPermissionsSettings = () => wrapper.findComponent(PermissionsSettings);
  const findOpenbaoUnhealthyAlert = () => wrapper.findByTestId('openbao-unhealthy-alert');
  const findOpenBetaBadge = () => wrapper.findByTestId('open-beta-badge');

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findSaasEnrollmentToggle = () => wrapper.findComponent(SaasEnrollmentToggle);

  const advanceToNextFetch = (milliseconds) => {
    jest.advanceTimersByTime(milliseconds);
  };

  const pollNextStatus = async (queryResponse) => {
    mockSecretManagerStatus.mockResolvedValue(queryResponse);
    advanceToNextFetch(POLL_INTERVAL);

    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    mockEnableSecretManager = jest.fn();
    mockEnableGroupSecretManager = jest.fn();
    mockDisableSecretManager = jest.fn();
    mockDisableGroupSecretManager = jest.fn();
    mockSecretManagerStatus = jest.fn();
    mockGetEntitlement = jest.fn().mockResolvedValue(entitlementResponse());
    mockOpenbaoHealth = jest.fn().mockResolvedValue(openbaoHealthResponse());
    mockGetEnrollment = jest.fn().mockResolvedValue(enrollmentStatusResponse());
  });

  describe('template', () => {
    beforeEach(() => {
      mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
    });

    describe('when user does not have permission to manage secrets manager', () => {
      beforeEach(async () => {
        await createComponent({ canManageSecretsManager: false });
      });

      it('disables toggle', () => {
        expect(findToggle().props('disabled')).toBe(true);
      });
    });

    describe('when queries are loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders skeleton loader', () => {
        expect(findSkeletonLoader().exists()).toBe(true);
        expect(findToggle().exists()).toBe(false);
      });
    });

    describe('when queries have loaded', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('hides skeleton loader and renders provisioning toggle', () => {
        expect(findSkeletonLoader().exists()).toBe(false);
        expect(findToggle().exists()).toBe(true);
      });
    });

    describe('when namespace is not enrollable', () => {
      beforeEach(async () => {
        await createComponent({ isNamespaceEnrollable: false });
      });

      it('does not query enrollment', () => {
        expect(mockGetEnrollment).toHaveBeenCalledTimes(0);
      });

      it('does not render SaaS enrollment toggle', () => {
        expect(findSaasEnrollmentToggle().exists()).toBe(false);
      });

      it('renders open beta badge', () => {
        expect(findOpenBetaBadge().exists()).toBe(true);
      });

      it('renders default provisioning toggle label (unindented), description, and learn more link', () => {
        expect(findToggleLabel().text()).toBe('Secrets manager');
        expect(findToggleLabel().classes()).not.toContain('gl-ml-6');
        expect(findToggleDescription().classes()).not.toContain('gl-ml-6');
        expect(findLearnMoreLink().attributes('href')).toBe(
          '/help/ci/secrets/secrets_manager/_index',
        );
      });
    });

    describe('when namespace is enrollable', () => {
      beforeEach(async () => {
        await createComponent({ isNamespaceEnrollable: true });
      });

      it('queries enrollment', () => {
        expect(mockGetEnrollment).toHaveBeenCalledTimes(1);
      });

      it('renders SaaS enrollment toggle', () => {
        expect(findSaasEnrollmentToggle().exists()).toBe(true);
        expect(findSaasEnrollmentToggle().props()).toMatchObject({
          canManageEnrollment: true,
          fullPath: 'gitlab-org/gitlab',
          hasEnrollmentQueryError: false,
          isEnrolled: true,
        });
      });

      // SaaS enrollment toggle goes on top which renders the badge
      it('does not render open beta', () => {
        expect(findOpenBetaBadge().exists()).toBe(false);
      });

      it('indents provisioning toggle, updates label, and removes learn more link', () => {
        expect(findToggleDescription().classes()).toContain('gl-ml-6');
        expect(findToggleLabel().classes()).toContain('gl-ml-6');
        expect(findToggleLabel().text()).toBe('Enable secrets manager for this group');
        expect(findLearnMoreLink().exists()).toBe(false);
      });
    });

    // only applies to top-level group
    // the Rails view hides the setting for child groups and child projects when TLG is not enrolled
    describe('when root namespace is not enrolled', () => {
      beforeEach(() => {
        mockGetEnrollment = jest
          .fn()
          .mockResolvedValue(enrollmentStatusResponse({ enrolled: false }));
      });

      it('skips secrets manager status query', () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(0);
      });

      it('disables provisioning toggle when namespace is enrollable', async () => {
        await createComponent({ isNamespaceEnrollable: true });

        expect(findToggle().props('disabled')).toBe(true);
      });

      it('passes enrollment state to SaaS toggle', async () => {
        await createComponent({ isNamespaceEnrollable: true });

        expect(findSaasEnrollmentToggle().props('isEnrolled')).toBe(false);
      });
    });
  });

  describe('when enrollment query fails for enrollable namespace', () => {
    beforeEach(async () => {
      mockGetEnrollment = jest.fn().mockRejectedValue(new Error('API error'));
      await createComponent({ isNamespaceEnrollable: true });
    });

    it('shows error message and disables provisioning toggle', () => {
      expect(findSaasEnrollmentToggle().props('hasEnrollmentQueryError')).toBe(true);
      expect(findToggle().props('disabled')).toBe(true);
      expect(findError().text()).toBe(
        'An error occurred while fetching the secrets manager enrollment status. Please refresh the page.',
      );
    });
  });

  describe('entitlement query', () => {
    describe('when topLevelGroupFullPath is empty', () => {
      beforeEach(async () => {
        await createComponent({ topLevelGroupFullPath: '' });
      });

      it('skips the entitlement query', () => {
        expect(mockGetEntitlement).not.toHaveBeenCalled();
      });
    });

    describe('when query has loaded', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('passes entitlement to billing alert', () => {
        expect(findBillingAlert().props('entitlement')).toMatchObject({
          state: 'PAID',
          blockedReason: null,
          trialStartedAt: null,
          trialExpiresAt: null,
          creditsRemaining: 50,
          creditsTotal: 500,
          onDemandEnabled: true,
        });
      });
    });

    describe.each([
      { state: 'BLOCKED', blockedReason: 'ON_DEMAND_DISABLED' },
      { state: 'BLOCKED', blockedReason: 'TRIAL_EXPIRED' },
      { state: 'BLOCKED', blockedReason: 'CREDITS_EXHAUSTED' },
      { state: 'BLOCKED', blockedReason: 'GRACE' },
      { state: 'BLOCKED', blockedReason: 'SUBSCRIPTION_GRACE_PERIOD_EXPIRED' },
      { state: 'INELIGIBLE', blockedReason: null },
    ])(
      'when entitlement state is $state with reason $blockedReason',
      ({ state, blockedReason }) => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
          mockGetEntitlement = jest
            .fn()
            .mockResolvedValue(entitlementResponse({ state, blockedReason }));
          await createComponent({
            isNamespaceEnrollable: true,
            secretsManagerPaidExperience: true,
          });
        });

        it('disables the provisioning toggle', () => {
          expect(findToggle().props('disabled')).toBe(true);
        });

        it('disables the SaaS enrollment toggle', () => {
          expect(findSaasEnrollmentToggle().props('disabled')).toBe(true);
        });
      },
    );

    describe.each([
      { state: 'TRIAL', onDemandEnabled: false },
      { state: 'PAID', onDemandEnabled: false },
      { state: 'OFFLINE_PAID', onDemandEnabled: false },
    ])('when entitlement state is $state with on-demand disabled', ({ state, onDemandEnabled }) => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
        mockGetEntitlement = jest
          .fn()
          .mockResolvedValue(entitlementResponse({ state, onDemandEnabled }));
        await createComponent({
          isNamespaceEnrollable: true,
          secretsManagerPaidExperience: true,
        });
      });

      it('keeps the provisioning toggle enabled', () => {
        expect(findToggle().props('disabled')).toBe(false);
      });

      it('keeps the SaaS enrollment toggle enabled', () => {
        expect(findSaasEnrollmentToggle().props('disabled')).toBe(false);
      });
    });
  });

  describe('SaaS enrollment toggle', () => {
    mockGetEnrollment = jest.fn();

    beforeEach(async () => {
      mockGetEnrollment.mockResolvedValueOnce(enrollmentStatusResponse({ enrolled: false }));
      await createComponent({ isNamespaceEnrollable: true });
    });

    it('refetches enrollment and secrets manager status when enrollment toggle is flipped', async () => {
      expect(mockGetEnrollment).toHaveBeenCalledTimes(1);
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(0); // skipped since namespace is unenrolled
      expect(findSaasEnrollmentToggle().props('isEnrolled')).toBe(false);

      mockGetEnrollment.mockResolvedValueOnce(enrollmentStatusResponse());
      findSaasEnrollmentToggle().vm.$emit('toggled');
      await waitForPromises();
      await nextTick();

      expect(mockGetEnrollment).toHaveBeenCalledTimes(2);
      expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
      expect(findSaasEnrollmentToggle().props('isEnrolled')).toBe(true);
    });
  });

  describe('when secrets manager status query receives an error', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(secretsManagerStatusErrorResponse);
      await createComponent();
    });

    it('disables toggle', () => {
      expect(findToggle().props('disabled')).toBe(true);
    });

    it('shows error message', () => {
      expect(findError().text()).toBe('Some error occurred');
    });

    it('does not render permission settings', () => {
      expect(findPermissionsSettings().exists()).toBe(false);
    });
  });

  describe.each([
    {
      context: ENTITY_PROJECT,
      contextActiveResponse: activeResponse,
      contextProvisioningResponse: provisioningResponse,
      contextInactiveResponse: inactiveResponse,
      contextDeprovisioningResponse: deprovisioningResponse,
      mockEnableMutation: () => mockEnableSecretManager,
      mockDisableMutation: () => mockDisableSecretManager,
      enableMutationResponse: initializeSecretManagerSettingsResponse,
      disableMutationResponse: deprovisionSecretManagerSettingsResponse,
      toastMessage: 'Secrets manager has been provisioned for this project.',
      deprovisionedMessage: 'Secrets manager has been deprovisioned for this project.',
    },
    {
      context: ENTITY_GROUP,
      contextActiveResponse: groupActiveResponse,
      contextProvisioningResponse: groupProvisioningResponse,
      contextInactiveResponse: groupInactiveResponse,
      contextDeprovisioningResponse: groupDeprovisioningResponse,
      mockEnableMutation: () => mockEnableGroupSecretManager,
      mockDisableMutation: () => mockDisableGroupSecretManager,
      enableMutationResponse: initializeGroupSecretManagerSettingsResponse,
      disableMutationResponse: deprovisionGroupSecretManagerSettingsResponse,
      toastMessage: 'Secrets manager has been provisioned for this group.',
      deprovisionedMessage: 'Secrets manager has been deprovisioned for this group.',
    },
  ])(
    '$context context',
    ({
      context,
      contextActiveResponse,
      contextProvisioningResponse,
      contextInactiveResponse,
      contextDeprovisioningResponse,
      mockEnableMutation,
      mockDisableMutation,
      enableMutationResponse,
      disableMutationResponse,
      toastMessage,
      deprovisionedMessage,
    }) => {
      const toggleSetting = async (errors = []) => {
        const response = enableMutationResponse(errors);
        mockEnableMutation().mockResolvedValue(response);

        findToggle().vm.$emit('change', true);
        await waitForPromises();
      };

      const toggleDisableSetting = async (errors = []) => {
        const response = disableMutationResponse(errors);
        mockDisableMutation().mockResolvedValue(response);

        findToggle().vm.$emit('change', false);
        await waitForPromises();
      };

      describe('when secrets manager status query receives ACTIVE status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextActiveResponse);
          await createComponent({ context });
        });

        it('shows active state', () => {
          expect(findToggle().props('value')).toBe(true);
        });

        it('renders permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(true);
        });
      });

      describe('when secrets manager status query receives INACTIVE status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextInactiveResponse);
          await createComponent({ context });
        });

        it('shows inactive state', () => {
          expect(findToggle().props('value')).toBe(false);
        });

        it('does not render permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(false);
        });
      });

      describe('when secrets manager status query receives PROVISIONING status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextProvisioningResponse);
          await createComponent({ context });
        });

        it('disables toggle and shows loading state', () => {
          expect(findToggle().props('disabled')).toBe(true);
          expect(findToggle().props('isLoading')).toBe(true);
        });

        it('does not render permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(false);
        });
      });

      describe('when secrets manager status query receives DEPROVISIONING status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextDeprovisioningResponse);
          await createComponent({ context });
        });

        it('disables toggle and shows loading state', () => {
          expect(findToggle().props('disabled')).toBe(true);
          expect(findToggle().props('isLoading')).toBe(true);
        });

        it('does not render permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(false);
        });
      });

      describe('when secrets manager status query receives NULL status', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextInactiveResponse);
          await createComponent({ context });
        });

        it('shows inactive state', () => {
          expect(findToggle().props('disabled')).toBe(false);
          expect(findToggle().props('value')).toBe(false);
        });

        it('does not render permission settings', () => {
          expect(findPermissionsSettings().exists()).toBe(false);
        });
      });

      describe('when enabling the secrets manager', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextInactiveResponse);
          await createComponent({ context });
        });

        it('sends mutation request', async () => {
          await toggleSetting();

          expect(mockEnableMutation()).toHaveBeenCalledWith({
            fullPath,
          });
        });

        it('shows error message on failure and disables toggle', async () => {
          await toggleSetting(['Error encountered']);

          expect(findError().exists()).toBe(true);
          expect(findToggle().props('disabled')).toBe(true);
        });

        it('starts polling for a new status while status is PROVISIONING', async () => {
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

          await toggleSetting();
          await pollNextStatus(contextProvisioningResponse);
          await pollNextStatus(contextProvisioningResponse);
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(3);
        });

        it('stops polling for status when new status is ACTIVE', async () => {
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

          await toggleSetting();
          await pollNextStatus(contextActiveResponse);
          await pollNextStatus(contextActiveResponse);

          expect(findToggle().props('value')).toBe(true);
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
        });

        it('shows toast message on success', async () => {
          await toggleSetting();
          await pollNextStatus(contextActiveResponse);

          expect(showToast).toHaveBeenCalledWith(toastMessage);
        });
      });

      describe('when disabling the secrets manager', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue(contextActiveResponse);
          await createComponent({ context });
          mockDisableMutation().mockClear();
        });

        it('sends mutation request', async () => {
          await toggleDisableSetting();

          expect(mockDisableMutation()).toHaveBeenCalledWith({
            fullPath,
          });
        });

        it('shows error message on failure and disables toggle', async () => {
          await toggleDisableSetting(['Error encountered']);

          expect(findError().exists()).toBe(true);
          expect(findToggle().props('disabled')).toBe(true);
        });

        it('starts polling for a new status while status is DEPROVISIONING', async () => {
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

          await toggleDisableSetting();
          await pollNextStatus(contextDeprovisioningResponse);
          await pollNextStatus(contextDeprovisioningResponse);
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(3);
        });

        it('stops polling for status when new status is INACTIVE', async () => {
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

          await toggleDisableSetting();
          await pollNextStatus(contextDeprovisioningResponse);
          await pollNextStatus(contextInactiveResponse);

          expect(findToggle().props('value')).toBe(false);
          expect(mockSecretManagerStatus).toHaveBeenCalledTimes(3);
        });

        it('shows toast message on success', async () => {
          await toggleDisableSetting();
          await pollNextStatus(contextDeprovisioningResponse);
          await pollNextStatus(contextInactiveResponse);

          expect(showToast).toHaveBeenCalledWith(deprovisionedMessage);
        });
      });
    },
  );

  describe('when OpenBao is unhealthy', () => {
    beforeEach(async () => {
      mockOpenbaoHealth.mockResolvedValue(openbaoHealthResponse(false));
      mockSecretManagerStatus.mockResolvedValue(activeResponse);
      await createComponent();
    });

    it('disables the toggle', () => {
      expect(findToggle().props('disabled')).toBe(true);
    });

    it('shows the unhealthy alert', () => {
      expect(findOpenbaoUnhealthyAlert().exists()).toBe(true);
      expect(findOpenbaoUnhealthyAlert().findComponent(GlAlert).props('variant')).toBe('danger');
    });

    it('hides permissions settings even when active', () => {
      expect(findPermissionsSettings().exists()).toBe(false);
    });
  });

  describe('when OpenBao health query fails', () => {
    beforeEach(async () => {
      mockOpenbaoHealth.mockRejectedValue(new Error('Network error'));
      mockSecretManagerStatus.mockResolvedValue(activeResponse);
      await createComponent();
    });

    it('disables the toggle', () => {
      expect(findToggle().props('disabled')).toBe(true);
    });

    it('shows the unhealthy alert', () => {
      expect(findOpenbaoUnhealthyAlert().exists()).toBe(true);
    });
  });

  describe('when OpenBao is healthy', () => {
    beforeEach(async () => {
      mockSecretManagerStatus.mockResolvedValue(inactiveResponse);
      await createComponent();
    });

    it('does not show the unhealthy alert', () => {
      expect(findOpenbaoUnhealthyAlert().exists()).toBe(false);
    });

    it('does not disable the toggle due to health', () => {
      expect(findToggle().props('disabled')).toBe(false);
    });
  });
});
