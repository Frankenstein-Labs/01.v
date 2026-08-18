import { GlLink, GlSprintf } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import Vue, { nextTick } from 'vue';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { SkipReason, itSkipVue3 } from 'helpers/vue3_conditional';
import waitForPromises from 'helpers/wait_for_promises';
import createRouter from 'ee/ci/secrets/router';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import SecretsApp from 'ee/ci/secrets/components/secrets_app.vue';
import SecretsEmptyState from 'ee/ci/secrets/components/secrets_empty_state.vue';
import SecretsTrialEmptyState from 'ee/ci/secrets/components/secrets_table/secrets_trial_empty_state.vue';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from 'ee/ci/secrets/context_config';
import enrollNamespaceMutation from 'ee/ci/secrets/graphql/mutations/enroll_namespace_secrets_manager.mutation.graphql';
import getOpenbaoHealthQuery from 'ee/ci/secrets/graphql/queries/get_openbao_health.query.graphql';
import getEntitlementQuery from 'ee/ci/secrets/graphql/queries/get_secrets_manager_entitlement.graphql';
import startTrialMutation from 'ee/ci/secrets/graphql/mutations/start_secrets_manager_trial.mutation.graphql';
import {
  BLOCKED_REASON_CREDITS_EXHAUSTED,
  BLOCKED_REASON_GRACE,
  BLOCKED_REASON_ON_DEMAND_DISABLED,
  BLOCKED_REASON_SUBSCRIPTION_CANCELLED,
  BLOCKED_REASON_TRIAL_EXPIRED,
  POLL_INTERVAL,
  ENTITY_GROUP,
  ENTITY_PROJECT,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import {
  enableSecretManagerResponse,
  enrollNamespaceAlreadyEnrolledResponse,
  enrollNamespaceErrorResponse,
  enrollNamespaceSuccessResponse,
  entitlementResponse,
  openbaoHealthResponse,
  secretManagerStatusResponse,
  startTrialSuccessResponse,
  startTrialErrorResponse,
} from '../mock_data';

jest.mock('~/alert');

describe('SecretsApp', () => {
  let wrapper;
  let apolloProvider;
  let mockSecretManagerStatus;
  let mockOpenbaoHealth;
  let mockEntitlementQuery;
  let mockEnableSecretsManager;
  let mockEnrollNamespace;
  let mockStartTrial;

  Vue.use(VueRouter);
  Vue.use(VueApollo);
  const mockToastShow = jest.fn();

  const findRouterView = () => wrapper.findComponent({ ref: 'router-view' });

  const managePermissionsPath = '/path/to/edit#js-shared-permissions';

  const defaultProvide = {
    fullPath: '/path/to/entity',
    managePermissionsPath,
    topLevelGroupFullPath: '',
    isSaas: false,
  };

  const createRouterForTest = () => createRouter('/-/secrets');

  const createComponent = async ({
    stubs,
    router,
    provide,
    isLoading = false,
    context = ENTITY_PROJECT,
  } = {}) => {
    const contextConfig = SECRETS_MANAGER_CONTEXT_CONFIG[context];
    const handlers = [
      [contextConfig.getStatus.query, mockSecretManagerStatus],
      [getOpenbaoHealthQuery, mockOpenbaoHealth],
      [getEntitlementQuery, mockEntitlementQuery],
      [contextConfig.enableSecretsManager.mutation, mockEnableSecretsManager],
      [enrollNamespaceMutation, mockEnrollNamespace],
      [startTrialMutation, mockStartTrial],
      [
        contextConfig.getSecrets.query,
        jest.fn().mockResolvedValue({ data: { secretsList: { edges: [] } } }),
      ],
      [
        contextConfig.getSecretsNeedingRotation.query,
        jest.fn().mockResolvedValue({ data: { secretsNeedingRotation: { nodes: [] } } }),
      ],
    ];

    apolloProvider = createMockApollo(handlers);

    wrapper = mountExtended(SecretsApp, {
      router: router || createRouterForTest(),
      provide: {
        contextConfig,
        ...defaultProvide,
        ...provide,
      },
      stubs,
      apolloProvider,
      mocks: {
        $toast: { show: mockToastShow },
      },
    });

    if (!isLoading) {
      await waitForPromises();
      await nextTick();
    }
  };

  const createPaidExperienceComponent = async (provide = {}) => {
    await createComponent({
      provide: {
        glFeatures: {
          secretsManagerPaidExperience: true,
        },
        topLevelGroupFullPath: 'top-level-group',
        ...provide,
      },
      stubs: {
        GlSprintf,
        'router-view': true,
      },
    });
  };

  const findEmptyState = () => wrapper.findComponent(SecretsEmptyState);
  const findTrialEmptyState = () => wrapper.findComponent(SecretsTrialEmptyState);
  const findEmptyStateNewSecretBtn = () =>
    wrapper.findComponentByTestId('empty-state-new-secret-button');
  const findLoadingIcon = () => wrapper.findByTestId('secrets-manager-loading-status');
  const findTrialAlert = () => wrapper.findComponentByTestId('secrets-trial-alert');
  const findTrialAlertLink = () => findTrialAlert().findComponent(GlLink);

  const advanceToNextFetch = (milliseconds) => {
    jest.advanceTimersByTime(milliseconds);
  };

  const pollNextStatus = async (status, context = 'project') => {
    mockSecretManagerStatus.mockResolvedValue(secretManagerStatusResponse(status, context));
    advanceToNextFetch(POLL_INTERVAL);

    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    mockSecretManagerStatus = jest.fn();
    mockOpenbaoHealth = jest.fn();
    mockEntitlementQuery = jest.fn().mockResolvedValue(entitlementResponse({ state: 'TRIAL' }));
    mockEnableSecretsManager = jest.fn();
    mockEnrollNamespace = jest.fn().mockResolvedValue(enrollNamespaceSuccessResponse());
    mockStartTrial = jest.fn().mockResolvedValue(startTrialSuccessResponse());

    mockSecretManagerStatus.mockResolvedValue(
      secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE),
    );
    mockOpenbaoHealth.mockResolvedValue(openbaoHealthResponse(true));
  });

  describe.each`
    context
    ${ENTITY_PROJECT}
    ${ENTITY_GROUP}
  `('SecretsApp in $context context', ({ context }) => {
    beforeEach(() => {
      mockSecretManagerStatus.mockClear();
      mockSecretManagerStatus.mockResolvedValue(
        secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE, context),
      );
    });

    describe('skipping secrets manager status query', () => {
      it('skips status query while entitlement is loading', async () => {
        mockEntitlementQuery.mockReturnValue(new Promise(() => {}));
        await createComponent({
          provide: {
            glFeatures: { secretsManagerPaidExperience: true },
            topLevelGroupFullPath: 'top-level-group',
          },
          stubs: { 'router-view': true },
          isLoading: true,
        });

        expect(mockSecretManagerStatus).not.toHaveBeenCalled();
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('skips status query when trial eligible', async () => {
        mockEntitlementQuery.mockResolvedValue(entitlementResponse({ state: 'TRIAL_ELIGIBLE' }));
        await createComponent({
          provide: {
            glFeatures: { secretsManagerPaidExperience: true },
            topLevelGroupFullPath: 'top-level-group',
          },
          stubs: { GlSprintf, 'router-view': true },
        });

        expect(mockSecretManagerStatus).not.toHaveBeenCalled();
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('runs status query after entitlement resolves as non-trial-eligible', async () => {
        mockEntitlementQuery.mockResolvedValue(entitlementResponse({ state: 'TRIAL' }));
        await createComponent({
          provide: {
            glFeatures: { secretsManagerPaidExperience: true },
            topLevelGroupFullPath: 'top-level-group',
          },
          stubs: { 'router-view': true },
        });

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findRouterView().exists()).toBe(true);
      });

      it('does not show loading icon when status query returns null', async () => {
        mockEntitlementQuery.mockResolvedValue(entitlementResponse({ state: 'TRIAL' }));
        mockSecretManagerStatus.mockResolvedValue({ data: { secretsManager: null } });
        await createComponent({
          provide: {
            glFeatures: { secretsManagerPaidExperience: true },
            topLevelGroupFullPath: 'top-level-group',
          },
          stubs: { 'router-view': true },
        });

        expect(findLoadingIcon().exists()).toBe(false);
        expect(findRouterView().exists()).toBe(true);
      });
    });

    describe('when secrets manager status is being fetched', () => {
      beforeEach(() => {
        createComponent({ stubs: { 'router-view': true }, isLoading: true, context });
      });

      it('renders the loading state', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });

      it('does not render the router view', () => {
        expect(findRouterView().exists()).toBe(false);
      });
    });

    describe('when secrets manager is being provisioned', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING, context),
        );
        await createComponent({ stubs: { 'router-view': true }, context });
      });

      // empty state owns the provisioning UI
      it('renders the router view', () => {
        expect(findRouterView().exists()).toBe(true);
      });

      it('does not render the loading state', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('polls for updated status while provisioning', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        await pollNextStatus(SECRET_MANAGER_STATUS_PROVISIONING, context);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
      });

      it('stops polling when provisioned', async () => {
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, context);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);

        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, context);
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, context);
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
      });
    });

    // e.g. provisioning was started in another tab and the user
    // opened/refreshed this page mid-provisioning.
    describe('when the page loads while provisioning is already in-progress', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING, context),
        );
        await createComponent({ context, router: createRouterForTest(context) });
      });

      it('shows the loading button in the empty state', () => {
        expect(findEmptyStateNewSecretBtn().props('loading')).toBe(true);
      });

      it('fires the success flow when status flips to ACTIVE', async () => {
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, context);

        expect(createAlert).toHaveBeenCalled();
      });
    });

    describe('when secrets manager has been provisioned', () => {
      beforeEach(async () => {
        await createComponent({ stubs: { 'router-view': true }, context });
      });

      it('renders the router view', () => {
        expect(findRouterView().exists()).toBe(true);
      });

      it('stops polling for status', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, context);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
      });
    });

    describe('when secrets manager is not provisioned', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue({ data: { secretsManager: null } });
        await createComponent({ stubs: { 'router-view': true }, context });
      });

      it('stops polling', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        await pollNextStatus(null, context);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
      });
    });

    describe('when there is an error with fetching the secrets manager status', () => {
      const error = new Error('GraphQL error: API error');

      beforeEach(async () => {
        mockSecretManagerStatus.mockRejectedValue(error);
        await createComponent({ stubs: { 'router-view': true }, context });
      });

      it('renders an error message', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'API error',
          captureError: true,
          error,
        });
      });

      it('stops polling', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        advanceToNextFetch(POLL_INTERVAL);

        await waitForPromises();
        await nextTick();

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
      });

      it('does not render the loading state or router view', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findRouterView().exists()).toBe(false);
      });
    });

    describe('when entity is not archived or marked for deletion', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE, context, {
            archived: false,
            markedForDeletion: false,
          }),
        );

        await createComponent({
          context,
          router: createRouterForTest(context),
        });
      });

      it('shows action buttons', () => {
        expect(findEmptyStateNewSecretBtn().exists()).toBe(true);
      });
    });

    describe('when entity is archived', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE, context, {
            archived: true,
            markedForDeletion: false,
          }),
        );

        await createComponent({
          context,
          router: createRouterForTest(context),
        });
      });

      it('sets secrets manager to read-only mode by hiding action buttons', () => {
        expect(findEmptyStateNewSecretBtn().exists()).toBe(false);
      });
    });

    describe('when entity is marked for deletion', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE, context, {
            archived: false,
            markedForDeletion: true,
          }),
        );

        await createComponent({
          context,
          router: createRouterForTest(context),
        });
      });

      it('sets secrets manager to read-only mode by hiding action buttons', () => {
        expect(findEmptyStateNewSecretBtn().exists()).toBe(false);
      });
    });
  });

  describe('toast message', () => {
    beforeEach(async () => {
      await createComponent({
        router: createRouterForTest(ENTITY_PROJECT),
      });
    });

    it('renders toast message when show-secrets-toast is emitted', async () => {
      findRouterView().vm.$emit('show-secrets-toast', 'This is a toast message.');
      await nextTick();

      expect(mockToastShow).toHaveBeenCalledWith('This is a toast message.');
    });
  });

  describe('when OpenBao is unhealthy', () => {
    beforeEach(async () => {
      mockOpenbaoHealth.mockResolvedValue(openbaoHealthResponse(false));
      await createComponent({
        router: createRouterForTest(ENTITY_PROJECT),
      });
    });

    it('shows an alert with unhealthy message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        title: 'Cannot connect to OpenBao',
        message:
          'Failed to connect with OpenBao. Secrets are currently unavailable, please try again later.',
      });
    });

    it('renders the router view', () => {
      expect(findRouterView().exists()).toBe(true);
    });

    it('redirects to index route when on a different route', async () => {
      const router = createRouterForTest(ENTITY_PROJECT);
      await router.push({ name: 'new' }).catch(() => {});

      mockOpenbaoHealth.mockResolvedValue(openbaoHealthResponse(false));
      await createComponent({ router });

      expect(router.currentRoute.name).toBe('index');
    });
  });

  describe('when OpenBao health query fails', () => {
    beforeEach(async () => {
      mockOpenbaoHealth.mockRejectedValue(new Error('Network error'));
      await createComponent({
        router: createRouter('/-/secrets'),
      });
    });

    it('shows an alert with unhealthy message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        title: 'Cannot connect to OpenBao',
        message:
          'Failed to connect with OpenBao. Secrets are currently unavailable, please try again later.',
      });
    });

    it('renders the router view', () => {
      expect(findRouterView().exists()).toBe(true);
    });
  });

  describe('entitlement query', () => {
    it('calls the entitlement query with the correct variables', async () => {
      await createPaidExperienceComponent();

      expect(mockEntitlementQuery).toHaveBeenCalledWith({ fullPath: 'top-level-group' });
    });

    it('renders an error when entitlement query fails', async () => {
      const error = new Error('GraphQL error: Entitlement error');
      mockEntitlementQuery.mockRejectedValue(error);
      await createPaidExperienceComponent();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Entitlement error',
        captureError: true,
        error,
      });
    });

    it('skips the entitlement query when feature flag is disabled', async () => {
      await createPaidExperienceComponent({
        glFeatures: { secretsManagerPaidExperience: false },
      });

      expect(mockEntitlementQuery).not.toHaveBeenCalled();
    });

    it('skips the entitlement query when topLevelGroupFullPath is empty', async () => {
      await createPaidExperienceComponent({ topLevelGroupFullPath: '' });

      expect(mockEntitlementQuery).not.toHaveBeenCalled();
    });

    it('shows loading state when entitlement query is skipped but status is still loading', async () => {
      mockSecretManagerStatus.mockReturnValue(new Promise(() => {}));
      await createPaidExperienceComponent({ topLevelGroupFullPath: '' });

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findRouterView().exists()).toBe(false);
    });

    it('sets read-only mode when entitlement state is blocked', async () => {
      mockEntitlementQuery.mockResolvedValue(
        entitlementResponse({ state: 'BLOCKED', blockedReason: 'TRIAL_EXPIRED' }),
      );
      await createPaidExperienceComponent();

      expect(findEmptyStateNewSecretBtn().exists()).toBe(false);
    });
  });

  describe('trial alerts', () => {
    const expiryTwoDays = new Date(Date.now() + 172800000).toISOString();
    const expiryThirtyDays = new Date(Date.now() + 2592000000).toISOString();

    it('does not render trial alert when feature flag is disabled', async () => {
      await createPaidExperienceComponent({
        glFeatures: { secretsManagerPaidExperience: false },
      });

      expect(findTrialAlert().exists()).toBe(false);
    });

    it('does not render trial alert when trial is active with sufficient credits and time', async () => {
      mockEntitlementQuery.mockResolvedValue(
        entitlementResponse({
          state: 'TRIAL',
          creditsRemaining: 400,
          creditsTotal: 500,
          trialExpiresAt: expiryThirtyDays,
          onDemandEnabled: true,
        }),
      );
      await createPaidExperienceComponent();

      expect(findTrialAlert().exists()).toBe(false);
    });

    describe('when trial credits are low', () => {
      it('renders a warning alert with on-demand enabled message', async () => {
        mockEntitlementQuery.mockResolvedValue(
          entitlementResponse({
            state: 'TRIAL',
            creditsRemaining: 5,
            creditsTotal: 500,
            trialExpiresAt: expiryTwoDays,
            onDemandEnabled: true,
          }),
        );
        await createPaidExperienceComponent();

        expect(findTrialAlert().props('variant')).toBe('warning');
        expect(findTrialAlert().props('title')).toBe('1% of credits left in secrets manager trial');
        expect(findTrialAlert().text()).toContain(
          'On-demand billing is enabled, and you will incur charges after the trial period ends.',
        );
        expect(findTrialAlertLink().attributes('href')).toBe(
          helpPagePath('subscriptions/gitlab_credits'),
        );
      });

      it('renders a warning alert with on-demand disabled message', async () => {
        mockEntitlementQuery.mockResolvedValue(
          entitlementResponse({
            state: 'TRIAL',
            creditsRemaining: 5,
            creditsTotal: 500,
            trialExpiresAt: expiryTwoDays,
            onDemandEnabled: false,
          }),
        );
        await createPaidExperienceComponent();

        expect(findTrialAlert().props('variant')).toBe('warning');
        expect(findTrialAlert().props('title')).toBe('1% of credits left in secrets manager trial');
        expect(findTrialAlert().text()).toContain(
          'Contact your billing administrator to enable on-demand billing and avoid disruption.',
        );
      });

      it('rounds nonzero percentages below 1% up to 1%', async () => {
        mockEntitlementQuery.mockResolvedValue(
          entitlementResponse({
            state: 'TRIAL',
            creditsRemaining: 2,
            creditsTotal: 500,
            trialExpiresAt: expiryTwoDays,
            onDemandEnabled: true,
          }),
        );
        await createPaidExperienceComponent();

        expect(findTrialAlert().props('title')).toBe('1% of credits left in secrets manager trial');
      });
    });

    describe('when trial credits are exhausted and on-demand is enabled', () => {
      beforeEach(async () => {
        mockEntitlementQuery.mockResolvedValue(
          entitlementResponse({
            state: 'TRIAL',
            creditsRemaining: 0,
            creditsTotal: 500,
            trialExpiresAt: expiryThirtyDays,
            onDemandEnabled: true,
          }),
        );
        await createPaidExperienceComponent();
      });

      it('renders a warning alert with credits exhausted message', () => {
        expect(findTrialAlert().props('variant')).toBe('warning');
        expect(findTrialAlert().props('title')).toBe('All trial credits used');
        expect(findTrialAlert().text()).toContain(
          'On-demand billing is enabled, and you are incurring charges for continued usage.',
        );
        expect(findTrialAlertLink().attributes('href')).toBe(
          helpPagePath('subscriptions/gitlab_credits'),
        );
      });
    });

    describe('when trial is expiring soon', () => {
      const expiryFiveDays = new Date(Date.now() + 5 * 86400000).toISOString();

      it('renders a warning alert with on-demand enabled message', async () => {
        mockEntitlementQuery.mockResolvedValue(
          entitlementResponse({
            state: 'TRIAL',
            creditsRemaining: 400,
            creditsTotal: 500,
            trialExpiresAt: expiryFiveDays,
            onDemandEnabled: true,
          }),
        );
        await createPaidExperienceComponent();

        expect(findTrialAlert().props('variant')).toBe('warning');
        expect(findTrialAlert().props('title')).toBe('Secrets manager trial ends in 5 days');
        expect(findTrialAlert().text()).toContain(
          'On-demand billing is enabled. When all trial credits are consumed, GitLab credits will be used.',
        );
      });

      it('renders a warning alert with on-demand disabled message', async () => {
        mockEntitlementQuery.mockResolvedValue(
          entitlementResponse({
            state: 'TRIAL',
            creditsRemaining: 400,
            creditsTotal: 500,
            trialExpiresAt: expiryFiveDays,
            onDemandEnabled: false,
          }),
        );
        await createPaidExperienceComponent();

        expect(findTrialAlert().props('variant')).toBe('warning');
        expect(findTrialAlert().props('title')).toBe('Secrets manager trial ends in 5 days');
        expect(findTrialAlert().text()).toContain(
          'Contact your billing administrator to enable on-demand billing and avoid disruption.',
        );
      });
    });

    describe.each`
      blockedReason                            | expectedTitle
      ${BLOCKED_REASON_CREDITS_EXHAUSTED}      | ${'0 credits left in secrets manager trial'}
      ${BLOCKED_REASON_GRACE}                  | ${'Your secrets manager subscription has been cancelled'}
      ${BLOCKED_REASON_ON_DEMAND_DISABLED}     | ${'On-demand billing is disabled'}
      ${BLOCKED_REASON_SUBSCRIPTION_CANCELLED} | ${'Your secrets manager add-on has been removed from your license'}
      ${BLOCKED_REASON_TRIAL_EXPIRED}          | ${'Secrets manager trial period has ended'}
    `('when blocked with reason $blockedReason', ({ blockedReason, expectedTitle }) => {
      beforeEach(async () => {
        mockEntitlementQuery.mockResolvedValue(
          entitlementResponse({ state: 'BLOCKED', blockedReason }),
        );
        await createPaidExperienceComponent();
      });

      it('renders a danger alert with the correct title', () => {
        expect(findTrialAlert().props('variant')).toBe('danger');
        expect(findTrialAlert().props('title')).toBe(expectedTitle);
      });
    });
  });

  describe('provision secrets manager', () => {
    const emitProvisionSecretsManager = async () => {
      findEmptyState().vm.$emit('provision-secrets-manager');
      await waitForPromises();
    };

    describe.each`
      context
      ${ENTITY_PROJECT}
      ${ENTITY_GROUP}
    `('in $context context', ({ context }) => {
      describe('on success', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue({ data: { secretsManager: null } });
          mockEnableSecretsManager.mockResolvedValue(enableSecretManagerResponse({ context }));

          await createComponent({ context, router: createRouterForTest(context) });
          await emitProvisionSecretsManager();
        });

        itSkipVue3(
          new SkipReason({
            name: 'calls the enable mutation with fullPath',
            reason:
              'Events emitted from a component nested inside <router-view> do not propagate to the parent template listener under vue-router 4',
            issue: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/612945',
          }),
          () => {
            // eslint-disable-next-line jest/no-standalone-expect
            expect(mockEnableSecretsManager).toHaveBeenCalledWith({
              fullPath: defaultProvide.fullPath,
            });
          },
        );

        itSkipVue3(
          new SkipReason({
            name: 'refetches the secrets manager status',
            reason:
              'Events emitted from a component nested inside <router-view> do not propagate to the parent template listener under vue-router 4',
            issue: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/612945',
          }),
          () => {
            // status was fetched on load; refetch after successful mutation.
            // eslint-disable-next-line jest/no-standalone-expect
            expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
          },
        );
      });

      describe('when the mutation returns errors', () => {
        beforeEach(async () => {
          mockSecretManagerStatus.mockResolvedValue({ data: { secretsManager: null } });
          mockEnableSecretsManager.mockResolvedValue(
            enableSecretManagerResponse({ context, errors: ['Not authorized'] }),
          );

          await createComponent({ context, router: createRouterForTest(context) });
          await emitProvisionSecretsManager();
        });

        itSkipVue3(
          new SkipReason({
            name: 'creates a generic error alert',
            reason:
              'Events emitted from a component nested inside <router-view> do not propagate to the parent template listener under vue-router 4',
            issue: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/612945',
          }),
          () => {
            // eslint-disable-next-line jest/no-standalone-expect
            expect(createAlert).toHaveBeenCalledWith(
              expect.objectContaining({
                message:
                  'There was a problem enabling the GitLab Secrets Manager. Try again later.',
              }),
            );
          },
        );

        it('clears the loading state on button', () => {
          // button loading is bound to isProvisioning; ensure it's reset after error.
          expect(findEmptyStateNewSecretBtn().props('loading')).toBe(false);
        });
      });
    });
  });

  // All specs in this block use `itSkipVue3`, which lifts the assertion
  // out of a standard `it(...)` callback. jest/no-standalone-expect flags
  // that pattern for every assertion below; the rule is disabled once
  // here instead of on every line. Drop this disable when the Vue 3 skips
  // are removed (see https://gitlab.com/gitlab-org/gitlab/-/work_items/612945).
  /* eslint-disable jest/no-standalone-expect */
  describe('start trial', () => {
    const emitStartTrial = async () => {
      findTrialEmptyState().vm.$emit('start-trial');
      await waitForPromises();
    };

    const skipReason = (name) =>
      new SkipReason({
        name,
        reason:
          'Events emitted from a component nested inside <router-view> do not propagate to the parent template listener under vue-router 4',
        issue: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/612945',
      });

    const trialSuccessAlert = {
      message:
        'The GitLab Secrets Manager trial has been enabled for all groups and projects within this namespace. %{linkStart}Manage group permissions.%{linkEnd}',
      messageLinks: { link: managePermissionsPath },
      variant: VARIANT_SUCCESS,
    };

    // Trial chain runs against a TLG, so we're always in ENTITY_GROUP context.
    const setUpTrialEligible = async () => {
      await createComponent({
        context: ENTITY_GROUP,
        router: createRouterForTest(ENTITY_GROUP),
        provide: {
          glFeatures: { secretsManagerPaidExperience: true },
          topLevelGroupFullPath: 'top-level-group',
        },
      });
    };

    beforeEach(() => {
      mockEntitlementQuery.mockResolvedValue(entitlementResponse({ state: 'TRIAL_ELIGIBLE' }));
      // TLG provisioning mutation succeeds; backend then flips status to
      // PROVISIONING while the async job runs, and finally to ACTIVE.
      mockEnableSecretsManager.mockResolvedValue(
        enableSecretManagerResponse({ context: ENTITY_GROUP }),
      );
      mockSecretManagerStatus.mockResolvedValue(
        secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING, ENTITY_GROUP),
      );
    });

    describe('on successful onboarding', () => {
      beforeEach(async () => {
        await setUpTrialEligible();
        await emitStartTrial();
        // Simulate the backend provisioning job completing.
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);
      });

      itSkipVue3(skipReason('fires enrollment mutation with the top-level group path'), () => {
        expect(mockEnrollNamespace).toHaveBeenCalledWith({ fullPath: 'top-level-group' });
      });

      itSkipVue3(skipReason('fires trial mutation with the top-level group path'), () => {
        expect(mockStartTrial).toHaveBeenCalledWith({ groupPath: 'top-level-group' });
      });

      itSkipVue3(skipReason('fires provisioning mutation with the current fullPath'), () => {
        expect(mockEnableSecretsManager).toHaveBeenCalledWith({
          fullPath: defaultProvide.fullPath,
        });
      });

      itSkipVue3(skipReason('refetches the entitlement after the chain succeeds'), () => {
        // initial fetch + post-chain refetch (fires from the status watch)
        expect(mockEntitlementQuery).toHaveBeenCalledTimes(2);
      });

      itSkipVue3(skipReason('shows a single success alert with the settings link'), () => {
        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith(trialSuccessAlert);
      });
    });

    describe('while provisioning is still polling', () => {
      const setUpPendingProvisioning = async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING, ENTITY_GROUP),
        );
        await setUpTrialEligible();
        await emitStartTrial();
      };

      itSkipVue3(skipReason('keeps the trial empty state visible'), async () => {
        await setUpPendingProvisioning();
        expect(findTrialEmptyState().exists()).toBe(true);
      });

      itSkipVue3(skipReason('does not show the success alert'), async () => {
        await setUpPendingProvisioning();
        expect(createAlert).not.toHaveBeenCalled();
      });

      itSkipVue3(skipReason('does not refetch the entitlement while polling'), async () => {
        await setUpPendingProvisioning();
        // Only the initial fetch; the post-chain refetch must wait until
        // the status flips to ACTIVE so on-refetch UI reflects the final
        // (TRIAL) state rather than the transient trial-eligible state.
        expect(mockEntitlementQuery).toHaveBeenCalledTimes(1);
      });

      itSkipVue3(
        skipReason('shows success alert after polling ends and secrets manager is provisioned'),
        async () => {
          await setUpPendingProvisioning();
          await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);

          expect(createAlert).toHaveBeenCalledTimes(1);
          expect(createAlert).toHaveBeenCalledWith(trialSuccessAlert);
        },
      );

      itSkipVue3(
        skipReason('refetches the entitlement only after status reaches ACTIVE'),
        async () => {
          await setUpPendingProvisioning();
          await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);

          // initial fetch + post-chain refetch (fires only after ACTIVE)
          expect(mockEntitlementQuery).toHaveBeenCalledTimes(2);
        },
      );
    });

    describe('when enroll returns a benign already-enrolled error', () => {
      beforeEach(async () => {
        mockEnrollNamespace.mockResolvedValue(enrollNamespaceAlreadyEnrolledResponse());
        await setUpTrialEligible();
        await emitStartTrial();
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);
      });

      itSkipVue3(skipReason('continues to trial'), () => {
        expect(mockStartTrial).toHaveBeenCalledWith({ groupPath: 'top-level-group' });
      });

      itSkipVue3(skipReason('shows a success message with the settings link'), () => {
        expect(createAlert).toHaveBeenCalledWith(trialSuccessAlert);
      });
    });

    describe('when start trial returns a benign error', () => {
      beforeEach(async () => {
        mockStartTrial.mockResolvedValue(
          startTrialErrorResponse(['A Secrets Manager trial is already active for this group.']),
        );
        await setUpTrialEligible();
        await emitStartTrial();
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);
      });

      itSkipVue3(skipReason('continues to provisioning'), () => {
        expect(mockEnableSecretsManager).toHaveBeenCalled();
      });

      itSkipVue3(skipReason('shows a success message with the settings link'), () => {
        expect(createAlert).toHaveBeenCalledWith(trialSuccessAlert);
      });
    });

    describe('when provisioning returns a benign already-initialized error', () => {
      beforeEach(async () => {
        mockEnableSecretsManager.mockResolvedValue(
          enableSecretManagerResponse({
            context: ENTITY_GROUP,
            errors: ['Secrets manager already initialized for the group.'],
          }),
        );
        await setUpTrialEligible();
        await emitStartTrial();
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);
      });

      itSkipVue3(skipReason('shows the success alert'), () => {
        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith(trialSuccessAlert);
      });
    });

    describe('when enrollment fails with a non-benign error', () => {
      beforeEach(async () => {
        mockEnrollNamespace.mockResolvedValue(enrollNamespaceErrorResponse(['Not authorized']));
        await setUpTrialEligible();
        await emitStartTrial();
      });

      itSkipVue3(skipReason('does not call start trial'), () => {
        expect(mockStartTrial).not.toHaveBeenCalled();
      });

      itSkipVue3(skipReason('does not call provisioning'), () => {
        expect(mockEnableSecretsManager).not.toHaveBeenCalled();
      });

      itSkipVue3(skipReason('shows an error alert'), () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({ message: 'Not authorized' }),
        );
      });

      itSkipVue3(skipReason('keeps the trial empty state visible for retry'), () => {
        expect(findTrialEmptyState().exists()).toBe(true);
      });
    });

    describe('when start trial fails after enrollment succeeds', () => {
      beforeEach(async () => {
        mockStartTrial.mockResolvedValue(startTrialErrorResponse(['This group is not eligible']));
        await setUpTrialEligible();
        await emitStartTrial();
      });

      itSkipVue3(skipReason('does not call provisioning'), () => {
        expect(mockEnableSecretsManager).not.toHaveBeenCalled();
      });

      itSkipVue3(skipReason('shows an error alert'), () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({ message: 'This group is not eligible' }),
        );
      });

      itSkipVue3(skipReason('re-runs the chain on retry'), async () => {
        // partial-progress retry: enroll is idempotent and returns benign
        // error; trial now succeeds; provisioning completes; success alert
        // fires from the status watch.
        mockEnrollNamespace.mockResolvedValue(enrollNamespaceAlreadyEnrolledResponse());
        mockStartTrial.mockResolvedValue(startTrialSuccessResponse());

        await emitStartTrial();
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);

        expect(mockEnrollNamespace).toHaveBeenCalledTimes(2);
        expect(mockStartTrial).toHaveBeenCalledTimes(2);
        expect(mockEnableSecretsManager).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith(trialSuccessAlert);
      });
    });

    describe('when a mutation in the chain throws (transport-level error)', () => {
      // Distinct from "mutation returns errors" (GraphQL payload errors,
      // covered above): this covers the promise-rejection path (network
      // failure, transport-level exception).
      beforeEach(async () => {
        mockEnrollNamespace.mockRejectedValue(new Error('Network error'));
        await setUpTrialEligible();
        await emitStartTrial();
      });

      itSkipVue3(skipReason('surfaces the thrown error message'), () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Network error',
            captureError: true,
          }),
        );
      });

      itSkipVue3(skipReason('does not show the success alert'), () => {
        expect(createAlert).not.toHaveBeenCalledWith(trialSuccessAlert);
      });

      itSkipVue3(skipReason('keeps the trial empty state visible for retry'), () => {
        expect(findTrialEmptyState().exists()).toBe(true);
      });
    });

    describe('when a mutation throws without a message', () => {
      // Covers the generic-copy fallback path: some transport errors surface
      // as an Error without a useful `.message`. The catch should fall back
      // to the generic "An error occurred..." copy so the user isn't shown
      // an empty alert.
      beforeEach(async () => {
        mockEnrollNamespace.mockRejectedValue(new Error());
        await setUpTrialEligible();
        await emitStartTrial();
      });

      itSkipVue3(skipReason('shows the generic trial error alert'), () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'An error occurred while starting the trial.',
            captureError: true,
          }),
        );
      });
    });

    describe('when provisioning fails after trial succeeds', () => {
      beforeEach(async () => {
        mockEnableSecretsManager.mockResolvedValue(
          enableSecretManagerResponse({
            context: ENTITY_GROUP,
            errors: ['Provisioning backend unavailable'],
          }),
        );
        await setUpTrialEligible();
        await emitStartTrial();
      });

      itSkipVue3(skipReason('shows the provisioning error'), () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({ message: 'Provisioning backend unavailable' }),
        );
      });

      itSkipVue3(skipReason('does not show the success alert'), () => {
        expect(createAlert).not.toHaveBeenCalledWith(trialSuccessAlert);
      });

      itSkipVue3(skipReason('keeps the trial empty state visible for retry'), () => {
        expect(findTrialEmptyState().exists()).toBe(true);
      });

      itSkipVue3(skipReason('re-runs the full chain on retry'), async () => {
        // benign errors on enroll and trial (already done); provisioning
        // now succeeds and status flips to ACTIVE; single success alert.
        mockEnrollNamespace.mockResolvedValue(enrollNamespaceAlreadyEnrolledResponse());
        mockStartTrial.mockResolvedValue(
          startTrialErrorResponse(['A Secrets Manager trial is already active for this group.']),
        );
        mockEnableSecretsManager.mockResolvedValue(
          enableSecretManagerResponse({ context: ENTITY_GROUP }),
        );

        await emitStartTrial();
        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, ENTITY_GROUP);

        expect(mockEnableSecretsManager).toHaveBeenCalledTimes(2);
        expect(createAlert).toHaveBeenCalledWith(trialSuccessAlert);
      });
    });
  });
  /* eslint-enable jest/no-standalone-expect */

  describe('provisioning success alert', () => {
    // simulate the empty state's click, then simulate the backend returning
    // PROVISIONING on the post-mutation refetch (so polling kicks in).
    const startProvisioningFlow = async (context) => {
      mockSecretManagerStatus.mockResolvedValue(
        secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING, context),
      );
      findEmptyState().vm.$emit('provision-secrets-manager');
      await waitForPromises();
    };

    describe.each`
      context           | expectedMessage
      ${ENTITY_PROJECT} | ${'GitLab Secrets Manager has been enabled for this project.'}
      ${ENTITY_GROUP}   | ${'GitLab Secrets Manager has been enabled for this group.'}
    `('in $context context', ({ context, expectedMessage }) => {
      beforeEach(async () => {
        // start with an unprovisioned state so the user can click "New secret"
        // to kick off provisioning.
        mockSecretManagerStatus.mockResolvedValue({ data: { secretsManager: null } });
        mockEnableSecretsManager.mockResolvedValue(enableSecretManagerResponse({ context }));
        await createComponent({ context, router: createRouterForTest(context) });
      });

      itSkipVue3(
        new SkipReason({
          name: 'fires a success alert with a manage permissions link',
          reason:
            'Events emitted from a component nested inside <router-view> do not propagate to the parent template listener under vue-router 4',
          issue: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/612945',
        }),
        async () => {
          await startProvisioningFlow(context);
          await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE, context);

          // eslint-disable-next-line jest/no-standalone-expect
          expect(createAlert).toHaveBeenCalledWith({
            message: `${expectedMessage} %{linkStart}Manage permissions.%{linkEnd}`,
            messageLinks: { link: managePermissionsPath },
            variant: VARIANT_SUCCESS,
          });
        },
      );
    });
  });
});
