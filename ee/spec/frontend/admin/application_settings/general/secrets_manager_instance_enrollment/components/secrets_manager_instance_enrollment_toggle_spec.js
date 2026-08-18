import { GlBadge, GlToggle } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SecretsManagerBillingAlert from 'ee/ci/secrets/components/secrets_manager_billing_alert.vue';
import SecretsManagerInstanceEnrollmentToggle from 'ee/admin/application_settings/general/secrets_manager_instance_enrollment/components/secrets_manager_instance_enrollment_toggle.vue';
import getEntitlementQuery from 'ee/ci/secrets/graphql/queries/get_secrets_manager_entitlement.graphql';
import getInstanceSecretsManagerEnrollmentQuery from 'ee/admin/application_settings/general/secrets_manager_instance_enrollment/graphql/queries/get_instance_secrets_manager_enrollment.query.graphql';
import enrollInstanceSecretsManagerMutation from 'ee/admin/application_settings/general/secrets_manager_instance_enrollment/graphql/mutations/enroll_instance_secrets_manager.mutation.graphql';
import unenrollInstanceSecretsManagerMutation from 'ee/admin/application_settings/general/secrets_manager_instance_enrollment/graphql/mutations/unenroll_instance_secrets_manager.mutation.graphql';
import { entitlementResponse } from 'ee_jest/pages/projects/shared/permissions/secrets_manager/mock_data';

Vue.use(VueApollo);
jest.mock('~/lib/logger');

