import Vue from 'vue';
import { GlForm, GlFormGroup, GlFormInput } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import { stubComponent } from 'helpers/stub_component';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WorkItemLinksForm from '~/work_items/components/work_item_links/work_item_links_form.vue';
import { FORM_TYPES, SEARCH_DEBOUNCE, WORK_ITEM_TYPE_NAME_ISSUE } from '~/work_items/constants';
import projectWorkItemsQuery from '~/work_items/graphql/project_work_items.query.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import createWorkItemMutation from '~/work_items/graphql/create_work_item.mutation.graphql';
import workItemHierarchyAddChildrenMutation from '~/work_items/graphql/work_item_hierarchy_add_children.mutation.graphql';
import namespaceProjectsForLinksWidgetQuery from '~/work_items/graphql/namespace_projects_for_links_widget.query.graphql';
import {
  availableWorkItemsResponse,
  createWorkItemMutationResponse,
  mockIterationWidgetResponse,
  namespaceProjectsList,
  namespaceWorkItemTypesQueryResponse,
  workItemHierarchyAddChildrenMutationResponse,
} from 'jest/work_items/mock_data';

Vue.use(VueApollo);

describe('WorkItemLinksForm', () => {
  /**
   * @type {import('helpers/vue_test_utils_helper').ExtendedWrapper}
   */
  let wrapper;

  const addMutationResolver = jest
    .fn()
    .mockResolvedValue(workItemHierarchyAddChildrenMutationResponse);
  const createMutationResolver = jest.fn().mockResolvedValue(createWorkItemMutationResponse);
  const availableWorkItemsResolver = jest.fn().mockResolvedValue(availableWorkItemsResponse);
  const namespaceWorkItemTypesResolver = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemTypesQueryResponse);
  const namespaceProjectsFormLinksWidgetResolver = jest
    .fn()
    .mockResolvedValue(namespaceProjectsList);

  const mockParentIteration = mockIterationWidgetResponse;
  const mockParentMilestone = {
    __typename: 'Milestone',
    dueDate: null,
    expired: false,
    id: 'gid://gitlab/Milestone/61',
    startDate: null,
    state: 'active',
    title: 'Sprint 1708516271',
    webPath: '/flightjs/Flight/-/milestones/8',
  };

  const createComponent = async ({
    parentConfidential = false,
    parentIteration = null,
    parentMilestone = null,
    formType = FORM_TYPES.create,
    parentWorkItemType = WORK_ITEM_TYPE_NAME_ISSUE,
    childrenType = { id: 'gid://gitlab/WorkItems::Type/5', name: 'Task' },
    addMutation = addMutationResolver,
    createMutation = createMutationResolver,
    isGroup = false,
    createGroupLevelWorkItems = true,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemLinksForm, {
      apolloProvider: createMockApollo([
        [projectWorkItemsQuery, availableWorkItemsResolver],
        [namespaceWorkItemTypesQuery, namespaceWorkItemTypesResolver],
        [namespaceProjectsForLinksWidgetQuery, namespaceProjectsFormLinksWidgetResolver],
        [workItemHierarchyAddChildrenMutation, addMutation],
        [createWorkItemMutation, createMutation],
      ]),
      propsData: {
        fullPath: 'group-a',
        isGroup,
        issuableGid: 'gid://gitlab/WorkItem/1',
        parentConfidential,
        parentIteration,
        parentMilestone,
        parentWorkItemType,
        childrenType,
        formType,
        glFeatures: {
          createGroupLevelWorkItems,
        },
      },
      stubs: {
        GlFormGroup: stubComponent(GlFormGroup, {
          props: ['state', 'invalidFeedback'],
        }),
        GlFormInput: stubComponent(GlFormInput, {
          props: ['state', 'disabled', 'value'],
          template: `<input />`,
        }),
      },
    });

    jest.advanceTimersByTime(SEARCH_DEBOUNCE);
    await waitForPromises();
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findInput = () => wrapper.findComponent(GlFormInput);

  beforeEach(() => {
    gon.current_username = 'root';
  });

  describe('associate iteration with child item', () => {
    it('updates when parent has an iteration associated', async () => {
      await createComponent({
        parentIteration: mockParentIteration,
      });
      findInput().vm.$emit('input', 'Create task test');

      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });
      await waitForPromises();
      expect(createMutationResolver).toHaveBeenCalledWith({
        input: expect.objectContaining({
          iterationWidget: {
            iterationId: mockParentIteration.id,
          },
        }),
        useWorkItemFeatures: false,
      });
    });

    it('does not send the iteration widget to mutation when parent has no iteration associated', async () => {
      await createComponent();
      findInput().vm.$emit('input', 'Create task test');

      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });
      await waitForPromises();
      expect(createMutationResolver).not.toHaveBeenCalledWith({
        input: expect.objectContaining({
          iterationWidget: {
            iterationId: mockParentIteration.id,
          },
        }),
      });
    });

    it('does not send the iteration widget to mutation when iteration is not supported in child type', async () => {
      await createComponent({
        parentIteration: mockParentIteration,
        childrenType: { id: 'gid://gitlab/WorkItems::Type/7', name: 'Key Result' },
      });

      findInput().vm.$emit('input', 'Create task test');

      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });
      await waitForPromises();
      expect(createMutationResolver).not.toHaveBeenCalledWith({
        input: expect.objectContaining({
          iterationWidget: {
            iterationId: mockParentIteration.id,
          },
        }),
        useWorkItemFeatures: false,
      });
    });
  });

  describe('associate milestone with child item', () => {
    it('updates when parent has a milestone associated', async () => {
      await createComponent({
        parentMilestone: mockParentMilestone,
      });
      findInput().vm.$emit('input', 'Create task test');

      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });
      await waitForPromises();
      expect(createMutationResolver).toHaveBeenCalledWith({
        input: expect.objectContaining({
          milestoneWidget: {
            milestoneId: mockParentMilestone.id,
          },
        }),
        useWorkItemFeatures: false,
      });
    });

    it('does not send the milestone widget to mutation when parent has no milestone associated', async () => {
      await createComponent();
      findInput().vm.$emit('input', 'Create task test');

      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });
      await waitForPromises();
      expect(createMutationResolver).not.toHaveBeenCalledWith({
        input: expect.objectContaining({
          milestoneWidget: {
            milestoneId: mockParentMilestone.id,
          },
        }),
      });
    });

    it('does not send the milestone widget to mutation when milestone is not supported in child type', async () => {
      await createComponent({
        parentMilestone: mockParentMilestone,
        childrenType: { id: 'gid://gitlab/WorkItems::Type/7', name: 'Key Result' },
      });

      findInput().vm.$emit('input', 'Create task test');

      findForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
      });
      await waitForPromises();
      expect(createMutationResolver).not.toHaveBeenCalledWith({
        input: expect.objectContaining({
          milestoneWidget: {
            milestoneId: mockParentMilestone.id,
          },
        }),
      });
    });
  });
});
