import Vue from 'vue';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ReviewDrawer from '~/batch_comments/components/review_drawer.vue';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';
import { useBatchComments } from '~/batch_comments/store';
import userCanApproveQuery from '~/batch_comments/queries/can_approve.query.graphql';

jest.mock('~/autosave');
jest.mock('~/vue_shared/components/markdown/eventhub');

Vue.use(PiniaVuePlugin);
Vue.use(VueApollo);

describe('ReviewDrawer', () => {
  let wrapper;
  let pinia;

  const createComponent = ({ canApprove = true } = {}) => {
    const requestHandlers = [
      [
        userCanApproveQuery,
        () =>
          Promise.resolve({
            data: {
              project: {
                id: 1,
                mergeRequest: {
                  id: 1,
                  userPermissions: {
                    canApprove,
                  },
                },
              },
            },
          }),
      ],
    ];
    const apolloProvider = createMockApollo(requestHandlers);

    wrapper = mountExtended(ReviewDrawer, { pinia, apolloProvider });
  };

  beforeEach(() => {
    pinia = createTestingPinia({
      plugins: [globalAccessorPlugin],
    });
    useLegacyDiffs().projectPath = 'gitlab-org/gitlab';
    useNotes().noteableData.id = 1;
    useNotes().noteableData.preview_note_path = '/preview';
    useNotes().noteableData.noteableType = 'merge_request';
    useNotes().notesData.markdownDocsPath = '/markdown/docs';
    useNotes().notesData.quickActionsDocsPath = '/quickactions/docs';
    useBatchComments();
  });

  it.each`
    requirePasswordToApprove | exists   | existsText
    ${true}                  | ${true}  | ${'shows'}
    ${false}                 | ${false} | ${'hides'}
  `(
    '$existsText approve password if require_password_to_approve is $requirePasswordToApprove',
    async ({ requirePasswordToApprove, exists }) => {
      useNotes().noteableData.require_password_to_approve = requirePasswordToApprove;
      useBatchComments().drawerOpened = true;

      createComponent({ requirePasswordToApprove });

      await waitForPromises();

      expect(wrapper.findByTestId('approve_password').exists()).toBe(exists);
    },
  );
});
