import Vue, { nextTick } from 'vue';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import CommentTemperature from 'ee_component/ai/components/comment_temperature.vue';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import NoteForm from '~/notes/components/note_form.vue';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useNotes } from '~/notes/store/legacy_notes';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useBatchComments } from '~/batch_comments/store';
import {
  notesDataMock,
  noteableDataMock,
  userDataMock,
} from '../../../../../spec/frontend/notes/mock_data';

jest.mock('~/lib/utils/autosave');

const badNote = 'very bad note';

Vue.use(PiniaVuePlugin);

describe('issue_comment_form component', () => {
  let wrapper;
  let pinia;

  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findMarkdownEditorTextarea = () => findMarkdownEditor().find('textarea');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel');
  const findBatchCancelButton = () => wrapper.findComponentByTestId('cancelBatchCommentsEnabled');
  const findCommentTemperature = () => wrapper.findComponent(CommentTemperature);

  const createComponentWrapper = ({
    propsData = {},
    initialData = {},
    noteableType = 'Issue',
    abilities = {},
    stubs = {},
  } = {}) => {
    useNotes().noteableData = {
      ...noteableDataMock,
      noteableType,
    };
    useNotes().notesData = notesDataMock;
    useNotes().userData = userDataMock;

    wrapper = mountExtended(NoteForm, {
      pinia,
      propsData: {
        isEditing: false,
        noteBody: 'Magni suscipit eius consectetur enim et ex et commodi.',
        noteId: '545',
        ...propsData,
      },
      data() {
        return {
          ...initialData,
        };
      },
      provide: {
        glAbilities: abilities,
      },
      stubs,
    });
  };

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });
    useLegacyDiffs();
    useNotes();
    useBatchComments().$patch({ isMergeRequest: true });
  });

  describe('markdown editor', () => {
    it('shows markdown editor', () => {
      createComponentWrapper();
      expect(findMarkdownEditor().exists()).toBe(true);
    });

    it('passes down restoreFromAutosave prop to the editor', () => {
      createComponentWrapper({
        propsData: {
          restoreFromAutosave: true,
        },
      });
      expect(findMarkdownEditor().props('restoreFromAutosave')).toBe(true);
    });
  });

  describe.each(['Issue', 'MergeRequest'])('for `%s` noteable type', (noteableType) => {
    describe('comment temperature', () => {
      describe('without the ability to measure it', () => {
        it('does not render the comment temperature component', async () => {
          createComponentWrapper({
            noteableType,
            initialData: {
              updatedNoteBody: badNote,
            },
          });
          await nextTick();
          expect(findCommentTemperature().exists()).toBe(false);
        });
      });

      describe('with ability to measure it', () => {
        const measureCommentTemperatureMock = jest.fn().mockReturnValue();
        let bootstrapFn;

        beforeEach(() => {
          bootstrapFn = (updatedNoteBody = badNote) => {
            createComponentWrapper({
              noteableType,
              initialData: { updatedNoteBody },
              abilities: {
                measureCommentTemperature: true,
              },
              stubs: {
                CommentTemperature,
              },
            });
            findCommentTemperature().vm.measureCommentTemperature = measureCommentTemperatureMock;
          };
          bootstrapFn();
        });

        it('renders the comment temperature component', () => {
          expect(findCommentTemperature().exists()).toBe(true);
        });

        describe('when updating a note', () => {
          const proceedClick = async () => {
            wrapper.findByTestId('reply-comment-button').trigger('click');
            await nextTick();
          };
          const cancelClick = async () => {
            findCancelButton().vm.$emit('click');
            await nextTick();
          };

          it('does not measure temperature on the slash commands', async () => {
            bootstrapFn('/close');
            await proceedClick();
            expect(measureCommentTemperatureMock).not.toHaveBeenCalled();
            expect(wrapper.emitted('handleFormUpdate')).toBeDefined();
          });

          it('should measure comment temperature and not send', async () => {
            await proceedClick();
            expect(measureCommentTemperatureMock).toHaveBeenCalled();
            expect(wrapper.emitted('handleFormUpdate')).toBeUndefined();
          });

          it('should not disable the textarea while measuring the temperature', async () => {
            await proceedClick();
            expect(findMarkdownEditor().find('textarea').attributes('disabled')).toBeUndefined();
          });

          it('should not clear the text input while measuring the temperature', async () => {
            await proceedClick();
            expect(findMarkdownEditorTextarea().element.value).toBe('very bad note');
          });

          it('does not measure temperature when editing is cancelled', async () => {
            await cancelClick();
            expect(measureCommentTemperatureMock).not.toHaveBeenCalled();
          });

          describe('keyboard shortcuts', () => {
            it.each`
              eventProps                           | description
              ${{ metaKey: true }}                 | ${'Cmd+Enter'}
              ${{ ctrlKey: true }}                 | ${'Ctrl+Enter'}
              ${{ metaKey: true, shiftKey: true }} | ${'Shift+Cmd+Enter'}
              ${{ ctrlKey: true, shiftKey: true }} | ${'Shift+Ctrl+Enter'}
            `(
              'when `$description` is pressed it measures the comment temperature and does not send',
              async ({ eventProps } = {}) => {
                const textarea = wrapper.find('textarea');
                textarea.trigger('keydown.enter', eventProps);

                await nextTick();

                expect(measureCommentTemperatureMock).toHaveBeenCalled();
                expect(wrapper.emitted('submitForm')).toBeUndefined();
                expect(findMarkdownEditorTextarea().element.value).toBe('very bad note');
              },
            );
          });
        });

        describe.each`
          desc                                     | newComment | addToReview | action
          ${'when adding a new comment'}           | ${true}    | ${false}    | ${() => wrapper.findByTestId('comment-now-button').trigger('click')}
          ${'when adding to or starting a review'} | ${false}   | ${true}     | ${() => wrapper.findByTestId('start-review-button').trigger('click')}
        `('$desc', ({ action, newComment, addToReview } = {}) => {
          const proceedClick = async () => {
            action();
            await nextTick();
          };
          const cancelClick = async () => {
            findBatchCancelButton().vm.$emit('click');
            await nextTick();
          };

          beforeEach(() => {
            bootstrapFn = (updatedNoteBody = badNote) => {
              createComponentWrapper({
                noteableType,
                initialData: { updatedNoteBody },
                propsData: {
                  isDraft: true,
                  noteId: '',
                },
                abilities: {
                  measureCommentTemperature: true,
                },
                stubs: {
                  CommentTemperature,
                },
              });
              findCommentTemperature().vm.measureCommentTemperature = measureCommentTemperatureMock;
            };
            bootstrapFn();
          });

          it('does not measure temperature on the slash commands', async () => {
            bootstrapFn('/close');
            await proceedClick();
            expect(measureCommentTemperatureMock).not.toHaveBeenCalled();
            if (addToReview) {
              expect(wrapper.emitted('handleFormUpdate')).toBeUndefined();
              expect(wrapper.emitted('handleFormUpdateAddToReview')).toHaveLength(1);
            }
            if (newComment) {
              expect(wrapper.emitted('handleFormUpdate')).toHaveLength(1);
              expect(wrapper.emitted('handleFormUpdateAddToReview')).toBeUndefined();
            }
          });

          it('should measure comment temperature and not send', async () => {
            await proceedClick();
            expect(measureCommentTemperatureMock).toHaveBeenCalled();
            expect(wrapper.emitted('handleFormUpdate')).toBeUndefined();
          });

          it('should not make textarea disabled while measuring the temperature', async () => {
            await proceedClick();
            expect(findMarkdownEditor().find('textarea').attributes('disabled')).toBeUndefined();
          });

          it('should not clear the text input while measuring the temperature', async () => {
            await proceedClick();
            expect(findMarkdownEditorTextarea().element.value).toBe('very bad note');
          });

          it('does not measure temperature when editing is cancelled', async () => {
            await cancelClick();
            expect(measureCommentTemperatureMock).not.toHaveBeenCalled();
          });

          it('when adding a new comment does not measure temperature and sends when the Comment Temperature component asks to save', async () => {
            await proceedClick();
            expect(measureCommentTemperatureMock).toHaveBeenCalled();
            expect(wrapper.emitted('handleFormUpdate')).toBeUndefined();
            expect(wrapper.emitted('handleFormUpdateAddToReview')).toBeUndefined();

            findCommentTemperature().vm.$emit('save');
            if (addToReview) {
              expect(wrapper.emitted('handleFormUpdate')).toBeUndefined();
              expect(wrapper.emitted('handleFormUpdateAddToReview')).toHaveLength(1);
            }
            if (newComment) {
              expect(wrapper.emitted('handleFormUpdate')).toHaveLength(1);
              expect(wrapper.emitted('handleFormUpdateAddToReview')).toBeUndefined();
            }
            expect(measureCommentTemperatureMock).toHaveBeenCalledTimes(1);
          });

          describe('keyboard shortcuts', () => {
            it.each`
              eventProps                           | description
              ${{ metaKey: true }}                 | ${'Cmd+Enter'}
              ${{ ctrlKey: true }}                 | ${'Ctrl+Enter'}
              ${{ metaKey: true, shiftKey: true }} | ${'Shift+Cmd+Enter'}
              ${{ ctrlKey: true, shiftKey: true }} | ${'Shift+Ctrl+Enter'}
            `(
              'when `$description` is pressed it measures the comment temperature and does not send',
              async ({ eventProps } = {}) => {
                const textarea = wrapper.find('textarea');
                textarea.trigger('keydown.enter', eventProps);

                await nextTick();

                expect(measureCommentTemperatureMock).toHaveBeenCalled();
                expect(wrapper.emitted('submitForm')).toBeUndefined();
                expect(findMarkdownEditorTextarea().element.value).toBe('very bad note');
              },
            );
          });
        });
      });
    });
  });
});
