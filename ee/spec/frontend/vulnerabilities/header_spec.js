import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlButton } from '@gitlab/ui';
import { shallowMount, createWrapper as createWrapperWithUtil } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { sendDuoChatCommand } from 'ee/ai/utils';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResolveVulnerability from 'ee/vulnerabilities/graphql/ai_resolve_vulnerability.mutation.graphql';
import Api from 'ee/api';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import vulnerabilityStateMutations from 'ee/security_dashboard/graphql/mutate_vulnerability_state';
import vulnerabilitiesSeverityOverrideMutation from 'ee/security_dashboard/graphql/mutations/vulnerabilities_severity_override.mutation.graphql';
import VulnerabilityActionsDropdown from 'ee/vulnerabilities/components/vulnerability_actions_dropdown.vue';
import StatusBadge from 'ee/vue_shared/security_reports/components/status_badge.vue';
import Header, {
  CLIENT_SUBSCRIPTION_ID,
  VULNERABILITY_STATE_MODAL_ID,
  VULNERABILITY_SEVERITY_MODAL_ID,
} from 'ee/vulnerabilities/components/header.vue';
import ResolutionAlert from 'ee/vulnerabilities/components/resolution_alert.vue';
import StatusDescription from 'ee/vulnerabilities/components/status_description.vue';
import StateModal from 'ee/vulnerabilities/components/state_modal.vue';
import SeverityModal from 'ee/vulnerabilities/components/severity_modal.vue';
import {
  FEEDBACK_TYPES,
  VULNERABILITY_STATE_OBJECTS,
  FLAG_STATUSES,
} from 'ee/vulnerabilities/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import UsersMockHelper from 'helpers/user_mock_data_helper';
import waitForPromises from 'helpers/wait_for_promises';
import toast from '~/vue_shared/plugins/global_toast';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import download from '~/lib/utils/downloader';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { visitUrl } from '~/lib/utils/url_utility';
import getConfiguredFlows from 'ee/ai/graphql/get_configured_flows.query.graphql';

import {
  getVulnerabilityStatusMutationResponse,
  dismissalDescriptions,
  getAiSubscriptionResponse,
  AI_SUBSCRIPTION_ERROR_RESPONSE,
  MUTATION_AI_ACTION_DEFAULT_RESPONSE,
  MUTATION_AI_ACTION_GLOBAL_ERROR,
  MUTATION_AI_ACTION_ERROR,
} from './mock_data';

Vue.use(VueApollo);

const MOCK_SUBSCRIPTION_RESPONSE = getAiSubscriptionResponse(
  'http://gdk.test:3000/secure-ex/webgoat.net/-/merge_requests/5',
);
const vulnerabilityStateEntries = Object.entries(VULNERABILITY_STATE_OBJECTS);
const mockAxios = new MockAdapter(axios);
jest.mock('~/alert');
jest.mock('~/vue_shared/plugins/global_toast');
jest.mock('~/lib/utils/downloader');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn(),
}));
jest.mock('ee/ai/utils', () => ({ sendDuoChatCommand: jest.fn() }));

