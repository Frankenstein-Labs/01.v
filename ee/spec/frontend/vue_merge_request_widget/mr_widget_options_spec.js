import MockAdapter from 'axios-mock-adapter';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription as createMockApolloSubscription } from 'mock-apollo-client';
import { GlSprintf } from '@gitlab/ui';

import readyToMergeResponse from 'test_fixtures/graphql/merge_requests/states/ready_to_merge.query.graphql.json';
import approvedByCurrentUser from 'test_fixtures/graphql/merge_requests/approvals/approvals.query.graphql.json';
import getStateQueryResponse from 'test_fixtures/graphql/merge_requests/get_state.query.graphql.json';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';

import MrWidgetOptions from 'ee/vue_merge_request_widget/mr_widget_options.vue';
import WidgetContainer from 'ee/vue_merge_request_widget/components/widget/app.vue';
import MrWidgetSecurityPolicyPipelineNote from 'ee/vue_merge_request_widget/components/mr_widget_security_policy_pipeline_note.vue';
import MrWidgetApprovals from 'ee_else_ce/vue_merge_request_widget/components/approvals/approvals.vue';
import mergeChecksQuery from '~/vue_merge_request_widget/queries/merge_checks.query.graphql';
import mergeChecksSubscription from '~/vue_merge_request_widget/queries/merge_checks.subscription.graphql';
import Loading from '~/vue_merge_request_widget/components/loading.vue';
import eventHub from '~/vue_merge_request_widget/event_hub';

import createMockApollo from 'helpers/mock_apollo_helper';
import { TEST_HOST } from 'helpers/test_constants';
import waitForPromises from 'helpers/wait_for_promises';

import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { SUCCESS } from '~/vue_merge_request_widget/components/deployment/constants';

// Force Jest to transpile and cache
// eslint-disable-next-line no-unused-vars
import _Deployment from '~/vue_merge_request_widget/components/deployment/deployment.vue';

import getStateQuery from 'ee/vue_merge_request_widget/queries/get_state.query.graphql';
import getStateSubscription from '~/vue_merge_request_widget/queries/get_state.subscription.graphql';
import readyToMergeSubscription from '~/vue_merge_request_widget/queries/states/ready_to_merge.subscription.graphql';
import readyToMergeQuery from '~/vue_merge_request_widget/queries/states/ready_to_merge.query.graphql';
import mergeQuery from '~/vue_merge_request_widget/queries/states/new_ready_to_merge.query.graphql';
import approvalsQuery from 'ee_else_ce/vue_merge_request_widget/components/approvals/queries/approvals.query.graphql';
import approvedBySubscription from 'ee_else_ce/vue_merge_request_widget/components/approvals/queries/approvals.subscription.graphql';
import blockingMergeRequestsQuery from 'ee/vue_merge_request_widget/queries/blocking_merge_requests.query.graphql';

import mockData from './mock_data';

jest.mock('~/vue_shared/components/help_popover.vue');

Vue.use(VueApollo);

