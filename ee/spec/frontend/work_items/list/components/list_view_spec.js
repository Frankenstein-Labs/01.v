import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import ListView from '~/work_items/list/list_view.vue';
import ListViewEE from 'ee/work_items/list/list_view.vue';
import EmptyStateWithAnyIssues from '~/work_items/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import { WORK_ITEM_TYPE_NAME_EPIC } from '~/work_items/constants';
import { CREATED_DESC } from '~/work_items/list/constants';
import { STATUS_OPEN } from '~/issues/constants';

/** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
let wrapper;

const findListView = () => wrapper.findComponent(ListView);
const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);

const baseProvide = {
  namespaceName: 'Test',
};

const mountComponent = ({
  hasEpicsFeature = true,
  hasIssueWeightsFeature = false,
  hasIssuableHealthStatusFeature = false,
  hasCustomFieldsFeature = true,
  hasIterationsFeature = false,
  hasStatusFeature = true,
  showNewWorkItem = true,
  isGroup = true,
  workItemType = WORK_ITEM_TYPE_NAME_EPIC,
  props = {},
} = {}) => {
  wrapper = shallowMountExtended(ListViewEE, {
    provide: {
      hasEpicsFeature,
      hasCustomFieldsFeature,
      hasIssueWeightsFeature,
      hasIssuableHealthStatusFeature,
      hasIterationsFeature,
      showNewWorkItem,
      isGroup,
      workItemType,
      hasStatusFeature,
      ...baseProvide,
    },
    stubs: {
      EmptyStateWithoutAnyIssues: {
        template: '<div></div>',
      },
      ListView: stubComponent(ListView, { template: RENDER_ALL_SLOTS_TEMPLATE }),
      EmptyStateWithAnyIssues: stubComponent(EmptyStateWithAnyIssues, {
        template: RENDER_ALL_SLOTS_TEMPLATE,
      }),
    },
    propsData: {
      rootPageFullPath: 'gitlab-org',
      queryVariables: { fullPath: 'gitlab-org', sort: CREATED_DESC, state: STATUS_OPEN },
      hasWorkItems: false,
      initialLoadWasFiltered: false,
      showBulkEditSidebar: false,
      sortKey: CREATED_DESC,
      isSortKeyInitialized: true,
      state: STATUS_OPEN,
      ...props,
    },
  });
};

describe('planning view props', () => {
  it('passes props down to the ce list_view component', () => {
    mountComponent();

    const props = findListView().props();

    expect(props).toMatchObject({
      rootPageFullPath: 'gitlab-org',
      queryVariables: { fullPath: 'gitlab-org', sort: CREATED_DESC, state: STATUS_OPEN },
      hasWorkItems: false,
      initialLoadWasFiltered: false,
    });
  });
});

describe('new epic button in the "any issues" empty state', () => {
  it('preselects the epic work item type', () => {
    mountComponent({ hasEpicsFeature: true, workItemType: WORK_ITEM_TYPE_NAME_EPIC });

    expect(findCreateWorkItemModal().props('preselectedWorkItemType')).toBe(
      WORK_ITEM_TYPE_NAME_EPIC,
    );
  });
});