describe('Vulnerability Header', () => {
  let wrapper;

  const defaultVulnerability = {
    id: 1,
    createdAt: new Date().toISOString(),
    reportType: 'dast',
    state: 'detected',
    createMrUrl: '/create_mr_url',
    newIssueUrl: '/new_issue_url',
    uuid: 'xxxxxxxx-xxxx-5xxx-xxxx-xxxxxxxxxxxx',
    pipeline: {
      id: 2,
      createdAt: new Date().toISOString(),
      url: 'pipeline_url',
      sourceBranch: 'main',
    },
    latestFlag: {
      confidenceScore: 0.95,
    },
    description: 'description',
    identifiers: 'identifiers',
    links: 'links',
    location: 'location',
    name: 'name',
    project: { id: 123 },
    mergeRequestLinks: [],
    stateTransitions: [],
  };

  const diff = 'some diff to download';

  const getVulnerability = ({
    canCreateMergeRequest,
    canDownloadPatch,
    canResolveWithSingleShotAi,
    canExplainWithAi,
    aiResolutionEnabled,
    canAdmin = true,
    latestFlag = null,
    reportType = 'dast',
    duoSastVrWorkflowEnabled = false,
    project = { id: 123 },
    ...otherProperties
  } = {}) => ({
    remediations: canCreateMergeRequest || canDownloadPatch ? [{ diff }] : null,
    state: canDownloadPatch ? 'detected' : 'resolved',
    mergeRequestLinks: canCreateMergeRequest || canDownloadPatch ? [] : [{}],
    mergeRequestFeedback: canCreateMergeRequest ? null : {},
    aiResolutionAvailable: canResolveWithSingleShotAi,
    aiExplanationAvailable: canExplainWithAi,
    aiResolutionEnabled,
    canAdmin,
    latestFlag,
    reportType,
    duoSastVrWorkflowEnabled,
    project,
    ...(canDownloadPatch && canCreateMergeRequest === undefined ? { createMrUrl: '' } : {}),
    ...otherProperties,
  });

  const getConfiguredFlowsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiCatalogConfiguredItems: {
        nodes: [],
      },
    },
  });

  const createApolloProvider = (...queries) => {
    // Provide default mock for getConfiguredFlows to prevent unwanted error alerts
    const hasConfiguredFlowsHandler = queries.some(([query]) => query === getConfiguredFlows);
    const defaultQueries = hasConfiguredFlowsHandler
      ? queries
      : [[getConfiguredFlows, getConfiguredFlowsSuccessHandler], ...queries];
    return createMockApollo(defaultQueries);
  };

  const createRandomUser = () => {
    const user = UsersMockHelper.createRandomUser();
    const url = Api.buildUrl(Api.userPath).replace(':id', user.id);
    mockAxios.onGet(url).replyOnce(HTTP_STATUS_OK, user);

    return user;
  };

  const findStatusBadge = () => wrapper.findComponent(StatusBadge);
  const findActionsDropdown = () => wrapper.findComponent(VulnerabilityActionsDropdown);
  const findResolutionAlert = () => wrapper.findComponent(ResolutionAlert);
  const findStatusDescription = () => wrapper.findComponent(StatusDescription);
  const findChangeStatusButton = () => wrapper.findComponent(GlButton);
  const findStateModal = () => wrapper.findComponent(StateModal);
  const findSeverityModal = () => wrapper.findComponent(SeverityModal);
  const findEditVulnerabilityDropdown = () => wrapper.findComponent(GlDisclosureDropdown);

  const changeStatus = ({ action, dismissalReason, comment }) => {
    findStateModal().vm.$emit('change', { action, dismissalReason, comment });
  };

  const createWrapper = ({
    vulnerability = {},
    apolloProvider,
    glAbilities,
    hideVulnerabilitySeverityOverride = false,
    glFeatures = {},
    duoAgentPlatformAvailable = true,
    duoSecretDetectionFpEnabled = true,
    duoSastFalsePositiveDetectionEnabled = true,
  }) => {
    wrapper = shallowMount(Header, {
      apolloProvider,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
        GlModal: createMockDirective('gl-modal'),
      },
      propsData: {
        vulnerability: {
          ...defaultVulnerability,
          ...vulnerability,
        },
      },
      provide: {
        dismissalDescriptions,
        duoAgentPlatformAvailable,
        duoSecretDetectionFpEnabled,
        duoSastFalsePositiveDetectionEnabled,
        glAbilities: {
          resolveVulnerabilityWithAi: true,
          ...glAbilities,
        },
        glFeatures: {
          hideVulnerabilitySeverityOverride,
          ...glFeatures,
        },
      },
      stubs: {
        GlDisclosureDropdown,
      },
    });
  };

  afterEach(() => {
    mockAxios.reset();
    createAlert.mockReset();
  });

  // Resolution Alert
  describe('the vulnerability is no longer detected on the default branch', () => {
    const branchName = 'main';

    beforeEach(() => {
      createWrapper({
        vulnerability: {
          resolvedOnDefaultBranch: true,
          projectDefaultBranch: branchName,
        },
      });
    });

    it('should show the resolution alert component', () => {
      expect(findResolutionAlert().exists()).toBe(true);
    });

    it('should pass down the default branch name', () => {
      expect(findResolutionAlert().props('defaultBranchName')).toEqual(branchName);
    });

    it('should not show the alert component when the vulnerability is resolved', async () => {
      createWrapper({
        vulnerability: {
          state: 'resolved',
        },
      });
      await nextTick();
      const alert = findResolutionAlert();

      expect(alert.exists()).toBe(false);
    });
  });

  describe('status description', () => {
    it('the status description is rendered and passed the correct data', async () => {
      const user = createRandomUser();

      const vulnerability = {
        ...defaultVulnerability,
        state: 'confirmed',
        confirmedById: user.id,
      };

      createWrapper({ vulnerability });

      await waitForPromises();
      expect(findStatusDescription().exists()).toBe(true);

      expect(findStatusDescription().props()).toEqual({
        vulnerability,
        user,
        isLoadingVulnerability: false,
        isLoadingUser: false,
        isStatusBolded: false,
      });
    });

    it.each(vulnerabilityStateEntries)(
      `loads the correct user for the vulnerability state "%s"`,
      async (state) => {
        const user = createRandomUser();
        createWrapper({ vulnerability: { state, [`${state}ById`]: user.id } });

        await waitForPromises();
        expect(mockAxios.history.get).toHaveLength(1);
        expect(findStatusDescription().props('user')).toEqual(user);
      },
    );

    it('does not load a user if there is no user ID', async () => {
      createWrapper({ vulnerability: { state: 'detected' } });

      await waitForPromises();
      expect(mockAxios.history.get).toHaveLength(0);
      expect(findStatusDescription().props('user')).toBeUndefined();
    });

    it('will show an error when the user cannot be loaded', async () => {
      createWrapper({ vulnerability: { state: 'confirmed', confirmedById: 1 } });

      mockAxios.onGet().replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);
      await waitForPromises();
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(mockAxios.history.get).toHaveLength(1);
    });

    it('will set the isLoadingUser property correctly when the user is loading and finished loading', async () => {
      const user = createRandomUser();
      createWrapper({ vulnerability: { state: 'confirmed', confirmedById: user.id } });

      expect(findStatusDescription().props('isLoadingUser')).toBe(true);

      await waitForPromises();
      expect(mockAxios.history.get).toHaveLength(1);
      expect(findStatusDescription().props('isLoadingUser')).toBe(false);
    });
  });

  // "Edit vulnerability" dropdown when ff `vulnerability_severity_override` is enabled
  describe('"Edit vulnerability" dropdown', () => {
    it.each`
      index | name                 | modal
      ${0}  | ${'Change status'}   | ${VULNERABILITY_STATE_MODAL_ID}
      ${1}  | ${'Change severity'} | ${VULNERABILITY_SEVERITY_MODAL_ID}
    `('contains a "$name" item that opens the $modal on click', ({ index, name, modal }) => {
      createWrapper({ vulnerability: getVulnerability() });
      const rootWrapper = createWrapperWithUtil(wrapper.vm.$root);

      const dropdownItem = wrapper
        .findAllComponents(GlDisclosureDropdownItem)
        .at(index)
        .props('item');

      expect(dropdownItem.text).toBe(name);

      dropdownItem.action();

      expect(rootWrapper.emitted(BV_SHOW_MODAL)).toStrictEqual([[modal]]);
    });

    it('is disabled when user cannot admin vulnerability', () => {
      createWrapper({ vulnerability: getVulnerability({ canAdmin: false }) });

      expect(findEditVulnerabilityDropdown().props('disabled')).toBe(true);
    });

    describe('severity change', () => {
      const featureFlags = {
        hideVulnerabilitySeverityOverride: false,
      };

      describe('when API call is successful', () => {
        beforeEach(() => {
          const apolloProvider = createApolloProvider([
            vulnerabilitiesSeverityOverrideMutation,
            jest.fn().mockResolvedValue({
              data: {
                vulnerabilitiesSeverityOverride: {
                  errors: [],
                  vulnerabilities: [
                    {
                      id: 1,
                      severity: 'HIGH',
                    },
                  ],
                },
              },
            }),
          ]);

          createWrapper({
            vulnerability: getVulnerability({ severity: 'info' }),
            apolloProvider,
            ...featureFlags,
          });
        });

        it('dropdown is loading during GraphQL call', async () => {
          findSeverityModal().vm.$emit('change', { newSeverity: 'high' });
          await nextTick();

          expect(findEditVulnerabilityDropdown().props('loading')).toBe(true);
        });

        it(`emits the updated vulnerability, shows a toast`, async () => {
          findSeverityModal().vm.$emit('change', { newSeverity: 'high' });
          await waitForPromises();

          expect(wrapper.emitted('vulnerability-severity-change')[0][0]).toMatchObject({
            ...getVulnerability(),
            severity: 'high',
          });
          expect(toast).toHaveBeenCalledWith('Vulnerability set to high severity');
        });

        it('dropdown is not loading after GraphQL call', async () => {
          findSeverityModal().vm.$emit('change', { newSeverity: 'high' });
          await waitForPromises();

          expect(findEditVulnerabilityDropdown().props('loading')).toBe(false);
        });
      });

      describe('when API call fails', () => {
        beforeEach(() => {
          const apolloProvider = createApolloProvider([
            vulnerabilitiesSeverityOverrideMutation,
            jest.fn().mockRejectedValue({
              data: {
                vulnerabilitiesSeverityOverride: {
                  errors: [{ message: 'Something went wrong' }],
                  vulnerability: {},
                },
              },
            }),
          ]);

          createWrapper({ apolloProvider, ...featureFlags });
        });

        it('shows an error message, sends the error to sentry', async () => {
          const sentryCaptureException = jest.spyOn(Sentry, 'captureException');
          findSeverityModal().vm.$emit('change', { newSeverity: 'high' });

          await waitForPromises();

          expect(sentryCaptureException).toHaveBeenCalledWith(expect.any(Error));
          expect(createAlert).toHaveBeenCalledTimes(1);
        });
      });
    });
  });

  describe('state modal', () => {
    // "Change status" button when ff `vulnerability_severity_override` is disabled
    describe('change status button', () => {
      const featureFlags = {
        hideVulnerabilitySeverityOverride: true,
      };

      beforeEach(() => {
        createWrapper({
          vulnerability: getVulnerability(),
          ...featureFlags,
        });
      });

      it('renders enabled "Change status" button', () => {
        const button = findChangeStatusButton();
        expect(button.text()).toBe('Change status');
        expect(button.props('disabled')).toBe(false);
      });

      it('renders the disabled change status button when user can not admin the vulnerability', () => {
        createWrapper({
          vulnerability: getVulnerability({ canAdmin: false }),
          ...featureFlags,
        });

        expect(findChangeStatusButton().props('disabled')).toBe(true);
      });

      it('checks that button and modal are connected', () => {
        const buttonModalDirective = getBinding(findChangeStatusButton().element, 'gl-modal');
        const modalId = findStateModal().props('modalId');

        expect(buttonModalDirective.value).toBe(VULNERABILITY_STATE_MODAL_ID);
        expect(modalId).toBe(VULNERABILITY_STATE_MODAL_ID);
      });

      it('passes props to state drawer', () => {
        createWrapper({
          vulnerability: getVulnerability({
            state: 'dismissed',
            stateTransitions: [{ comment: 'test comment', dismissalReason: 'mitigating_control' }],
          }),
        });

        expect(findStateModal().props()).toMatchObject({
          state: 'dismissed',
          dismissalReason: 'mitigating_control',
          comment: 'test comment',
        });
      });
    });

    // modal behavior whether ff is true or false
    describe.each`
      vulnerabilitySeverityOverride | findLoadingElement
      ${true}                       | ${findEditVulnerabilityDropdown}
      ${false}                      | ${findStatusBadge}
    `(
      'when vulnerability_severity_override is $vulnerabilitySeverityOverride',
      ({ vulnerabilitySeverityOverride, findLoadingElement }) => {
        const featureFlags = {
          hideVulnerabilitySeverityOverride: !vulnerabilitySeverityOverride,
        };

        describe.each`
          payload                  | queryName                          | expected
          ${{ action: 'dismiss' }} | ${'vulnerabilityDismiss'}          | ${'dismissed'}
          ${{ action: 'confirm' }} | ${'vulnerabilityConfirm'}          | ${'confirmed'}
          ${{ action: 'resolve' }} | ${'vulnerabilityResolve'}          | ${'resolved'}
          ${{ action: 'revert' }}  | ${'vulnerabilityRevertToDetected'} | ${'detected'}
        `('state drawer change', ({ payload, queryName, expected }) => {
          describe('when API call is successful', () => {
            beforeEach(() => {
              const apolloProvider = createApolloProvider([
                vulnerabilityStateMutations[payload.action],
                jest
                  .fn()
                  .mockResolvedValue(getVulnerabilityStatusMutationResponse(queryName, expected)),
              ]);

              createWrapper({ apolloProvider, ...featureFlags });
            });

            it('status badge is loading during GraphQL call', async () => {
              changeStatus(payload);
              await nextTick();

              expect(findLoadingElement().props('loading')).toBe(true);
            });

            it(`emits the updated vulnerability properly - ${payload.action}`, async () => {
              changeStatus(payload);
              await waitForPromises();

              expect(wrapper.emitted('vulnerability-state-change')[0][0]).toMatchObject({
                state: expected,
              });
            });

            it(`emits an event when the state is changed - ${payload.action}`, async () => {
              changeStatus(payload);
              await waitForPromises();

              expect(wrapper.emitted()['vulnerability-state-change']).toHaveLength(1);
            });

            it('status badge is not loading after GraphQL call', async () => {
              changeStatus(payload);
              await waitForPromises();

              expect(findLoadingElement().props('loading')).toBe(false);
            });
          });

          describe('when API call fails', () => {
            beforeEach(() => {
              const apolloProvider = createApolloProvider([
                vulnerabilityStateMutations[payload.action],
                jest.fn().mockRejectedValue({
                  data: {
                    [queryName]: {
                      errors: [{ message: 'Something went wrong' }],
                      vulnerability: {},
                    },
                  },
                }),
              ]);

              createWrapper({ apolloProvider, ...featureFlags });
            });

            it('shows an error message', async () => {
              changeStatus(payload);
              await waitForPromises();

              expect(createAlert).toHaveBeenCalledTimes(1);
            });
          });
        });
      },
    );
  });

  describe('actions dropdown', () => {
    it.each([true, false])('passes the correct props to the dropdown', (actionsEnabled) => {
      createWrapper({
        vulnerability: getVulnerability({
          canCreateMergeRequest: actionsEnabled,
          canDownloadPatch: actionsEnabled,
          canResolveWithSingleShotAi: actionsEnabled,
          canExplainWithAi: actionsEnabled,
          aiResolutionEnabled: actionsEnabled,
          duoSastVrWorkflowEnabled: actionsEnabled,
          latestFlag: actionsEnabled ? null : { confidenceScore: 0.95 },
        }),
        glAbilities: {
          resolveVulnerabilityWithAi: actionsEnabled,
        },
        duoAgentPlatformAvailable: actionsEnabled,
        glFeatures: {
          agenticSastVrUi: actionsEnabled,
        },
      });

      expect(findActionsDropdown().props()).toMatchObject({
        loading: false,
        showDownloadPatch: actionsEnabled,
        showCreateMergeRequest: actionsEnabled,
        showResolveWithSingleShotAi: actionsEnabled,
        showResolveWithAgenticAi: actionsEnabled,
        showExplainWithAi: actionsEnabled,
        aiResolutionEnabled: actionsEnabled,
      });
    });

    const clickButton = (eventName) => {
      findActionsDropdown().vm.$emit(eventName);
      return waitForPromises();
    };

    describe('resolve with scanner suggestion button', () => {
      beforeEach(async () => {
        createWrapper({
          vulnerability: getVulnerability({
            ...defaultVulnerability,
            canCreateMergeRequest: true,
          }),
        });
        await waitForPromises();
      });

      it('submits correct data for creating a merge request', async () => {
        const mergeRequestPath = '/group/project/merge_request/123';
        mockAxios.onPost(defaultVulnerability.createMrUrl).reply(HTTP_STATUS_OK, {
          merge_request_path: mergeRequestPath,
          merge_request_links: [{ merge_request_path: mergeRequestPath }],
        });
        await clickButton('create-merge-request');

        expect(visitUrl).toHaveBeenCalledWith(mergeRequestPath);
        expect(mockAxios.history.post).toHaveLength(1);
        expect(JSON.parse(mockAxios.history.post[0].data)).toMatchObject({
          vulnerability_feedback: {
            feedback_type: FEEDBACK_TYPES.MERGE_REQUEST,
            category: defaultVulnerability.reportType,
            finding_uuid: defaultVulnerability.uuid,
            vulnerability_data: {
              ...convertObjectPropsToSnakeCase(defaultVulnerability),
              category: defaultVulnerability.reportType,
              target_branch: defaultVulnerability.pipeline.sourceBranch,
            },
          },
        });
      });

      it('shows an error message when merge request creation fails', async () => {
        mockAxios
          .onPost(defaultVulnerability.create_mr_url)
          .reply(HTTP_STATUS_INTERNAL_SERVER_ERROR);
        await clickButton('create-merge-request');

        expect(mockAxios.history.post).toHaveLength(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was an error creating the merge request. Please try again.',
        });
      });
    });

    describe('download patch button', () => {
      beforeEach(() => {
        createWrapper({
          vulnerability: getVulnerability({
            canDownloadPatch: true,
          }),
        });
      });

      it('calls download utility correctly', async () => {
        await clickButton('download-patch');

        expect(download).toHaveBeenCalledWith({
          fileData: diff,
          fileName: `remediation.patch`,
        });
      });
    });

    describe('explain with AI button', () => {
      beforeEach(() => {
        createWrapper({
          vulnerability: getVulnerability(),
        });
      });

      it('calls sendDuoChatCommand with the correct parameters when clicked', async () => {
        expect(sendDuoChatCommand).not.toHaveBeenCalled();

        await clickButton('explain-vulnerability');

        expect(sendDuoChatCommand).toHaveBeenCalledWith({
          question: '/vulnerability_explain',
          resourceId: `gid://gitlab/Vulnerability/${defaultVulnerability.id}`,
          agenticPrompt:
            'Explain this vulnerability and provide insights about potential solutions.',
        });
      });
    });

    describe('resolve with AI button', () => {
      let mockSubscription;
      let subscriptionSpy;

      const createWrapperWithAiApollo = ({
        mutationResponse = MUTATION_AI_ACTION_DEFAULT_RESPONSE,
      } = {}) => {
        mockSubscription = createMockSubscription();
        subscriptionSpy = jest.fn().mockReturnValue(mockSubscription);

        const apolloProvider = createApolloProvider([aiResolveVulnerability, mutationResponse]);
        apolloProvider.defaultClient.setRequestHandler(aiResponseSubscription, subscriptionSpy);

        createWrapper({
          vulnerability: getVulnerability(),
          apolloProvider,
        });

        return waitForPromises();
      };

      const createWrapperAndClickButton = (params) => {
        createWrapperWithAiApollo(params);

        return clickButton('resolve-vulnerability');
      };

      const sendSubscriptionMessage = (aiCompletionResponse) => {
        mockSubscription.next({ data: { aiCompletionResponse } });
        return waitForPromises();
      };

      // When the subscription is ready, a null aiCompletionResponse is sent
      const waitForSubscriptionToBeReady = () => sendSubscriptionMessage(null);

      beforeEach(() => {
        gon.current_user_id = 1;
      });

      it('continues to show the loading state into the redirect call', async () => {
        await createWrapperWithAiApollo();

        const resolveAIButton = findActionsDropdown();
        expect(resolveAIButton.props('loading')).toBe(false);

        await clickButton('resolve-vulnerability');
        expect(resolveAIButton.props('loading')).toBe(true);

        await waitForSubscriptionToBeReady();
        expect(resolveAIButton.props('loading')).toBe(true);

        await sendSubscriptionMessage(MOCK_SUBSCRIPTION_RESPONSE);
        expect(resolveAIButton.props('loading')).toBe(true);
        expect(visitUrl).toHaveBeenCalledTimes(1);
      });

      it('redirects after it receives the AI response', async () => {
        await createWrapperAndClickButton();
        await waitForSubscriptionToBeReady();
        expect(visitUrl).not.toHaveBeenCalled();

        await sendSubscriptionMessage(MOCK_SUBSCRIPTION_RESPONSE);
        expect(visitUrl).toHaveBeenCalledTimes(1);
        expect(visitUrl).toHaveBeenCalledWith(MOCK_SUBSCRIPTION_RESPONSE.content);
      });

      it('calls the mutation with the correct input', async () => {
        await createWrapperAndClickButton();
        await waitForSubscriptionToBeReady();

        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).toHaveBeenCalledWith({
          resourceId: 'gid://gitlab/Vulnerability/1',
          clientSubscriptionId: CLIENT_SUBSCRIPTION_ID,
        });
      });

      it.each`
        type                    | mutationResponse                       | subscriptionMessage               | expectedError
        ${'mutation global'}    | ${MUTATION_AI_ACTION_GLOBAL_ERROR}     | ${null}                           | ${'mutation global error'}
        ${'mutation ai action'} | ${MUTATION_AI_ACTION_ERROR}            | ${null}                           | ${'mutation ai action error'}
        ${'subscription'}       | ${MUTATION_AI_ACTION_DEFAULT_RESPONSE} | ${AI_SUBSCRIPTION_ERROR_RESPONSE} | ${'subscription error'}
      `(
        'unsubscribes and shows only an error when there is a $type error',
        async ({ mutationResponse, subscriptionMessage, expectedError }) => {
          await createWrapperAndClickButton({ mutationResponse });
          await waitForSubscriptionToBeReady();
          await sendSubscriptionMessage(subscriptionMessage);

          expect(findActionsDropdown().props('loading')).toBe(false);
          expect(visitUrl).not.toHaveBeenCalled();
          expect(createAlert.mock.calls[0][0].message.toString()).toContain(expectedError);
        },
      );

      it('starts the subscription, waits for the subscription to be ready, then runs the mutation', async () => {
        await createWrapperWithAiApollo({
          canCreateMergeRequest: true,
          canDownloadPatch: true,
        });
        await clickButton('resolve-vulnerability');
        expect(subscriptionSpy).toHaveBeenCalled();
        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).not.toHaveBeenCalled();

        await waitForSubscriptionToBeReady();
        expect(MUTATION_AI_ACTION_DEFAULT_RESPONSE).toHaveBeenCalled();
      });
    });

    describe('show-public-project warning', () => {
      it.each([true, false])(
        'passes "vulnerability.belongsToPublicProject" prop to the component',
        (belongsToPublicProject) => {
          createWrapper({
            vulnerability: {
              belongsToPublicProject,
            },
          });

          expect(findActionsDropdown().props('showPublicProjectWarning')).toBe(
            belongsToPublicProject,
          );
        },
      );
    });

    describe('agentic resolve vulnerability button', () => {
      beforeEach(() => {
        createWrapper({
          vulnerability: {
            ...defaultVulnerability,
            project: {
              id: 456,
              fullPath: 'gitlab-org/gitlab',
            },
            latestFlag: null,
          },
        });
      });

      it('calls Api.triggerVulnerabilityResolution with correct parameters', async () => {
        const apiResponse = { id: 789, status: 'running' };
        jest.spyOn(Api, 'triggerVulnerabilityResolution').mockResolvedValue({ data: apiResponse });

        await clickButton('agentic-resolve-vulnerability');

        expect(Api.triggerVulnerabilityResolution).toHaveBeenCalledWith(
          defaultVulnerability.id,
          456,
          null,
        );
      });

      it('shows a success alert with a link to the agent session', async () => {
        const apiResponse = { id: 789, status: 'running' };
        jest.spyOn(Api, 'triggerVulnerabilityResolution').mockResolvedValue({ data: apiResponse });

        await clickButton('agentic-resolve-vulnerability');

        expect(createAlert).toHaveBeenCalledWith({
          variant: 'success',
          message: 'You can track the progress in the AI session via Automate → Sessions.',
          primaryButton: {
            text: 'View agent session',
            link: '/gitlab-org/gitlab/-/automate/agent-sessions/789',
          },
        });
      });

      it('shows an error alert when the API call fails', async () => {
        const error = new Error('API Error');
        jest.spyOn(Api, 'triggerVulnerabilityResolution').mockRejectedValue(error);

        await clickButton('agentic-resolve-vulnerability');

        expect(createAlert).toHaveBeenCalledWith({
          captureError: true,
          error,
          message: 'Something went wrong, could not start Duo agent session.',
        });
      });

      describe('when vulnerability is a false positive', () => {
        beforeEach(() => {
          createWrapper({
            vulnerability: {
              ...defaultVulnerability,
              project: {
                id: 456,
                fullPath: 'gitlab-org/gitlab',
              },
              latestFlag: {
                status: FLAG_STATUSES.DETECTED_AS_FP,
                origin: 'ai_sast_fp_detection',
              },
            },
          });
        });

        it('does not render resolve vulnerability button', () => {
          expect(findActionsDropdown().props('showResolveWithSingleShotAi')).toBe(false);
        });
      });
    });
  });

  describe('AI false positive detection', () => {
    const vulnerability = getVulnerability({
      canAdmin: true,
      reportType: 'sast',
      latestFlag: null,
      project: { id: 456, fullPath: 'gitlab-org/gitlab' },
      id: 789,
    });

    beforeEach(() => {
      gon.api_version = 'v4';
      createWrapper({
        vulnerability,
      });
    });

    describe('when duoSastFalsePositiveDetectionEnabled is false', () => {
      beforeEach(() => {
        gon.api_version = 'v4';
        createWrapper({
          vulnerability,
          duoSastFalsePositiveDetectionEnabled: false,
        });
      });

      it('does not show the AI false positive detection button', () => {
        expect(findActionsDropdown().props('canRunAiFalsePositiveDetection')).toBe(false);
      });
    });

    it('calls Api.triggerFalsePositiveDetection with correct parameters', async () => {
      const apiResponse = { workload: { id: 'workflow-123', status: 'running' } };
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(Api.triggerFalsePositiveDetection).toHaveBeenCalledWith(vulnerability.id, 456, null);
    });

    it('shows success alert when API call succeeds', async () => {
      const apiResponse = { id: 'workflow-123', status: 'running' };
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        variant: 'success',
        message: 'GitLab Duo False Positive Detection workflow started successfully',
        primaryButton: {
          text: 'View agent session',
          link: '/gitlab-org/gitlab/-/automate/agent-sessions/workflow-123',
        },
      });
    });

    it('shows error alert when API call fails', async () => {
      const errorMessage = 'Something went wrong';
      const error = new Error('API Error');
      error.response = { data: { message: errorMessage } };
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockRejectedValue(error);

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        captureError: true,
        error,
      });
    });

    it('shows generic error when no specific error message is available', async () => {
      const error = new Error('Network Error');
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockRejectedValue(error);

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error occurred when starting the AI False Positive Detection workflow.',
        captureError: true,
        error,
      });
    });

    it('handles workload error in response data', async () => {
      const workloadError = 'Workload processing failed';
      const apiResponse = { workload: { id: null, message: workloadError } };
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: workloadError,
        captureError: true,
        error: expect.any(Error),
      });
    });

    it('sets and clears isProcessingAction state correctly', async () => {
      expect(findActionsDropdown().props('loading')).toBe(false);

      const pendingPromise = new Promise(() => {});
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockReturnValue(pendingPromise);

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await nextTick();

      expect(findActionsDropdown().props('loading')).toBe(true);
    });

    it('skips Apollo query when project.id is not available', async () => {
      const queryMock = jest.fn();
      const apolloProvider = createApolloProvider([getConfiguredFlows, queryMock]);

      const vulnerabilityWithoutProjectId = {
        ...vulnerability,
        project: {}, // No id property
      };

      createWrapper({
        vulnerability: vulnerabilityWithoutProjectId,
        apolloProvider,
      });

      await waitForPromises();

      const apiResponse = { workload: { id: 'workflow-123', status: 'running' } };
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(queryMock).not.toHaveBeenCalled();
      expect(Api.triggerFalsePositiveDetection).toHaveBeenCalledWith(
        vulnerabilityWithoutProjectId.id,
        undefined,
        null,
      );
    });

    it('passes aiCatalogItemConsumerId to API when available', async () => {
      const apolloProvider = createApolloProvider([
        getConfiguredFlows,
        jest.fn().mockResolvedValue({
          data: {
            aiCatalogConfiguredItems: {
              nodes: [{ id: 'gid://gitlab/Ai::Catalog::ItemConsumer/123' }],
            },
          },
        }),
      ]);

      createWrapper({
        vulnerability,
        apolloProvider,
      });

      await waitForPromises();

      const apiResponse = { workload: { id: 'workflow-123', status: 'running' } };
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(Api.triggerFalsePositiveDetection).toHaveBeenCalledWith(vulnerability.id, 456, 123);
    });

    it('passes null aiCatalogItemConsumerId when Apollo query returns empty', async () => {
      const apolloProvider = createApolloProvider([
        getConfiguredFlows,
        jest.fn().mockResolvedValue({
          data: {
            aiCatalogConfiguredItems: {
              nodes: [],
            },
          },
        }),
      ]);

      createWrapper({
        vulnerability,
        apolloProvider,
      });

      await waitForPromises();

      const apiResponse = { workload: { id: 'workflow-123', status: 'running' } };
      jest.spyOn(Api, 'triggerFalsePositiveDetection').mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-ai-false-positive-detection');
      await waitForPromises();

      expect(Api.triggerFalsePositiveDetection).toHaveBeenCalledWith(vulnerability.id, 456, null);
    });

    it('handles Apollo query error gracefully', async () => {
      const apolloProvider = createApolloProvider([
        getConfiguredFlows,
        jest.fn().mockRejectedValue(new Error('Apollo error')),
      ]);

      const sentryCaptureException = jest.spyOn(Sentry, 'captureException');

      createWrapper({
        vulnerability,
        apolloProvider,
      });

      await waitForPromises();

      expect(sentryCaptureException).toHaveBeenCalledWith(expect.any(Error));
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong, could not fetch AI resolution configuration.',
      });
    });
  });

  describe('hasActiveFpDetection (status-based gating)', () => {
    const baseVulnerability = (reportType, latestFlag) =>
      getVulnerability({
        canAdmin: true,
        reportType,
        latestFlag,
        project: { id: 456 },
        id: 789,
      });

    const SAST_FEATURES = {};
    const SECRET_DETECTION_FEATURES = { duoSecretDetectionFalsePositive: true };

    const SAST_PROP = 'canRunAiFalsePositiveDetection';
    const SECRET_PROP = 'canRunSecretDetectionFalsePositiveDetection';

    describe.each`
      reportType            | features                     | propName
      ${'sast'}             | ${SAST_FEATURES}             | ${SAST_PROP}
      ${'secret_detection'} | ${SECRET_DETECTION_FEATURES} | ${SECRET_PROP}
    `('with FF enabled for $reportType', ({ reportType, features, propName }) => {
      describe.each`
        scenario                               | latestFlag                                                                      | expectedCanRun
        ${'no flag'}                           | ${null}                                                                         | ${true}
        ${'status DETECTED_AS_FP'}             | ${{ status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'ai_sast_fp_detection' }}     | ${false}
        ${'status DETECTED_AS_NOT_FP'}         | ${{ status: FLAG_STATUSES.DETECTED_AS_NOT_FP, origin: 'ai_sast_fp_detection' }} | ${false}
        ${'status NOT_STARTED'}                | ${{ status: FLAG_STATUSES.NOT_STARTED, origin: 'ai_sast_fp_detection' }}        | ${false}
        ${'status IN_PROGRESS'}                | ${{ status: FLAG_STATUSES.IN_PROGRESS, origin: 'ai_sast_fp_detection' }}        | ${false}
        ${'status FAILED'}                     | ${{ status: FLAG_STATUSES.FAILED, origin: 'ai_sast_fp_detection' }}             | ${false}
        ${'status DISMISSED'}                  | ${{ status: FLAG_STATUSES.DISMISSED, origin: 'ai_sast_fp_detection' }}          | ${true}
        ${'manual origin with active status'}  | ${{ status: FLAG_STATUSES.NOT_STARTED, origin: 'manual_legacy' }}               | ${true}
        ${'manual origin with DETECTED_AS_FP'} | ${{ status: FLAG_STATUSES.DETECTED_AS_FP, origin: 'manual_old' }}               | ${true}
      `('$scenario', ({ latestFlag, expectedCanRun }) => {
        beforeEach(() => {
          gon.api_version = 'v4';
          createWrapper({
            vulnerability: baseVulnerability(reportType, latestFlag),
            glFeatures: features,
          });
        });

        it(`sets the re-run-button prop to expected value`, () => {
          expect(findActionsDropdown().props(propName)).toBe(expectedCanRun);
        });
      });
    });
  });

  describe('Secret detection FP detection', () => {
    const vulnerability = getVulnerability({
      canAdmin: true,
      reportType: 'secret_detection',
      latestFlag: null,
      project: { id: 456, fullPath: 'gitlab-org/gitlab' },
      id: 789,
    });

    beforeEach(() => {
      gon.api_version = 'v4';
      createWrapper({
        vulnerability,
        glFeatures: { duoSecretDetectionFalsePositive: true },
      });
    });

    describe('when duoSecretDetectionFpEnabled is false', () => {
      beforeEach(() => {
        gon.api_version = 'v4';
        createWrapper({
          vulnerability,
          glFeatures: { duoSecretDetectionFalsePositive: true },
          duoSecretDetectionFpEnabled: false,
        });
      });

      it('does not show the secret detection false positive detection button', () => {
        expect(findActionsDropdown().props('canRunSecretDetectionFalsePositiveDetection')).toBe(
          false,
        );
      });
    });

    it('calls Api.triggerSecretDetectionFalsePositiveDetection with correct parameters', async () => {
      const apiResponse = { workload: { id: 'workflow-123', status: 'running' } };
      jest
        .spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection')
        .mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await waitForPromises();

      expect(Api.triggerSecretDetectionFalsePositiveDetection).toHaveBeenCalledWith(
        vulnerability.id,
        456,
        null,
      );
    });

    it('shows success alert when API call succeeds', async () => {
      const apiResponse = { id: 'workflow-123', workload: { id: 'workload-456' } };
      jest
        .spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection')
        .mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          variant: 'success',
          message: expect.stringContaining(
            'False Positive Detection workflow started successfully',
          ),
        }),
      );
    });

    it('shows error alert when API call fails', async () => {
      const errorMessage = 'Something went wrong';
      const error = new Error('API Error');
      error.response = { data: { message: errorMessage } };
      jest.spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection').mockRejectedValue(error);

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        captureError: true,
        error,
      });
    });

    it('shows generic error when no specific error message is available', async () => {
      const error = new Error('Network Error');
      jest.spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection').mockRejectedValue(error);

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Error occurred when starting the AI False Positive Detection workflow.',
        captureError: true,
        error,
      });
    });

    it('handles workload error in response data', async () => {
      const workloadError = 'Workload processing failed';
      const apiResponse = { workload: { id: null, message: workloadError } };
      jest
        .spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection')
        .mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: workloadError,
        captureError: true,
        error: expect.any(Error),
      });
    });

    it('sets and clears isProcessingAction state correctly', async () => {
      expect(findActionsDropdown().props('loading')).toBe(false);

      const pendingPromise = new Promise(() => {});
      jest
        .spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection')
        .mockReturnValue(pendingPromise);

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await nextTick();

      expect(findActionsDropdown().props('loading')).toBe(true);
    });

    it('passes secretDetectionAiCatalogItemConsumerId to API when available', async () => {
      const apolloProvider = createApolloProvider([
        getConfiguredFlows,
        jest.fn().mockResolvedValue({
          data: {
            aiCatalogConfiguredItems: {
              nodes: [{ id: 'gid://gitlab/Ai::Catalog::ItemConsumer/123' }],
            },
          },
        }),
      ]);

      createWrapper({
        vulnerability,
        apolloProvider,
        glFeatures: { duoSecretDetectionFalsePositive: true },
      });

      await waitForPromises();

      const apiResponse = { workload: { id: 'workflow-123', status: 'running' } };
      jest
        .spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection')
        .mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await waitForPromises();

      expect(Api.triggerSecretDetectionFalsePositiveDetection).toHaveBeenCalledWith(
        vulnerability.id,
        456,
        123,
      );
    });

    it('passes null secretDetectionAiCatalogItemConsumerId when Apollo query returns empty', async () => {
      const apolloProvider = createApolloProvider([
        getConfiguredFlows,
        jest.fn().mockResolvedValue({
          data: {
            aiCatalogConfiguredItems: {
              nodes: [],
            },
          },
        }),
      ]);

      createWrapper({
        vulnerability,
        apolloProvider,
        glFeatures: { duoSecretDetectionFalsePositive: true },
      });

      await waitForPromises();

      const apiResponse = { workload: { id: 'workflow-123', status: 'running' } };
      jest
        .spyOn(Api, 'triggerSecretDetectionFalsePositiveDetection')
        .mockResolvedValue({ data: apiResponse });

      findActionsDropdown().vm.$emit('run-secret-detection-false-positive-detection');
      await waitForPromises();

      expect(Api.triggerSecretDetectionFalsePositiveDetection).toHaveBeenCalledWith(
        vulnerability.id,
        456,
        null,
      );
    });

    it('handles Apollo query error gracefully', async () => {
      const apolloProvider = createApolloProvider([
        getConfiguredFlows,
        jest.fn().mockRejectedValue(new Error('Apollo error')),
      ]);

      const sentryCaptureException = jest.spyOn(Sentry, 'captureException');

      createWrapper({
        vulnerability,
        apolloProvider,
        glFeatures: { duoSecretDetectionFalsePositive: true },
      });

      await waitForPromises();

      expect(sentryCaptureException).toHaveBeenCalledWith(expect.any(Error));
    });
  });
});
