import { GlModal } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';

import WorkItemChangeTypeModalEE from 'ee/work_items/components/work_item_change_type_modal.vue';
import WorkItemChangeTypeModal from '~/work_items/components/work_item_change_type_modal.vue';
import getWorkItemDesignListQuery from '~/work_items/components/design_management/graphql/design_collection.query.graphql';
import promoteToEpicMutation from '~/issues/show/queries/promote_to_epic.mutation.graphql';
import { WORK_ITEM_TYPE_NAME_TASK } from '~/work_items/constants';

import { promoteToEpicMutationResponse } from '../mock_data';

describe('WorkItemChangeTypeModal component', () => {
  Vue.use(VueApollo);

  let wrapper;
  const graphqlError = 'GraphQL error';

  const noDesignQueryHandler = jest.fn().mockResolvedValue({
    data: {
      workItem: {
        id: 'gid://gitlab/WorkItem/1',
        workItemType: {
          id: 'gid://gitlab/WorkItems::Type/1',
          name: 'Issue',
          __typename: 'WorkItemType',
        },
        widgets: [
          {
            __typename: 'WorkItemWidgetDesigns',
            type: 'DESIGNS',
            designCollection: {
              copyState: 'READY',
              designs: { nodes: [] },
              versions: { nodes: [] },
            },
          },
        ],
      },
    },
  });

  const promoteToEpicMutationSuccessHandler = jest
    .fn()
    .mockResolvedValue(promoteToEpicMutationResponse);

  const promoteToEpicMutationErrorResponse = {
    errors: [
      {
        message: graphqlError,
      },
    ],
    data: {
      promoteToEpic: null,
    },
  };

  const createComponent = ({
    widgets = [],
    workItemType = WORK_ITEM_TYPE_NAME_TASK,
    promoteToEpicMutationHandler = promoteToEpicMutationSuccessHandler,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemChangeTypeModalEE, {
      apolloProvider: createMockApollo([
        [getWorkItemDesignListQuery, noDesignQueryHandler],
        [promoteToEpicMutation, promoteToEpicMutationHandler],
      ]),
      propsData: {
        workItemId: 'gid://gitlab/WorkItem/1',
        fullPath: 'gitlab-org/gitlab-test',
        hasParent: false,
        hasChildren: false,
        widgets,
        workItemType,
        workItemIid: '1',
      },
      provide: {
        hasSubepicsFeature: false,
        getWorkItemTypeConfiguration: jest.fn(),
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot name="modal-title"></slot><slot></slot><slot name="modal-footer"></slot></div>',
        }),
      },
    });
  };

  const findChangeTypeModal = () => wrapper.findComponent(WorkItemChangeTypeModal);

  describe('promote issue to epic', () => {
    it('successfully changes a work item type when conditions are met', () => {
      createComponent();

      findChangeTypeModal().vm.$emit('promote-to-epic');

      expect(promoteToEpicMutationSuccessHandler).toHaveBeenCalledWith({
        input: {
          iid: '1',
          projectPath: 'gitlab-org/gitlab-test',
        },
      });
    });

    it.each`
      errorType          | expectedErrorMessage | failureHandler
      ${'graphql error'} | ${graphqlError}      | ${jest.fn().mockResolvedValue(promoteToEpicMutationErrorResponse)}
      ${'network error'} | ${'Network error'}   | ${jest.fn().mockRejectedValue(new Error('Network error'))}
    `(
      'emits an error when there is a $errorType',
      async ({ expectedErrorMessage, failureHandler }) => {
        createComponent({ promoteToEpicMutationHandler: failureHandler });

        findChangeTypeModal().vm.$emit('promote-to-epic');
        await waitForPromises();

        expect(wrapper.emitted('error')[0][0]).toEqual(expectedErrorMessage);
      },
    );
  });
});