describe('ee merge request widget options', () => {
  const allSubscriptions = {};
  let wrapper;
  let mock;

  const findWidgetContainer = () => wrapper.findComponent(WidgetContainer);
  const findApprovalsWidget = () => wrapper.findComponent(MrWidgetApprovals);
  const findPipelineContainer = () => wrapper.findComponentByTestId('pipeline-container');
  const findMergedPipelineContainer = () => wrapper.findByTestId('merged-pipeline-container');
  const findLoadingComponent = () => wrapper.findComponent(Loading);
  const findMergeError = () => wrapper.findByTestId('merge-error');
  const findManageStorageDocsLink = () => wrapper.findByText('manage your storage usage');
  const findSecurityPolicyPipelineNote = () =>
    wrapper.findComponent(MrWidgetSecurityPolicyPipelineNote);

  const createMergeChecksResponse = (checks = []) => ({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        mergeRequest: {
          id: 'gid://gitlab/MergeRequest/1',
          userPermissions: { canMerge: true },
          mergeabilityChecks: checks,
        },
      },
    },
  });

  const createComponent = ({
    mountFn = shallowMountExtended,
    updatedMrData = {},
    mergeChecks = [],
  } = {}) => {
    gl.mrWidgetData = { ...mockData, ...updatedMrData };
    const queryResponse = {
      data: {
        project: {
          ...getStateQueryResponse.data.project,
          mergeTrains: null,
          mergeRequest: {
            ...getStateQueryResponse.data.project.mergeRequest,
            mergeTrainCar: null,
          },
        },
      },
    };
    const queryHandlers = [
      [approvalsQuery, jest.fn().mockResolvedValue(approvedByCurrentUser)],
      [getStateQuery, jest.fn().mockResolvedValue(queryResponse)],
      [readyToMergeQuery, jest.fn().mockResolvedValue(readyToMergeResponse)],
      [
        mergeQuery,
        jest.fn().mockResolvedValue({
          data: {
            project: { id: 1, mergeRequest: { id: 1, userPermissions: { canMerge: true } } },
          },
        }),
      ],
      [
        blockingMergeRequestsQuery,
        jest.fn().mockResolvedValue({
          data: { project: { id: 1, mergeRequest: { id: 1, blockingMergeRequests: null } } },
        }),
      ],
      [mergeChecksQuery, jest.fn().mockResolvedValue(createMergeChecksResponse(mergeChecks))],
    ];
    const subscriptionHandlers = [
      [
        approvedBySubscription,
        () => {
          // Please see https://github.com/Mike-Gibson/mock-apollo-client/blob/c85746f1433b42af83ef6ca0d2904ccad6076666/README.md#multiple-subscriptions
          // for why subscriptions must be mocked this way, in this context
          // Note that the keyed object -> array structure is so that:
          //  A) when necessary, we can publish (.next) events into the stream
          //  B) we can do that by name (per subscription) rather than as a single array of all subscriptions
          const sym = Symbol.for('approvedBySubscription');
          const newSub = createMockApolloSubscription();
          const container = allSubscriptions[sym] || [];

          container.push(newSub);
          allSubscriptions[sym] = container;

          return newSub;
        },
      ],
      [getStateSubscription, () => createMockApolloSubscription()],
      [readyToMergeSubscription, () => createMockApolloSubscription()],
      [mergeChecksSubscription, () => createMockApolloSubscription()],
    ];
    const apolloProvider = createMockApollo(queryHandlers);

    subscriptionHandlers.forEach(([query, stream]) => {
      apolloProvider.defaultClient.setRequestHandler(query, stream);
    });

    wrapper = mountFn(MrWidgetOptions, {
      propsData: {
        mrData: {
          ...mockData,
          ...updatedMrData,
        },
      },
      stubs: { GlSprintf },
      apolloProvider,
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
    mock.onGet(mockData.merge_request_widget_path).reply(HTTP_STATUS_OK, {});
    mock.onGet(mockData.merge_request_cached_widget_path).reply(HTTP_STATUS_OK, {});
  });

  afterEach(() => {
    // This is needed because the `fetchInitialData` is triggered while
    // the `mock.restore` is trying to clean up, causing a bunch of
    // unmocked requests...
    // This is not ideal and will be cleaned up in
    // https://gitlab.com/gitlab-org/gitlab/-/issues/214032
    return waitForPromises().then(() => {
      wrapper.destroy();
      wrapper = null;
      mock.restore();
    });
  });

  describe('computed', () => {
    describe('shouldRenderApprovals', () => {
      it('should return false when in empty state', async () => {
        createComponent({
          updatedMrData: {
            has_approvals_available: true,
          },
        });
        await waitForPromises();

        wrapper.vm.mr = {
          ...wrapper.vm.mr,
          setGraphqlData: jest.fn(),
          state: 'nothingToMerge',
        };

        await nextTick();
        expect(findLoadingComponent().exists()).toBe(false);
        expect(findApprovalsWidget().exists()).toBe(false);
      });

      it('should return true when requiring approvals and in non-empty state', async () => {
        createComponent({
          updatedMrData: {
            has_approvals_available: true,
          },
        });
        await waitForPromises();

        wrapper.vm.mr = {
          ...wrapper.vm.mr,
          setGraphqlData: jest.fn(),
          state: 'readyToMerge',
        };

        await nextTick();
        expect(findApprovalsWidget().exists()).toBe(true);
      });
    });
  });

  describe('rendering deployments', () => {
    const deploymentMockData = {
      id: 15,
      name: 'review/diplo',
      url: '/root/acets-review-apps/environments/15',
      stop_url: '/root/acets-review-apps/environments/15/stop',
      external_url: 'http://diplo.',
      external_url_formatted: 'diplo.',
      deployed_at: '2017-03-22T22:44:42.258Z',
      deployed_at_formatted: 'Mar 22, 2017 10:44pm',
      status: SUCCESS,
    };

    const deploymentsMockData = [
      deploymentMockData,
      {
        ...deploymentMockData,
        id: deploymentMockData.id + 1,
      },
    ];

    it('renders multiple deployments container', async () => {
      createComponent({
        updatedMrData: {
          deployments: deploymentsMockData,
        },
      });
      await waitForPromises();
      expect(findPipelineContainer().exists()).toBe(true);
      expect(findPipelineContainer().props('mr').deployments).toEqual(deploymentsMockData);
      expect(findPipelineContainer().props('mr').postMergeDeployments).toHaveLength(0);
    });

    // gitlab:quarantine_issue_url=https://gitlab.com/gitlab-org/gitlab/-/issues/426129
    // eslint-disable-next-line jest/no-disabled-tests
    it.skip('renders multiple deployments', async () => {
      createComponent({
        mountFn: mountExtended,
        updatedMrData: {
          deployments: deploymentsMockData,
        },
      });
      await waitForPromises();
      expect(wrapper.findAll('.deploy-heading')).toHaveLength(2);
    });
  });

  describe('widget container', () => {
    it('renders the widget container', async () => {
      createComponent();
      await waitForPromises();
      expect(findWidgetContainer().exists()).toBe(true);
    });
  });

  describe('CI widget', () => {
    const sourceBranchLink = '<a href="/to/the/past">Link</a>';

    it('renders the pipeline widget', async () => {
      createComponent({
        updatedMrData: {
          source_branch_with_namespace_link: sourceBranchLink,
        },
      });
      await waitForPromises();
      expect(findMergedPipelineContainer().exists()).toBe(false);
      expect(findPipelineContainer().exists()).toBe(true);
      expect(findPipelineContainer().props('mr').sourceBranch).toBe(mockData.source_branch);
      expect(findPipelineContainer().props('mr').sourceBranchLink).toBe(sourceBranchLink);
    });

    // gitlab:quarantine_issue_url=https://gitlab.com/gitlab-org/gitlab/-/issues/427192
    // eslint-disable-next-line jest/no-disabled-tests
    it.skip('renders the branch in the pipeline widget', async () => {
      createComponent({
        mountFn: mountExtended,
        updatedMrData: {
          source_branch_with_namespace_link: sourceBranchLink,
        },
      });
      await waitForPromises();
      const ciWidget = wrapper.find('.mr-state-widget .label-branch');
      expect(ciWidget.html()).toContain(sourceBranchLink);
    });
  });

  describe('data', () => {
    it('passes approval api paths to service', () => {
      const paths = {
        api_approvals_path: `${TEST_HOST}/api/approvals/path`,
        api_approval_settings_path: `${TEST_HOST}/api/approval/settings/path`,
        api_approve_path: `${TEST_HOST}/api/approve/path`,
        api_unapprove_path: `${TEST_HOST}/api/unapprove/path`,
      };
      createComponent({
        updatedMrData: {
          ...paths,
        },
      });
      expect(wrapper.vm.service).toMatchObject(convertObjectPropsToCamelCase(paths));
    });
  });

  describe('loading state', () => {
    it('displays when waiting for API requests to process', () => {
      createComponent();
      expect(findLoadingComponent().exists()).toBe(true);
    });

    it('does not display when the API requests are processed', async () => {
      createComponent();
      await waitForPromises();
      expect(findLoadingComponent().exists()).toBe(false);
    });
  });

  describe('merge error', () => {
    const setupMergeError = async (error) => {
      createComponent();
      await waitForPromises();
      eventHub.$emit('FailedToMerge', error);
      await nextTick();
    };

    it('prevents XSS attacks by rendering merge error as plain text', async () => {
      const maliciousError = '<div class="xss"><script>alert("XSS")</script></div>';
      await setupMergeError(maliciousError);

      expect(findMergeError().text()).toContain(maliciousError);
      expect(findMergeError().element.querySelector('.xss')).toBe(null);
    });

    it('renders a docs link when storage is full', async () => {
      const storageFullError = 'Your namespace storage is full';
      await setupMergeError(storageFullError);

      expect(findMergeError().text()).toContain(storageFullError);
      expect(findManageStorageDocsLink().attributes('href')).toBe(
        '/help/user/storage_usage_quotas',
      );
    });
  });

  describe('shouldShowSecurityPolicyPipelineNote', () => {
    it('renders note when pipeline is passing and check is blocking', async () => {
      createComponent({
        updatedMrData: {
          security_policies_path: '/group/project/-/security/policies',
        },
        mergeChecks: [{ identifier: 'SECURITY_POLICY_PIPELINE_CHECK', status: 'FAILED' }],
      });
      await waitForPromises();

      expect(findSecurityPolicyPipelineNote().exists()).toBe(true);
    });

    it('renders note when check has WARNING status', async () => {
      createComponent({
        updatedMrData: {
          security_policies_path: '/group/project/-/security/policies',
        },
        mergeChecks: [{ identifier: 'SECURITY_POLICY_PIPELINE_CHECK', status: 'WARNING' }],
      });
      await waitForPromises();

      expect(findSecurityPolicyPipelineNote().exists()).toBe(true);
    });

    it('does not render note when pipeline is not passing', async () => {
      createComponent({
        updatedMrData: {
          ci_status: 'failed',
          security_policies_path: '/group/project/-/security/policies',
        },
        mergeChecks: [{ identifier: 'SECURITY_POLICY_PIPELINE_CHECK', status: 'FAILED' }],
      });
      await waitForPromises();

      expect(findSecurityPolicyPipelineNote().exists()).toBe(false);
    });

    it('does not render note when securityPoliciesPath is empty', async () => {
      createComponent({
        mergeChecks: [{ identifier: 'SECURITY_POLICY_PIPELINE_CHECK', status: 'FAILED' }],
      });
      await waitForPromises();

      expect(findSecurityPolicyPipelineNote().exists()).toBe(false);
    });

    it('does not render note when check status is SUCCESS', async () => {
      createComponent({
        updatedMrData: {
          security_policies_path: '/group/project/-/security/policies',
        },
        mergeChecks: [{ identifier: 'SECURITY_POLICY_PIPELINE_CHECK', status: 'SUCCESS' }],
      });
      await waitForPromises();

      expect(findSecurityPolicyPipelineNote().exists()).toBe(false);
    });

    it('does not render note when no security policy pipeline check exists', async () => {
      createComponent({
        updatedMrData: {
          security_policies_path: '/group/project/-/security/policies',
        },
        mergeChecks: [],
      });
      await waitForPromises();

      expect(findSecurityPolicyPipelineNote().exists()).toBe(false);
    });

    it('applies !gl-rounded-b-none to pipeline container when note is shown', async () => {
      createComponent({
        updatedMrData: {
          security_policies_path: '/group/project/-/security/policies',
        },
        mergeChecks: [{ identifier: 'SECURITY_POLICY_PIPELINE_CHECK', status: 'FAILED' }],
      });
      await waitForPromises();

      expect(findPipelineContainer().classes()).toContain('!gl-rounded-b-none');
    });
  });
});
