import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkItemRelationshipList from '~/work_items/components/work_item_relationships/work_item_relationship_list.vue';
import WorkItemLinkChildContents from 'ee/work_items/components/shared/work_item_link_child_contents.vue';
import { mockBlockingLinkedItem } from '../../mock_data';

jest.mock('~/lib/utils/url_utility');

describe('WorkItemRelationshipListEE', () => {
  let wrapper;
  const mockLinkedItems = mockBlockingLinkedItem.linkedItems.nodes;
  const workItemFullPath = 'test-project-path';

  const createComponent = ({
    parentWorkItemId = 'gid://gitlab/WorkItem/1',
    parentWorkItemIid = '2',
    linkedItems = [],
    relationshipType = 'blocks',
    heading = 'Blocking',
    canUpdate = true,
    isLoggedIn = true,
    activeChildItemId = null,
  } = {}) => {
    if (isLoggedIn) {
      window.gon.current_user_id = 1;
    }

    wrapper = shallowMountExtended(WorkItemRelationshipList, {
      provide: {
        workItemTypesConfiguration: [],
      },
      propsData: {
        parentWorkItemId,
        parentWorkItemIid,
        linkedItems,
        relationshipType,
        heading,
        canUpdate,
        workItemFullPath,
        activeChildItemId,
      },
    });
  };

  const findWorkItemLinkChildContents = () => wrapper.findComponent(WorkItemLinkChildContents);

  it('renders work item link child contents with correct props', () => {
    createComponent({ linkedItems: mockLinkedItems });
    expect(findWorkItemLinkChildContents().props()).toMatchObject({
      childItem: mockLinkedItems[0].workItem,
      canUpdate: true,
      workItemFullPath,
    });
  });
});
