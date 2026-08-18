import { GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import SystemNote from '~/work_items/components/notes/system_note.vue';
import WorkItemNotes from '~/work_items/components/work_item_notes.vue';
import workItemNotesByIidQuery from '~/work_items/graphql/notes/work_item_notes_by_iid.query.graphql';
import deleteWorkItemNoteMutation from '~/work_items/graphql/notes/delete_work_item_notes.mutation.graphql';
import workItemNoteCreatedSubscription from '~/work_items/graphql/notes/work_item_note_created.subscription.graphql';
import workItemNoteUpdatedSubscription from '~/work_items/graphql/notes/work_item_note_updated.subscription.graphql';
import workItemNoteDeletedSubscription from '~/work_items/graphql/notes/work_item_note_deleted.subscription.graphql';
import { WIDGET_TYPE_NOTES, WORK_ITEM_NOTES_SORT_ORDER_KEY } from '~/work_items/constants';
import { DESC } from '~/notes/constants';
import {
  mockWorkItemNotesByIidResponse,
  workItemNotesCreateSubscriptionResponse,
  workItemNotesUpdateSubscriptionResponse,
  workItemNotesDeleteSubscriptionResponse,
  workItemNotesWithSystemNotesWithChangedDescription,
} from 'jest/work_items/mock_data';
import { workItemQueryResponse } from '../mock_data';

const mockWorkItemId = workItemQueryResponse.data.workItem.id;
const mockWorkItemIid = workItemQueryResponse.data.workItem.iid;

describe('WorkItemNotes component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const showModal = jest.fn();

  const findAllSystemNotes = () => wrapper.findAllComponents(SystemNote);

  const workItemNotesQueryHandler = jest.fn().mockResolvedValue(mockWorkItemNotesByIidResponse);

  const workItemNotesWithChangedDescriptionHandler = jest
    .fn()
    .mockResolvedValue(workItemNotesWithSystemNotesWithChangedDescription);
  const deleteWorkItemNoteMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: { destroyNote: { note: null, __typename: 'DestroyNote' } },
  });
  const notesCreateSubscriptionHandler = jest
    .fn()
    .mockResolvedValue(workItemNotesCreateSubscriptionResponse);
  const notesUpdateSubscriptionHandler = jest
    .fn()
    .mockResolvedValue(workItemNotesUpdateSubscriptionResponse);
  const notesDeleteSubscriptionHandler = jest
    .fn()
    .mockResolvedValue(workItemNotesDeleteSubscriptionResponse);

  const createComponent = ({
    workItemId = mockWorkItemId,
    workItemIid = mockWorkItemIid,
    defaultWorkItemNotesQueryHandler = workItemNotesQueryHandler,
    deleteWINoteMutationHandler = deleteWorkItemNoteMutationSuccessHandler,
  } = {}) => {
    wrapper = shallowMount(WorkItemNotes, {
      apolloProvider: createMockApollo([
        [workItemNotesByIidQuery, defaultWorkItemNotesQueryHandler],
        [deleteWorkItemNoteMutation, deleteWINoteMutationHandler],
        [workItemNoteCreatedSubscription, notesCreateSubscriptionHandler],
        [workItemNoteUpdatedSubscription, notesUpdateSubscriptionHandler],
        [workItemNoteDeletedSubscription, notesDeleteSubscriptionHandler],
      ]),
      provide: {
        isGroup: false,
      },
      propsData: {
        fullPath: 'test-path',
        uploadsPath: '/group/project/uploads',
        workItemId,
        workItemIid,
        workItemType: 'task',
      },
      stubs: {
        GlModal: stubComponent(GlModal, { methods: { show: showModal } }),
      },
    });
  };

  describe('system notes with description changes', () => {
    it('collapses notes with time difference of 10 mins into one', async () => {
      const notesWidget =
        workItemNotesWithSystemNotesWithChangedDescription.data.namespace.workItem.widgets.find(
          (widget) => widget.type === WIDGET_TYPE_NOTES,
        );

      const {
        discussions: { nodes },
      } = notesWidget;

      createComponent({
        defaultWorkItemNotesQueryHandler: workItemNotesWithChangedDescriptionHandler,
      });

      await waitForPromises();

      expect(findAllSystemNotes()).not.toHaveLength(nodes.length);
      expect(findAllSystemNotes()).toHaveLength(2);
    });

    describe('when notes are fetched in descending order', () => {
      useLocalStorageSpy();

      it('collapses notes with time difference of 10 mins into one', async () => {
        localStorage.setItem(WORK_ITEM_NOTES_SORT_ORDER_KEY, DESC);

        const reversedNotes = { ...workItemNotesWithSystemNotesWithChangedDescription };
        const discussions = reversedNotes.data.namespace.workItem.widgets.find(
          (widget) => widget.type === WIDGET_TYPE_NOTES,
        ).discussions.nodes;

        discussions.reverse();

        createComponent({
          defaultWorkItemNotesQueryHandler: jest.fn().mockResolvedValue(reversedNotes),
        });

        await waitForPromises();

        expect(findAllSystemNotes()).not.toHaveLength(discussions.length);
        expect(findAllSystemNotes()).toHaveLength(2);
      });
    });
  });
});
