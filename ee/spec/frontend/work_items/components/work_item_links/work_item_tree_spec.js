import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import WorkItemTree from '~/work_items/components/work_item_links/work_item_tree.vue';
import WorkItemChildrenWrapper from '~/work_items/components/work_item_links/work_item_children_wrapper.vue';
import getWorkItemTreeQuery from '~/work_items/graphql/work_item_tree.query.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import {
  namespaceWorkItemTypesQueryResponse,
  workItemHierarchyTreeResponse,
} from 'ee_else_ce_jest/work_items/mock_data';

Vue.use(VueApollo);

describe('WorkItemTree EE', () => {
  let wrapper;

  const workItemHierarchyTreeResponseHandler = jest
    .fn()
    .mockResolvedValue(workItemHierarchyTreeResponse);
  const namespaceWorkItemTypesQueryHandler = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemTypesQueryResponse);

  const findWorkItemLinkChildrenWrapper = () => wrapper.findComponent(WorkItemChildrenWrapper);

  const createComponent = async ({
    workItemType = 'Objective',
    workItemIid = '2',
    parentWorkItemType = 'Objective',
    confidential = false,
    canUpdate = true,
    canUpdateChildren = true,
    hasSubepicsFeature = true,
    workItemHierarchyTreeHandler = workItemHierarchyTreeResponseHandler,
    shouldWaitForPromise = true,
    closedChildrenCount = 0,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemTree, {
      propsData: {
        fullPath: 'test/project',
        workItemType,
        workItemIid,
        parentWorkItemType,
        workItemId: 'gid://gitlab/WorkItem/2',
        confidential,
        canUpdate,
        canUpdateChildren,
      },
      apolloProvider: createMockApollo([
        [getWorkItemTreeQuery, workItemHierarchyTreeHandler],
        [namespaceWorkItemTypesQuery, namespaceWorkItemTypesQueryHandler],
      ]),
      provide: {
        hasSubepicsFeature,
        closedChildrenCount,
      },
      stubs: { CrudComponent },
    });

    if (shouldWaitForPromise) {
      await waitForPromises();
    }
  };

  it('fetches widget definitions and passes formatted allowed children by type to children wrapper', async () => {
    await createComponent();

    expect(namespaceWorkItemTypesQueryHandler).toHaveBeenCalled();
    await nextTick();

    expect(findWorkItemLinkChildrenWrapper().props('allowedChildrenByType')).toEqual({
      Epic: ['Epic', 'Issue'],
      Incident: ['Task'],
      Issue: ['Task'],
      Objective: ['Key Result', 'Objective'],
      Ticket: ['Task'],
    });
  });
});
