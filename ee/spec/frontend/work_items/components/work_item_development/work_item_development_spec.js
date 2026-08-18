import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { map } from 'lodash-es';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import workItemDevelopmentQuery from '~/work_items/graphql/work_item_development.query.graphql';
import workItemDevelopmentUpdatedSubscription from '~/work_items/graphql/work_item_development.subscription.graphql';
import waitForPromises from 'helpers/wait_for_promises';

import {
  workItemDevelopmentResponse,
  workItemDevelopmentFragmentResponse,
  workItemDevelopmentMRNodes,
  workItemDevelopmentFeatureFlagNodes,
  workItemRelatedBranchNodes,
} from 'jest/work_items/mock_data';

import WorkItemDevelopment from '~/work_items/components/work_item_development/work_item_development.vue';
import WorkItemDevelopmentRelationshipList from '~/work_items/components/work_item_development/work_item_development_relationship_list.vue';
import { workItemByIidResponseFactory } from '../../mock_data';

/**
 * MR list is available for CE and EE
 * Related feature flags is only available for EE
 */
describe('WorkItemDevelopment EE', () => {
  Vue.use(VueApollo);

  let wrapper;

  const workItemResponse = workItemByIidResponseFactory({ canUpdate: true });

  const workItemSuccessQueryHandler = jest.fn().mockResolvedValue(workItemResponse);

  const createWorkItemDevelopmentResponse = (config) =>
    workItemDevelopmentResponse({
      widgets: [
        ...workItemResponse.data.namespace.workItem.widgets,
        workItemDevelopmentFragmentResponse(config),
      ],
    });

  const devWidgetWithMRListOnly = createWorkItemDevelopmentResponse({
    mrNodes: workItemDevelopmentMRNodes,
    willAutoCloseByMergeRequest: true,
    featureFlagNodes: [],
    branchNodes: [],
    relatedMergeRequests: [],
  });

  const devWidgetWithFlagListOnly = createWorkItemDevelopmentResponse({
    mrNodes: [],
    willAutoCloseByMergeRequest: false,
    featureFlagNodes: workItemDevelopmentFeatureFlagNodes,
    branchNodes: [],
    relatedMergeRequests: [],
  });

  const devWidgetWithBranchListOnly = createWorkItemDevelopmentResponse({
    mrNodes: [],
    willAutoCloseByMergeRequest: false,
    featureFlagNodes: [],
    branchNodes: workItemRelatedBranchNodes,
    relatedMergeRequests: [],
  });

  const devWidgetWithRelatedMRListOnly = createWorkItemDevelopmentResponse({
    mrNodes: [],
    willAutoCloseByMergeRequest: false,
    featureFlagNodes: [],
    branchNodes: [],
    relatedMergeRequests: map(workItemDevelopmentMRNodes, 'mergeRequest'),
  });

  const devWidgetWithNoDevItems = createWorkItemDevelopmentResponse({
    mrNodes: [],
    willAutoCloseByMergeRequest: false,
    featureFlagNodes: [],
    branchNodes: [],
    relatedMergeRequests: [],
  });

  const devWidgetSuccessQueryHandler = jest.fn().mockResolvedValue(devWidgetWithMRListOnly);

  const devWidgetSuccessQueryHandlerWithOnlyMRList = jest
    .fn()
    .mockResolvedValue(devWidgetWithMRListOnly);

  const devWidgetSuccessQueryHandlerWithFlagListOnly = jest
    .fn()
    .mockResolvedValue(devWidgetWithFlagListOnly);

  const devWidgetSuccessQueryHandlerWithOnlyRelatedMRList = jest
    .fn()
    .mockResolvedValue(devWidgetWithRelatedMRListOnly);

  const devWidgetSuccessQueryHandlerWithOnlyBranchList = jest
    .fn()
    .mockResolvedValue(devWidgetWithBranchListOnly);

  const devWidgetSuccessQueryHandlerWithNoDevItem = jest
    .fn()
    .mockResolvedValue(devWidgetWithNoDevItems);

  const workItemDevelopmentUpdatedSubscriptionHandler = jest
    .fn()
    .mockResolvedValue({ data: { workItemUpdated: null } });

  const createComponent = ({
    workItemQueryHandler = workItemSuccessQueryHandler,
    workItemDevelopmentQueryHandler = devWidgetSuccessQueryHandler,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemDevelopment, {
      apolloProvider: createMockApollo([
        [workItemByIidQuery, workItemQueryHandler],
        [workItemDevelopmentQuery, workItemDevelopmentQueryHandler],
        [workItemDevelopmentUpdatedSubscription, workItemDevelopmentUpdatedSubscriptionHandler],
      ]),
      propsData: {
        workItemId: 'gid://gitlab/WorkItem/1',
        workItemIid: '1',
        workItemFullPath: 'full-path',
      },
    });
  };

  const findRelationshipList = () => wrapper.findComponent(WorkItemDevelopmentRelationshipList);

  it.each`
    description        | successQueryResolveHandler
    ${'feature flags'} | ${devWidgetSuccessQueryHandlerWithFlagListOnly}
    ${'MRs'}           | ${devWidgetSuccessQueryHandlerWithOnlyMRList}
    ${'branches'}      | ${devWidgetSuccessQueryHandlerWithOnlyBranchList}
    ${'related MRs'}   | ${devWidgetSuccessQueryHandlerWithOnlyRelatedMRList}
  `(
    'should show the relationship list when there is only a list of $description',
    async ({ successQueryResolveHandler }) => {
      createComponent({ workItemDevelopmentQueryHandler: successQueryResolveHandler });
      await waitForPromises();

      expect(findRelationshipList().exists()).toBe(true);
    },
  );

  it('should not show the widget when any of the dev item is not available', async () => {
    createComponent({ workItemDevelopmentQueryHandler: devWidgetSuccessQueryHandlerWithNoDevItem });
    await waitForPromises();

    expect(findRelationshipList().exists()).toBe(false);
  });
});
