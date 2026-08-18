import { GlDisclosureDropdownItem, GlLabel, GlLoadingIcon, GlTableLite } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { RouterLinkStub } from '@vue/test-utils';
import { createAlert } from '~/alert';
import UserDate from '~/vue_shared/components/user_date.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  ENTITY_GROUP,
  ENTITY_PROJECT,
  ENTITLEMENT_STATE_TRIAL_ELIGIBLE,
} from 'ee/ci/secrets/constants';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import SecretsEmptyState from 'ee/ci/secrets/components/secrets_empty_state.vue';
import SecretsTrialEmptyState from 'ee/ci/secrets/components/secrets_table/secrets_trial_empty_state.vue';
import SecretActionsCell from 'ee/ci/secrets/components/secrets_table/secret_actions_cell.vue';
import SecretDeleteModal from 'ee/ci/secrets/components/secret_delete_modal.vue';
import SecretsAlertBanner from 'ee/ci/secrets/components/secrets_table/secrets_alert_banner.vue';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from 'ee/ci/secrets/context_config';
import {
  mockEmptySecrets,
  mockGroupSecretsData,
  mockGroupSecretsResponse,
  mockProjectSecretsData,
  mockProjectSecretsResponse,
} from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);
const { bindInternalEventDocument } = useMockInternalEventsTracking();