describe('SecretsManagerInstanceEnrollmentToggle', () => {
  let wrapper;
  let mockEntitlementQuery;
  let mockEnrollmentQuery;
  let mockEnrollMutation;
  let mockUnenrollMutation;
  const mockToastShow = jest.fn();

  const enrollmentResponse = (enrolled) => ({
    data: {
      instanceSecretsManagerEnrollment: {
        __typename: 'SecretsManagerInstanceEnrollment',
        enrolled,
        beta: enrolled,
      },
    },
  });
  const enrollMutationResponse = (errors = []) => ({
    data: { instanceSecretsManagerEnroll: { errors } },
  });
  const unenrollMutationResponse = (errors = []) => ({
    data: { instanceSecretsManagerUnenroll: { errors } },
  });

  const findBetaBadge = () => wrapper.findComponent(GlBadge);
  const findToggle = () => wrapper.findComponent(GlToggle);
  const findBillingAlert = () => wrapper.findComponent(SecretsManagerBillingAlert);
  const findErrorAlert = () => wrapper.findComponentByTestId('enrollment-error-alert');

  const flipToggle = async (value) => {
    findToggle().vm.$emit('change', value);
    await waitForPromises();
  };

  const createComponent = ({
    secretsManagerPaidExperience = false,
    topLevelGroupFullPath = 'some-root-group',
  } = {}) => {
    const apolloProvider = createMockApollo([
      [getEntitlementQuery, mockEntitlementQuery],
      [getInstanceSecretsManagerEnrollmentQuery, mockEnrollmentQuery],
      [enrollInstanceSecretsManagerMutation, mockEnrollMutation],
      [unenrollInstanceSecretsManagerMutation, mockUnenrollMutation],
    ]);

    wrapper = shallowMountExtended(SecretsManagerInstanceEnrollmentToggle, {
      apolloProvider,
      propsData: {
        topLevelGroupFullPath,
      },
      provide: {
        glFeatures: {
          secretsManagerPaidExperience,
        },
      },
      mocks: {
        $toast: { show: mockToastShow },
      },
    });
  };

  beforeEach(() => {
    mockEntitlementQuery = jest.fn().mockResolvedValue(entitlementResponse());
    mockEnrollmentQuery = jest.fn().mockResolvedValue(enrollmentResponse(false));
    mockEnrollMutation = jest.fn().mockResolvedValue(enrollMutationResponse());
    mockUnenrollMutation = jest.fn().mockResolvedValue(unenrollMutationResponse());
    mockToastShow.mockClear();
  });

  describe('on mount', () => {
    it('queries the enrollment state', async () => {
      createComponent();
      await waitForPromises();

      expect(mockEnrollmentQuery).toHaveBeenCalledTimes(1);
      expect(findToggle().props('value')).toBe(false);
    });

    it('reflects an enrolled state', async () => {
      mockEnrollmentQuery.mockResolvedValueOnce(enrollmentResponse(true));
      createComponent();
      await waitForPromises();

      expect(findToggle().props('value')).toBe(true);
    });

    it('does not render the error alert initially', async () => {
      createComponent();
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(false);
    });

    it('renders an inline error when the query fails', async () => {
      mockEnrollmentQuery.mockRejectedValueOnce(new Error('boom'));
      createComponent();
      await waitForPromises();

      expect(findErrorAlert().exists()).toBe(true);
      expect(findErrorAlert().text()).not.toBe('');
    });
  });

  describe('toggling on', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('calls the enroll mutation and reflects the new state', async () => {
      await flipToggle(true);

      expect(mockEnrollMutation).toHaveBeenCalledTimes(1);
      expect(mockUnenrollMutation).not.toHaveBeenCalled();
      expect(findToggle().props('value')).toBe(true);
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('disables the toggle while the mutation is in flight', async () => {
      expect(findToggle().props('disabled')).toBe(false);
      expect(findToggle().props('isLoading')).toBe(false);

      flipToggle(true);
      await nextTick();

      expect(findToggle().props('disabled')).toBe(true);
      expect(findToggle().props('isLoading')).toBe(true);
    });

    it('re-enables the toggle after the mutation resolves', async () => {
      await flipToggle(true);

      expect(findToggle().props('disabled')).toBe(false);
      expect(findToggle().props('isLoading')).toBe(false);
    });

    it('shows the enroll-specific success toast', async () => {
      await flipToggle(true);

      expect(mockToastShow).toHaveBeenCalledTimes(1);
      expect(mockToastShow).toHaveBeenCalledWith('Secrets Manager is enabled.');
    });

    it('renders an inline error when the mutation returns errors', async () => {
      mockEnrollMutation.mockResolvedValueOnce(enrollMutationResponse(['nope']));

      await flipToggle(true);

      expect(findErrorAlert().exists()).toBe(true);
      expect(findToggle().props('value')).toBe(false);
      expect(mockToastShow).not.toHaveBeenCalled();
    });

    it('renders an inline error when the mutation throws', async () => {
      mockEnrollMutation.mockRejectedValueOnce(new Error('boom'));

      await flipToggle(true);

      expect(findErrorAlert().exists()).toBe(true);
      expect(findToggle().props('value')).toBe(false);
      expect(mockToastShow).not.toHaveBeenCalled();
    });

    it('clears a previous error before the next mutation attempt', async () => {
      mockEnrollMutation.mockRejectedValueOnce(new Error('boom'));
      await flipToggle(true);
      expect(findErrorAlert().exists()).toBe(true);

      mockEnrollMutation.mockResolvedValueOnce(enrollMutationResponse());
      await flipToggle(true);

      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('toggling off', () => {
    beforeEach(async () => {
      mockEnrollmentQuery.mockResolvedValueOnce(enrollmentResponse(true));
      createComponent();
      await waitForPromises();
    });

    it('calls the unenroll mutation and reflects the new state', async () => {
      await flipToggle(false);

      expect(mockUnenrollMutation).toHaveBeenCalledTimes(1);
      expect(mockEnrollMutation).not.toHaveBeenCalled();
      expect(findToggle().props('value')).toBe(false);
      expect(findErrorAlert().exists()).toBe(false);
    });

    it('shows the unenroll-specific success toast', async () => {
      await flipToggle(false);

      expect(mockToastShow).toHaveBeenCalledTimes(1);
      expect(mockToastShow).toHaveBeenCalledWith('Secrets Manager is disabled.');
    });

    it('renders an inline error when the mutation returns errors', async () => {
      mockUnenrollMutation.mockResolvedValueOnce(unenrollMutationResponse(['nope']));

      await flipToggle(false);

      expect(findErrorAlert().exists()).toBe(true);
      expect(findToggle().props('value')).toBe(true);
    });
  });

  describe('dismissing the error alert', () => {
    beforeEach(async () => {
      mockEnrollMutation.mockRejectedValueOnce(new Error('boom'));
      createComponent();
      await waitForPromises();
      await flipToggle(true);
    });

    it('hides the alert when dismissed', async () => {
      expect(findErrorAlert().exists()).toBe(true);

      findErrorAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('entitlement query', () => {
    describe('when topLevelGroupFullPath is empty', () => {
      beforeEach(async () => {
        await createComponent({ topLevelGroupFullPath: '' });
      });

      it('skips the entitlement query', () => {
        expect(mockEntitlementQuery).not.toHaveBeenCalled();
      });
    });

    describe('when query has loaded', () => {
      it('passes entitlement to billing alert', async () => {
        createComponent();
        await waitForPromises();

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

      it('enables toggle when on-demand is enabled', async () => {
        createComponent();
        await waitForPromises();

        expect(findToggle().props('disabled')).toBe(false);
      });

      it.each([
        { state: 'BLOCKED', blockedReason: 'ON_DEMAND_DISABLED' },
        { state: 'BLOCKED', blockedReason: 'TRIAL_EXPIRED' },
        { state: 'BLOCKED', blockedReason: 'CREDITS_EXHAUSTED' },
        { state: 'BLOCKED', blockedReason: 'GRACE' },
        { state: 'BLOCKED', blockedReason: 'SUBSCRIPTION_GRACE_PERIOD_EXPIRED' },
        { state: 'INELIGIBLE', blockedReason: null },
      ])(
        'disables toggle when entitlement state is $state with reason $blockedReason',
        async ({ state, blockedReason }) => {
          mockEntitlementQuery = jest
            .fn()
            .mockResolvedValue(entitlementResponse({ state, blockedReason }));
          createComponent({ secretsManagerPaidExperience: true });
          await waitForPromises();

          expect(findToggle().props('disabled')).toBe(true);
        },
      );

      it.each([{ state: 'TRIAL' }, { state: 'PAID' }, { state: 'OFFLINE_PAID' }])(
        'keeps toggle enabled for $state state when on-demand is disabled',
        async ({ state }) => {
          mockEntitlementQuery = jest
            .fn()
            .mockResolvedValue(entitlementResponse({ state, onDemandEnabled: false }));
          createComponent({ secretsManagerPaidExperience: true });
          await waitForPromises();

          expect(findToggle().props('disabled')).toBe(false);
        },
      );
    });
  });

  describe('when secretsManagerPaidExperience feature flag is disabled', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the beta badge', () => {
      expect(findBetaBadge().exists()).toBe(true);
    });
  });

  describe('when secretsManagerPaidExperience feature flag is enabled', () => {
    beforeEach(async () => {
      createComponent({ secretsManagerPaidExperience: true });
      await waitForPromises();
    });

    it('does not render the beta badge', () => {
      expect(findBetaBadge().exists()).toBe(false);
    });
  });
});
