import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import waitForPromises from 'helpers/wait_for_promises';
import { sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { getDiffFileMock } from 'jest/diffs/mock_data/diff_file';
import note from 'jest/notes/mock_data';
import DiffLineNoteForm from '~/diffs/components/diff_line_note_form.vue';
import NoteForm from '~/notes/components/note_form.vue';
import { SOMETHING_WENT_WRONG, SAVING_THE_COMMENT_FAILED } from '~/diffs/i18n';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';
import { useBatchComments } from '~/batch_comments/store';
import { useMrNotes } from '~/mr_notes/store/legacy_mr_notes';

Vue.use(PiniaVuePlugin);
jest.mock('~/alert');

describe('EE DiffLineNoteForm', () => {
  let wrapper;
  let pinia;

  let saveDraft;

  const createComponent = (props = {}) => {
    const diffFile = getDiffFileMock();
    const diffLines = diffFile.highlighted_diff_lines;

    wrapper = shallowMount(DiffLineNoteForm, {
      propsData: {
        diffFileHash: diffFile.file_hash,
        diffLines,
        line: diffLines[0],
        noteTargetLine: diffLines[0],
        ...props,
      },
      pinia,
      mocks: {
        resetAutoSave: jest.fn(),
      },
    });
  };

  const submitNoteAddToReview = () =>
    wrapper.findComponent(NoteForm).vm.$emit('handleFormUpdateAddToReview', note);
  const saveDraftCommitId = () => saveDraft.mock.calls[0][0].data.note.commit_id;

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });
    useLegacyDiffs().diffFiles = [getDiffFileMock()];
    useNotes();
    useMrNotes();
    saveDraft = useBatchComments().saveDraft.mockImplementation(() => Promise.resolve());
  });

  describe('when user submits note to review', () => {
    it('should call saveDraft action with commit_id === null when store has no commit', () => {
      createComponent();

      submitNoteAddToReview();

      expect(saveDraft).toHaveBeenCalledTimes(1);
      expect(saveDraftCommitId()).toBe(null);
    });

    it('should call saveDraft action with commit_id when store has commit', () => {
      const HEAD_SHA = 'abc123';
      useLegacyDiffs().commit = {};
      useLegacyDiffs().diffFiles = [
        {
          file_hash: getDiffFileMock().file_hash,
          diff_refs: { head_sha: HEAD_SHA },
          highlighted_diff_lines: [],
        },
      ];
      createComponent();

      submitNoteAddToReview();

      expect(saveDraft).toHaveBeenCalledTimes(1);
      expect(saveDraftCommitId()).toBe(HEAD_SHA);
    });

    describe('when note-form emits `handleFormUpdateAddToReview`', () => {
      const parentElement = null;
      const errorCallback = jest.fn();

      describe.each`
        scenario                  | serverError                      | message
        ${'with server error'}    | ${{ data: { errors: 'error' } }} | ${SAVING_THE_COMMENT_FAILED}
        ${'without server error'} | ${null}                          | ${SOMETHING_WENT_WRONG}
      `('$scenario', ({ serverError, message }) => {
        beforeEach(async () => {
          saveDraft.mockRejectedValue(serverError);

          createComponent();

          wrapper
            .findComponent(NoteForm)
            .vm.$emit(
              'handleFormUpdateAddToReview',
              'invalid note',
              false,
              parentElement,
              errorCallback,
            );

          await waitForPromises();
        });

        it(`renders ${serverError ? 'server' : 'generic'} error message`, () => {
          expect(createAlert).toHaveBeenCalledWith({
            message: sprintf(message, { reason: serverError?.data?.errors }),
            parent: parentElement,
          });
        });

        it('calls errorCallback', () => {
          expect(errorCallback).toHaveBeenCalled();
        });
      });
    });
  });
});
