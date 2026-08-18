import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { detectAndConfirmSensitiveTokens } from '~/lib/utils/secret_detection';
import { getDraft, clearDraft, updateDraft } from '~/lib/utils/autosave';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import BaseCommentForm from 'ee/compliance_violations/components/base_comment_form.vue';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal');
jest.mock('~/lib/utils/secret_detection');
jest.mock('~/lib/utils/autosave');
jest.mock('~/vue_shared/components/markdown/tracking');

describe('BaseCommentForm', () => {
  let wrapper;

  const defaultProps = {
    autosaveKey: 'test-autosave-key',
    formFieldProps: {
      'aria-label': 'Test comment',
      placeholder: 'Write a comment...',
      id: 'test-comment',
      name: 'test-comment',
    },
    submitButtonText: 'Submit',
  };

  const defaultProvide = {
    uploadsPath: '/uploads',
    markdownPreviewPath: '/preview',
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(BaseCommentForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findSubmitButton = () => wrapper.findComponentByTestId('submit-button');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');

  beforeEach(() => {
    getDraft.mockReturnValue('');
    confirmAction.mockResolvedValue(true);
    detectAndConfirmSensitiveTokens.mockResolvedValue(true);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders MarkdownEditor', () => {
      const markdownEditor = findMarkdownEditor();

      expect(markdownEditor.exists()).toBe(true);
    });

    it('renders submit button with correct text', () => {
      const submitButton = findSubmitButton();

      expect(submitButton.exists()).toBe(true);
      expect(submitButton.text()).toBe('Submit');
    });

    it('renders cancel button with default text', () => {
      const cancelButton = findCancelButton();

      expect(cancelButton.exists()).toBe(true);
      expect(cancelButton.text()).toBe('Cancel');
    });

    it('renders cancel button with custom text', () => {
      createComponent({ props: { cancelButtonText: 'Custom Cancel' } });

      expect(findCancelButton().text()).toBe('Custom Cancel');
    });
  });

  describe('autosave functionality', () => {
    it('loads draft content on initialization', () => {
      const draftContent = 'Draft comment';
      getDraft.mockReturnValue(draftContent);

      createComponent();

      expect(getDraft).toHaveBeenCalledWith('test-autosave-key');
      expect(wrapper.vm.commentText).toBe(draftContent);
    });

    it('uses initial value when provided', () => {
      const initialValue = 'Initial content';
      createComponent({ props: { initialValue } });

      expect(wrapper.vm.commentText).toBe(initialValue);
    });

    it('prefers initial value over draft', () => {
      const initialValue = 'Initial content';
      const draftContent = 'Draft content';
      getDraft.mockReturnValue(draftContent);

      createComponent({ props: { initialValue } });

      expect(wrapper.vm.commentText).toBe(initialValue);
    });

    it('updates draft when comment text changes', async () => {
      createComponent();
      const newText = 'New comment text';

      await findMarkdownEditor().vm.$emit('input', newText);

      expect(updateDraft).toHaveBeenCalledWith('test-autosave-key', newText);
      expect(wrapper.vm.commentText).toBe(newText);
    });

    it('does not update draft when submitting', async () => {
      createComponent({ props: { isSubmitting: true } });
      const newText = 'New comment text';

      await findMarkdownEditor().vm.$emit('input', newText);

      expect(updateDraft).not.toHaveBeenCalled();
      expect(wrapper.vm.commentText).toBe('');
    });
  });

  describe('form submission', () => {
    it('disables submit button when no text is provided', () => {
      createComponent();

      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('disables submit button when only whitespace is provided', async () => {
      createComponent();
      wrapper.vm.commentText = '   \n\t  ';
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(true);
    });

    it('enables submit button when text is provided', async () => {
      createComponent();
      wrapper.vm.commentText = 'Test comment';
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(false);
    });

    it('disables submit button when submitting', async () => {
      createComponent({ props: { isSubmitting: true } });
      wrapper.vm.commentText = 'Test comment';
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(true);
      expect(findSubmitButton().props('loading')).toBe(true);
    });

    it('submits form successfully', async () => {
      createComponent();
      wrapper.vm.commentText = 'Test comment';

      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(detectAndConfirmSensitiveTokens).toHaveBeenCalledWith({
        content: 'Test comment',
      });

      expect(wrapper.emitted('submit')).toEqual([['Test comment']]);
    });

    it('handles sensitive token detection cancellation', async () => {
      detectAndConfirmSensitiveTokens.mockResolvedValue(false);
      createComponent();
      wrapper.vm.commentText = 'Test comment';

      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('submit')).toBeUndefined();
    });

    it('does not submit when comment text is empty', async () => {
      createComponent();
      wrapper.vm.commentText = '';

      await findSubmitButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('submit')).toBeUndefined();
    });
  });

  describe('submitSuccess watcher', () => {
    it('clears draft when submitSuccess becomes true', async () => {
      createComponent({ props: { submitSuccess: false } });
      wrapper.vm.commentText = 'Test comment';

      await wrapper.setProps({ submitSuccess: true });

      expect(clearDraft).toHaveBeenCalledWith('test-autosave-key');
    });

    it('clears comment text when submitSuccess becomes true and clearOnSuccess is true', async () => {
      createComponent({ props: { submitSuccess: false, clearOnSuccess: true } });
      wrapper.vm.commentText = 'Test comment';

      await wrapper.setProps({ submitSuccess: true });

      expect(wrapper.vm.commentText).toBe('');
      expect(clearDraft).toHaveBeenCalledWith('test-autosave-key');
    });

    it('does not clear comment text when submitSuccess becomes true and clearOnSuccess is false', async () => {
      createComponent({ props: { submitSuccess: false, clearOnSuccess: false } });
      wrapper.vm.commentText = 'Test comment';

      await wrapper.setProps({ submitSuccess: true });

      expect(wrapper.vm.commentText).toBe('Test comment');
      expect(clearDraft).toHaveBeenCalledWith('test-autosave-key');
    });

    it('does not clear anything when submitSuccess remains false', async () => {
      createComponent({ props: { submitSuccess: false } });
      wrapper.vm.commentText = 'Test comment';

      await wrapper.setProps({ submitSuccess: false });

      expect(wrapper.vm.commentText).toBe('Test comment');
      expect(clearDraft).not.toHaveBeenCalled();
    });

    it('does not clear anything when submitSuccess changes from true to false', async () => {
      createComponent({ props: { submitSuccess: true } });
      wrapper.vm.commentText = 'Test comment';

      await wrapper.setProps({ submitSuccess: false });

      expect(wrapper.vm.commentText).toBe('Test comment');
      expect(clearDraft).not.toHaveBeenCalled();
    });
  });

  describe('cancel editing', () => {
    it('emits cancel when cancel button is clicked and no changes', async () => {
      createComponent();

      await findCancelButton().vm.$emit('click');

      expect(confirmAction).not.toHaveBeenCalled();
      expect(clearDraft).toHaveBeenCalledWith('test-autosave-key');
      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });

    it('shows confirmation dialog when there are unsaved changes', async () => {
      createComponent({ props: { initialValue: 'Initial' } });
      wrapper.vm.commentText = 'Modified content';

      await findCancelButton().vm.$emit('click');

      expect(confirmAction).toHaveBeenCalledWith('Are you sure you want to cancel?', {
        primaryBtnText: 'Discard changes',
        cancelBtnText: 'Continue editing',
        primaryBtnVariant: 'danger',
      });
    });

    it('uses custom confirmation text when provided', async () => {
      const customConfirmText = 'Custom confirmation message';
      createComponent({
        props: {
          initialValue: 'Initial',
          confirmCancelText: customConfirmText,
        },
      });
      wrapper.vm.commentText = 'Modified content';

      await findCancelButton().vm.$emit('click');

      expect(confirmAction).toHaveBeenCalledWith(customConfirmText, expect.any(Object));
    });

    it('continues editing when confirmation is cancelled', async () => {
      confirmAction.mockResolvedValue(false);
      createComponent({ props: { initialValue: 'Initial' } });
      wrapper.vm.commentText = 'Modified content';

      await findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toBeUndefined();
      expect(clearDraft).not.toHaveBeenCalled();
    });

    it('clears draft and resets form when confirmed', async () => {
      confirmAction.mockResolvedValue(true);
      createComponent({ props: { initialValue: 'Initial' } });
      wrapper.vm.commentText = 'Modified content';

      await wrapper.vm.cancelEditing();

      expect(clearDraft).toHaveBeenCalledWith('test-autosave-key');
      expect(wrapper.vm.commentText).toBe('Initial');
      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });
});