describe('SecretsTable component', () => {
  let wrapper;
  let apolloProvider;
  let mockSecretsListResponse;
  let mockSecretsNeedingRotationResponse;
  let mockSecretManagerStatus;

  const findDeleteModal = () => wrapper.findComponent(SecretDeleteModal);
  const findEmptyState = () => wrapper.findComponent(SecretsEmptyState);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findNewSecretButton = () => wrapper.findComponentByTestId('new-secret-button');
  const findSecretsTable = () => wrapper.findComponent(GlTableLite);
  const findSecretsTableRows = () => findSecretsTable().find('tbody').findAll('tr');
  const findSecretBranches = () => wrapper.findByTestId('secret-branches');
  const findSecretBranchesRow = (index) =>
    findSecretsTableRows().at(index).findAll('td').at(0).find('code');
  const findSecretDetailsLink = () => wrapper.findComponentByTestId('secret-details-link');
  const findSecretEnvironmentsRow = (index) =>
    findSecretsTableRows().at(index).findAll('td').at(0).findComponent(GlLabel);
  const findSecretHealthStatus = (index) =>
    wrapper.findAllComponentsByTestId('secret-health-status').at(index);
  const findSecretActionsCell = () => wrapper.findComponent(SecretActionsCell);
  const findSecretsAlertBanner = () => wrapper.findComponent(SecretsAlertBanner);
  const findSecretsCreatedDateCell = () =>
    wrapper.findByTestId('secret-created-at').findComponent(UserDate);

  const findDeleteButton = (index) =>
    wrapper
      .findAllComponents(SecretActionsCell)
      .at(index)
      .findAllComponents(GlDisclosureDropdownItem)
      .at(1)
      .find('button');

  const findProtectedBadges = () => wrapper.findAllByTestId('secret-protected-badge');
  const findRotationApproachingIcon = () =>
    wrapper.findComponentByTestId('rotation-approaching-icon');
  const findRotationOverdueIcon = () => wrapper.findComponentByTestId('rotation-overdue-icon');

  const findDocumentationLink = () => wrapper.findByTestId('documentation-link');
  const findFeedbackLink = () => wrapper.findByTestId('feedback-link');
  const findTrialEmptyState = () => wrapper.findComponent(SecretsTrialEmptyState);

  const createComponent = async ({
    context = ENTITY_PROJECT,
    provide,
    isLoading = false,
    isOpenbaoHealthy = true,
    entitlement = null,
    isSaas = false,
    secretManagerStatus = 'ACTIVE',
  } = {}) => {
    const contextConfig = SECRETS_MANAGER_CONTEXT_CONFIG[context];
    const handlers = [
      [contextConfig.getStatus.query, mockSecretManagerStatus],
      [contextConfig.getSecrets.query, mockSecretsListResponse],
      [contextConfig.getSecretsNeedingRotation.query, mockSecretsNeedingRotationResponse],
    ];
    apolloProvider = createMockApollo(handlers);

    wrapper = mountExtended(SecretsTable, {
      provide: {
        fullPath: `path/to/entity`,
        contextConfig,
        enrollmentSettingsPath: '/group/settings',
        entitlement,
        isTrialOnboarding: false,
        isOpenbaoHealthy,
        isSaas,
        isProvisioning: false,
        isReadOnly: false,
        secretManagerStatus,
        topLevelGroupFullPath: 'top-level-group',
        ...provide,
      },
      apolloProvider,
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });

    if (!isLoading) {
      await waitForPromises();
    }
  };

  const mockSecretsNeedingRotation = () => ({
    data: {
      secretsNeedingRotation: {
        nodes: [
          {
            name: 'SECRET_1',
            rotationInfo: {
              rotationIntervalDays: 7,
              nextReminderAt: null,
              lastReminderAt: null,
              status: 'APPROACHING',
            },
          },
        ],
      },
    },
  });

  beforeEach(() => {
    mockSecretsListResponse = jest.fn();
    mockSecretManagerStatus = jest.fn();

    mockSecretsNeedingRotationResponse = jest.fn().mockResolvedValue(mockSecretsNeedingRotation());
  });

  afterEach(() => {
    apolloProvider = null;
  });

  const projectContextData = {
    first: 100,
    showBranch: true,
    visitEventName: 'visit_project_secrets_manager',
  };

  const groupContextData = {
    first: 500,
    showBranch: false,
    visitEventName: 'visit_group_secrets_manager',
  };

  describe.each`
    context           | secretsList               | mockSecretsResponse           | contextData
    ${ENTITY_PROJECT} | ${mockProjectSecretsData} | ${mockProjectSecretsResponse} | ${projectContextData}
    ${ENTITY_GROUP}   | ${mockGroupSecretsData}   | ${mockGroupSecretsResponse}   | ${groupContextData}
  `(
    'managing a secret in $context context',
    ({ context, secretsList, mockSecretsResponse, contextData }) => {
      describe('when secrets query is loading', () => {
        beforeEach(() => {
          createComponent({ context, isLoading: true });
        });

        it('shows loading icon', () => {
          expect(findLoadingIcon().exists()).toBe(true);
        });

        it('does not show empty state or table', () => {
          expect(findEmptyState().exists()).toBe(false);
          expect(findSecretsTable().exists()).toBe(false);
        });
      });

      describe('when there are no secrets', () => {
        beforeEach(async () => {
          mockSecretsListResponse.mockResolvedValue(mockEmptySecrets);
          await createComponent({ context });
        });

        it('shows empty state', () => {
          expect(findEmptyState().exists()).toBe(true);
        });

        it('does not show table or loading icon', () => {
          expect(findSecretsTable().exists()).toBe(false);
          expect(findLoadingIcon().exists()).toBe(false);
        });

        it('allows creating a new secret from the empty state', () => {
          expect(findEmptyState().props('canCreateSecret')).toBe(true);
        });
      });

      describe('when secrets are fetched', () => {
        const secret = secretsList[0].node;

        beforeEach(async () => {
          mockSecretsListResponse.mockResolvedValue(mockSecretsResponse());
          await createComponent({ context });
        });

        it('query is called with the correct variables', () => {
          expect(mockSecretsListResponse).toHaveBeenLastCalledWith({
            first: contextData.first,
            fullPath: 'path/to/entity',
          });
        });

        it('does not show the empty state or loading icon', () => {
          expect(findEmptyState().exists()).toBe(false);
          expect(findLoadingIcon().exists()).toBe(false);
        });

        it('shows a link to the new secret page', () => {
          expect(findNewSecretButton().props('to')).toBe('new');
        });

        it('renders a table of secrets', () => {
          expect(findSecretsTable().exists()).toBe(true);
          expect(findSecretsTableRows()).toHaveLength(secretsList.length);
          expect(findSecretBranches().exists()).toBe(contextData.showBranch);
        });

        it('shows protected badges when enabled for group secrets', () => {
          const protectedCount = secretsList.filter((s) => s.node.protected === true).length;
          expect(findProtectedBadges()).toHaveLength(protectedCount);
        });

        it('shows the secret name as a link to the secret details', () => {
          expect(findSecretDetailsLink().text()).toBe(secret.name);
          expect(findSecretDetailsLink().props('to')).toMatchObject({
            name: 'details',
            params: { secretName: secret.name },
          });
        });

        it('passes the correct date to the createdAt date cell', () => {
          expect(findSecretsCreatedDateCell().props('date')).toBe(secret.createdAt);
        });

        it('passes correct props to actions cell', () => {
          expect(findSecretActionsCell().props()).toMatchObject({
            secretName: secret.name,
          });
        });

        it('hides the delete secret modal', () => {
          expect(findDeleteModal().props('showModal')).toBe(false);
        });

        it('renders feedback link', () => {
          expect(findFeedbackLink().attributes('href')).toBe(
            'https://gitlab.com/gitlab-org/gitlab/-/work_items/598100',
          );
        });

        it('renders documentation link', () => {
          expect(findDocumentationLink().attributes('href')).toBe(
            '/help/ci/secrets/secrets_manager/_index',
          );
        });
      });

      describe('when secrets query fails', () => {
        const error = new Error('GraphQL error: Permission denied.');

        beforeEach(async () => {
          mockSecretsListResponse.mockRejectedValue(error);
          await createComponent({ context });
        });

        it('renders error message', () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: 'Permission denied.',
            captureError: true,
            error,
          });
        });
      });

      describe('delete secret modal', () => {
        describe('when deleting a secret', () => {
          beforeEach(async () => {
            mockSecretsListResponse.mockResolvedValue(mockSecretsResponse());
            await createComponent({ context });

            findDeleteButton(0).trigger('click');
            await nextTick();
          });

          it('shows delete modal when clicking on "Delete" action', () => {
            expect(findDeleteModal().props('showModal')).toBe(true);
          });

          it('refetches secrets and hides modal when secret is deleted', async () => {
            expect(mockSecretsListResponse).toHaveBeenCalledTimes(1);

            findDeleteModal().vm.$emit('refetch-secrets');
            await nextTick();

            expect(findDeleteModal().props('showModal')).toBe(false);
            expect(mockSecretsListResponse).toHaveBeenCalledTimes(2);
          });
        });

        describe('when re-opening the modal', () => {
          beforeEach(async () => {
            mockSecretsListResponse.mockResolvedValue(mockSecretsResponse());
            await createComponent({ context });
          });

          it('resets the secret name', async () => {
            findDeleteButton(0).trigger('click');
            await nextTick();

            expect(findDeleteModal().props('secretName')).toBe(secretsList[0].node.name);

            findDeleteModal().vm.$emit('hide');
            findDeleteButton(1).trigger('click');
            await nextTick();

            expect(findDeleteModal().props('secretName')).toBe(secretsList[1].node.name);
          });
        });
      });

      describe('health status', () => {
        beforeEach(async () => {
          mockSecretsListResponse.mockResolvedValue(mockSecretsResponse());
          await createComponent({ context });
        });

        it.each`
          index | text                 | variant      | tooltip
          ${0}  | ${'Healthy'}         | ${'success'} | ${'Secret created or updated successfully.'}
          ${1}  | ${'Needs attention'} | ${'danger'}  | ${'Secret creation failed. Delete the secret and try again.'}
          ${2}  | ${'Needs attention'} | ${'danger'}  | ${'Secret update failed. Retry the update or delete the secret.'}
          ${3}  | ${'Creating'}        | ${'neutral'} | ${'Secret is being created.'}
          ${4}  | ${'Updating'}        | ${'neutral'} | ${'Secret is being updated.'}
        `('renders $text status', ({ index, text, tooltip, variant }) => {
          expect(findSecretHealthStatus(index).text()).toBe(text);
          expect(findSecretHealthStatus(index).props('variant')).toBe(variant);
          expect(findSecretHealthStatus(index).attributes('title')).toBe(tooltip);
        });
      });

      describe('event tracking', () => {
        it('tracks page visit', async () => {
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          await createComponent({ context });

          expect(trackEventSpy).toHaveBeenCalledTimes(1);
          expect(trackEventSpy).toHaveBeenCalledWith(
            contextData.visitEventName,
            { label: 'secrets_table_page' },
            undefined,
          );
        });
      });
    },
  );

  describe.each`
    context           | secretsList               | mockSecretsResponse
    ${ENTITY_PROJECT} | ${mockProjectSecretsData} | ${mockProjectSecretsResponse}
    ${ENTITY_GROUP}   | ${mockGroupSecretsData}   | ${mockGroupSecretsResponse}
  `('secrets rotation in $context context', ({ context, secretsList, mockSecretsResponse }) => {
    describe('rotation alert banner', () => {
      it('renders when secrets need rotation', async () => {
        mockSecretsListResponse.mockResolvedValue(mockSecretsResponse());
        await createComponent({ context });

        expect(findSecretsAlertBanner().exists()).toBe(true);
      });

      it('does not render when no secrets need rotation', async () => {
        mockSecretsListResponse.mockResolvedValue(mockSecretsResponse());
        mockSecretsNeedingRotationResponse.mockResolvedValue({
          data: {
            secretsNeedingRotation: {
              nodes: [],
            },
          },
        });
        await createComponent({ context });
        await waitForPromises();

        expect(findSecretsAlertBanner().exists()).toBe(false);
      });
    });

    describe('rotation reminder icons', () => {
      it('shows warning icon for APPROACHING status', async () => {
        const approachingSecret = [secretsList[0]]; // First secret has APPROACHING status
        mockSecretsListResponse.mockResolvedValue(mockSecretsResponse(approachingSecret));
        await createComponent({ context });

        const approachingIcon = findRotationApproachingIcon();
        expect(approachingIcon.exists()).toBe(true);
        expect(approachingIcon.props('name')).toBe('warning');
        expect(approachingIcon.props('variant')).toBe('warning');
        expect(approachingIcon.attributes('title')).toBe(
          'Rotation reminder: This secret needs to be updated soon.',
        );
      });

      it('shows warning-solid icon for OVERDUE status', async () => {
        const overdueSecret = [secretsList[1]]; // Second secret has OVERDUE status
        mockSecretsListResponse.mockResolvedValue(mockSecretsResponse(overdueSecret));
        await createComponent({ context });

        const overdueIcon = findRotationOverdueIcon();
        expect(overdueIcon.exists()).toBe(true);
        expect(overdueIcon.props('name')).toBe('warning-solid');
        expect(overdueIcon.props('variant')).toBe('danger');
        expect(overdueIcon.attributes('title')).toBe('Rotation overdue');
      });

      it('does not show rotation icons when no rotation info', async () => {
        const secretWithNoRotation = [secretsList[2]]; // third secret has no rotation status
        mockSecretsListResponse.mockResolvedValue(mockSecretsResponse(secretWithNoRotation));
        await createComponent({ context });

        expect(findRotationApproachingIcon().exists()).toBe(false);
        expect(findRotationOverdueIcon().exists()).toBe(false);
      });
    });

    describe('secretsNeedingRotation query', () => {
      beforeEach(() => {
        createAlert.mockClear();
      });

      it('fetches secrets needing rotation with correct variables', async () => {
        await createComponent({ context });

        expect(mockSecretsNeedingRotationResponse).toHaveBeenCalledWith({
          fullPath: 'path/to/entity',
        });
      });

      it('handles errors when fetching secrets needing rotation', async () => {
        const error = new Error('GraphQL error: API Error');
        mockSecretsNeedingRotationResponse = jest.fn().mockRejectedValue(error);

        await createComponent({ context });

        expect(createAlert).toHaveBeenCalledWith({
          message: 'API Error',
          captureError: true,
          error,
        });
      });
    });
  });

  describe('when OpenBao is unhealthy', () => {
    beforeEach(async () => {
      mockSecretsListResponse.mockResolvedValue(mockProjectSecretsResponse());
      await createComponent({ context: ENTITY_PROJECT, isOpenbaoHealthy: false });
    });

    it('does not fetch secrets', () => {
      expect(mockSecretsListResponse).not.toHaveBeenCalled();
    });

    it('shows the empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });

    it('does not allow creating a new secret from the empty state', () => {
      expect(findEmptyState().props('canCreateSecret')).toBe(false);
    });

    it('does not show loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('when entitlement state is trial eligible', () => {
    beforeEach(async () => {
      // when the entitlement is trial-eligible, `SecretsApp` skips the status
      // query so status stays undefined in the child.
      await createComponent({
        entitlement: { state: ENTITLEMENT_STATE_TRIAL_ELIGIBLE },
        provide: { secretManagerStatus: undefined },
      });
    });

    it('renders the trial empty state', () => {
      expect(findTrialEmptyState().exists()).toBe(true);
    });

    it('does not render the secrets list empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render the feedback and documentation links', () => {
      expect(findFeedbackLink().exists()).toBe(false);
      expect(findDocumentationLink().exists()).toBe(false);
    });

    it('does not fetch secrets list and secrets needing rotation', () => {
      expect(mockSecretsListResponse).not.toHaveBeenCalled();
      expect(mockSecretsNeedingRotationResponse).not.toHaveBeenCalled();
    });
  });

  // Keep TLGs on the trial empty state while the onboarding chain is
  // waiting for provisioning to poll to ACTIVE. Without this, the entitlement
  // flips to TRIAL mid-chain and the user would see the empty state with a
  // "New secret" button they can't yet use.
  describe('when the TLG onboarding chain is in progress', () => {
    it('renders the trial empty state while polling for provisioning', async () => {
      await createComponent({
        entitlement: { state: 'TRIAL' },
        provide: { isTrialOnboarding: true, secretManagerStatus: 'PROVISIONING' },
      });

      expect(findTrialEmptyState().exists()).toBe(true);
      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe.each`
    status
    ${null}
    ${'PROVISIONING'}
    ${'DEPROVISIONING'}
    ${'INACTIVE'}
  `('when secrets manager status is $status', ({ status }) => {
    beforeEach(async () => {
      await createComponent({ secretManagerStatus: status });
    });

    it('does not fetch secrets list and secrets needing rotation', () => {
      expect(mockSecretsListResponse).not.toHaveBeenCalled();
      expect(mockSecretsNeedingRotationResponse).not.toHaveBeenCalled();
    });

    it('renders the empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
    });
  });

  describe('secret details in project context', () => {
    beforeEach(async () => {
      mockSecretsListResponse.mockResolvedValue(mockProjectSecretsResponse());
      await createComponent({ context: ENTITY_PROJECT });
    });

    it('renders branches correctly', () => {
      expect(findSecretBranchesRow(0).text()).toBe('All (default)');
      expect(findSecretBranchesRow(1).text()).toBe('main');
    });

    it('renders environments correctly', () => {
      expect(findSecretEnvironmentsRow(0).props('title')).toBe('env::All (default)');
      expect(findSecretEnvironmentsRow(1).props('title')).toBe('env::canary');
    });
  });

  describe.each`
    context           | mockSecretsResponse
    ${ENTITY_PROJECT} | ${mockProjectSecretsResponse}
    ${ENTITY_GROUP}   | ${mockGroupSecretsResponse}
  `('read only mode in $context context', ({ context, mockSecretsResponse }) => {
    beforeEach(async () => {
      mockSecretsListResponse.mockResolvedValue(mockSecretsResponse());
      await createComponent({ context, provide: { isReadOnly: true } });
    });

    it('hides create button', () => {
      expect(findNewSecretButton().exists()).toBe(false);
    });

    it('hides actions column', () => {
      expect(findSecretActionsCell().exists()).toBe(false);
    });
  });
});
