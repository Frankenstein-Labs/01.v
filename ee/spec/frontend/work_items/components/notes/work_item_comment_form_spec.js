import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import CommentTemperature from 'ee_component/ai/components/comment_temperature.vue';
import { ESC_KEY, ENTER_KEY } from '~/lib/utils/keys';
import workItemEmailParticipantsByIidQuery from '~/work_items/graphql/notes/work_item_email_participants_by_iid.query.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import WorkItemCommentForm from '~/work_items/components/notes/work_item_comment_form.vue';
import WorkItemStateToggle from '~/work_items/components/work_item_state_toggle.vue';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';

import { workItemByIidResponseFactory } from '../../mock_data';

jest.mock('~/lib/utils/autosave');

Vue.use(VueApollo);

describe('WorkItemCommentForm', () => {
  let wrapper;
  let measureCommentTemperatureMock;
  let workItemResponse;
  let workItemByIidSuccessHandler;

  const mockAutosaveKey = 'test-auto-save-key';
  const mockAutosaveKeyInternalNote = 'test-auto-save-key/InternalNote';
  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findWorkItemToggleStateButton = () => wrapper.findComponent(WorkItemStateToggle);
  const findConfirmButton = () => wrapper.findComponentByTestId('confirm-button');
  const findCommentTemperature = () => wrapper.findComponent(CommentTemperature);

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    window.gon.current_user_id = 1;

    workItemResponse = workItemByIidResponseFactory({
      canMarkNoteAsInternal: true,
      canUpdate: true,
    });
    workItemByIidSuccessHandler = jest.fn().mockResolvedValue(workItemResponse);

    wrapper = shallowMountExtended(WorkItemCommentForm, {
      apolloProvider: createMockApollo([
        [workItemEmailParticipantsByIidQuery, jest.fn()],
        [workItemByIidQuery, workItemByIidSuccessHandler],
      ]),
      propsData: {
        workItemId: 'gid://gitlab/WorkItem/1',
        workItemType: 'Task',
        workItemIid: '1',
        markdownPreviewPath: '/group/project/preview_markdown?target_type=WorkItem',
        fullPath: 'group/project',
        uploadsPath: 'http://127.0.0.1:3000/test-project-path/uploads',
        ariaLabel: 'test-aria-label',
        autosaveKey: mockAutosaveKey,
        autosaveKeyInternalNote: mockAutosaveKeyInternalNote,
        ...props,
      },
      provide: {
        glFeatures: {},
        ...provide,
      },
      stubs: {
        CommentTemperature,
      },
    });
    measureCommentTemperatureMock = jest.fn().mockReturnValue();
  };

  describe('comment temperature', () => {
    const commentText = 'This is a test comment';

    describe('without the ability to measure it', () => {
      it('does not render the comment temperature component', () => {
        createComponent({
          provide: {
            glAbilities: {
              measureCommentTemperature: false,
            },
          },
        });

        expect(findCommentTemperature().exists()).toBe(false);
      });
    });

    describe('with ability to measure it', () => {
      describe.each([false, true])('when isNewDiscussion is %j', (isNewDiscussion) => {
        const submitButtonClick = async () => {
          if (isNewDiscussion) {
            findWorkItemToggleStateButton().vm.$emit('submit-comment');
          } else {
            findConfirmButton().vm.$emit('click');
          }
          await waitForPromises();
        };

        beforeEach(async () => {
          createComponent({
            props: {
              initialValue: commentText,
              isNewDiscussion,
            },
            provide: {
              glAbilities: {
                measureCommentTemperature: true,
              },
            },
          });

          await waitForPromises();
          findCommentTemperature().vm.measureCommentTemperature = measureCommentTemperatureMock;
        });

        it('renders the comment temperature component', () => {
          expect(findCommentTemperature().exists()).toBe(true);
        });

        it('measures comment temperature and does not submit when clicking the button', async () => {
          await submitButtonClick();

          expect(measureCommentTemperatureMock).toHaveBeenCalled();
          expect(wrapper.emitted('submitForm')).toBeUndefined();
        });

        it('does not disable the text area while measuring the temperature', () => {
          findConfirmButton().vm.$emit('click');

          expect(findMarkdownEditor().props('disabled')).toBe(false);
        });

        it('does not clear the text input while measuring the temperature', () => {
          findConfirmButton().vm.$emit('click');

          expect(findMarkdownEditor().props('value')).toBe(commentText);
        });

        it('submits the form when the Comment Temperature component emits a save event', async () => {
          findConfirmButton().vm.$emit('click');

          expect(measureCommentTemperatureMock).toHaveBeenCalled();
          expect(wrapper.emitted('submit-form')).toBeUndefined();

          findCommentTemperature().vm.$emit('save');
          await nextTick();

          expect(wrapper.emitted('submit-form')).toHaveLength(1);
          expect(wrapper.emitted('submit-form')[0][0]).toEqual({
            commentText,
            isNoteInternal: false,
          });
        });
      });
    });

    describe('keyboard shortcuts', () => {
      beforeEach(() => {
        createComponent({
          props: {
            initialValue: commentText,
          },
          provide: {
            glAbilities: {
              measureCommentTemperature: true,
            },
          },
        });
        findCommentTemperature().vm.measureCommentTemperature = measureCommentTemperatureMock;
      });

      it('measures temperature on Cmd+Enter', () => {
        findMarkdownEditor().vm.$emit(
          'keydown',
          new KeyboardEvent('keydown', { key: ENTER_KEY, metaKey: true }),
        );

        expect(measureCommentTemperatureMock).toHaveBeenCalled();
        expect(wrapper.emitted('submitForm')).toBeUndefined();
      });

      it('measures temperature on Ctrl+Enter', () => {
        findMarkdownEditor().vm.$emit(
          'keydown',
          new KeyboardEvent('keydown', { key: ENTER_KEY, ctrlKey: true }),
        );

        expect(measureCommentTemperatureMock).toHaveBeenCalled();
        expect(wrapper.emitted('submitForm')).toBeUndefined();
      });

      it('does not measure temperature on Shift+Enter', () => {
        findMarkdownEditor().vm.$emit(
          'keydown',
          new KeyboardEvent('keydown', { key: ENTER_KEY, ctrshiftKeylKey: true }),
        );

        expect(measureCommentTemperatureMock).not.toHaveBeenCalled();
      });

      it('does not measure temperature when editing is cancelled', () => {
        findMarkdownEditor().vm.$emit('keydown', new KeyboardEvent('keydown', { key: ESC_KEY }));

        expect(measureCommentTemperatureMock).not.toHaveBeenCalled();
      });
    });
  });
});
