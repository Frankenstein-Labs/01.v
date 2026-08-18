import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAvatar, GlAvatarLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { getLocationHash } from '~/lib/utils/url_utility';
import toast from '~/vue_shared/plugins/global_toast';
import NoteHeader from '~/notes/components/note_header.vue';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import EditedAt from '~/issues/show/components/edited.vue';
import DiscussionNote from 'ee/compliance_violations/components/discussion_note.vue';
import EditCommentForm from 'ee/compliance_violations/components/edit_comment_form.vue';
import destroyComplianceViolationNoteMutation from 'ee/compliance_violations/graphql/mutations/destroy_compliance_violation_note.mutation.graphql';
import toggleComplianceViolationNoteAwardEmojiMutation from 'ee/compliance_violations/graphql/mutations/toggle_compliance_violation_note_award_emoji.mutation.graphql';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import {
  mockNote,
  mockNoteWithAwards,
  mockNoteWithEdit,
  mockDeleteNoteSuccess,
  mockDeleteNoteError,
  mockToggleAwardEmojiSuccess,
  mockToggleAwardEmojiError,
} from './mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/copy_to_clipboard');
jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  getLocationHash: jest.fn(),
}));
jest.mock('~/vue_shared/plugins/global_toast');

describe('DiscussionNote', () => {
  let wrapper;

  const createDropdownStub = () => {
    const mockClose = jest.fn();
    return {
      stub: {
        GlDisclosureDropdown: stubComponent(
          {},
          {
            methods: {
              close: mockClose,
            },
          },
        ),
      },
      mockClose,
    };
  };

  const createComponent = ({
    props = {},
    deleteNoteMutationHandler = jest.fn().mockResolvedValue(mockDeleteNoteSuccess),
    toggleAwardEmojiMutationHandler = jest.fn().mockResolvedValue(mockToggleAwardEmojiSuccess),
    stubs = {},
  } = {}) => {
    const apolloProvider = createMockApollo([
      [destroyComplianceViolationNoteMutation, deleteNoteMutationHandler],
      [toggleComplianceViolationNoteAwardEmojiMutation, toggleAwardEmojiMutationHandler],
    ]);

    wrapper = shallowMountExtended(DiscussionNote, {
      propsData: {
        note: mockNote,
        violationId: 'gid://gitlab/ComplianceViolation/123',
        ...props,
      },
      apolloProvider,
      stubs,
    });
  };

  const findTimelineEntryItem = () => wrapper.findComponent(TimelineEntryItem);
  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findAvatarLink = () => wrapper.findComponent(GlAvatarLink);
  const findNoteHeader = () => wrapper.findComponent(NoteHeader);
  const findNoteText = () => wrapper.findByTestId('discussion-note-text');
  const findActionsDropdown = () => wrapper.findComponentByTestId('note-actions-dropdown');
  const findCopyLinkAction = () => wrapper.findComponentByTestId('copy-link-action');
  const findDeleteNoteAction = () => wrapper.findComponentByTestId('delete-note-action');
  const findDeleteNoteModal = () => wrapper.findComponent({ ref: 'deleteNoteModal' });
  const findEditButton = () => wrapper.findComponentByTestId('edit-note-button');
  const findReplyButton = () => wrapper.findComponentByTestId('reply-note-button');
  const findEditedAt = () => wrapper.findComponent(EditedAt);
  const findEditCommentForm = () => wrapper.findComponent(EditCommentForm);
  const findEmojiPicker = () => wrapper.findComponentByTestId('note-emoji-button');
  const findAwardsList = () => wrapper.findComponentByTestId('note-awards-list');

  beforeEach(() => {
    getLocationHash.mockReturnValue('');
    toast.mockClear();
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders TimelineEntryItem with correct props', () => {
      const timelineItem = findTimelineEntryItem();

      expect(timelineItem.exists()).toBe(true);
      expect(timelineItem.attributes('id')).toBe('note_123');
      expect(timelineItem.classes()).toContain('note');
      expect(timelineItem.classes()).toContain('note-wrapper');
      expect(timelineItem.classes()).toContain('note-comment');
    });

    it('renders avatar with correct props', () => {
      const avatar = findAvatar();

      expect(avatar.exists()).toBe(true);
      expect(avatar.props()).toMatchObject({
        src: mockNote.author.avatarUrl,
        entityName: mockNote.author.username,
        alt: mockNote.author.name,
        size: 32,
      });
    });

    it('renders avatar link with correct props', () => {
      const avatarLink = findAvatarLink();

      expect(avatarLink.exists()).toBe(true);
      expect(avatarLink.attributes('href')).toBe(mockNote.author.webUrl);
      expect(avatarLink.attributes('data-user-id')).toBe('456');
      expect(avatarLink.attributes('data-username')).toBe(mockNote.author.username);
      expect(avatarLink.classes()).toContain('js-user-link');
    });

    it('renders note header with correct props', () => {
      const noteHeader = findNoteHeader();

      expect(noteHeader.exists()).toBe(true);
      expect(noteHeader.props()).toMatchObject({
        author: mockNote.author,
        createdAt: mockNote.createdAt,
        noteId: 123,
        noteUrl: '#note_123',
      });
    });

    it('renders the correct note', () => {
      expect(findNoteHeader().props('noteId')).toBe(123);
      expect(findNoteHeader().props('noteUrl')).toBe('#note_123');
    });

    it('renders note body with HTML content', () => {
      const noteText = findNoteText();

      expect(noteText.exists()).toBe(true);
      expect(noteText.html()).toContain('<p>This is a discussion note</p>');
      expect(noteText.classes()).toContain('note-text');
      expect(noteText.classes()).toContain('md');
    });

    it('renders actions dropdown with correct props', () => {
      const dropdown = findActionsDropdown();

      expect(dropdown.exists()).toBe(true);
      expect(dropdown.props()).toMatchObject({
        icon: 'ellipsis_v',
        textSrOnly: true,
        placement: 'bottom-end',
        category: 'tertiary',
        noCaret: true,
      });
      expect(dropdown.attributes('title')).toBe('More actions');
    });

    it('renders copy link action', () => {
      const copyAction = findCopyLinkAction();

      expect(copyAction.exists()).toBe(true);
    });

    it('renders delete note action', () => {
      const deleteAction = findDeleteNoteAction();

      expect(deleteAction.exists()).toBe(true);
      expect(deleteAction.props('variant')).toBe('danger');
    });

    it('renders edit button', () => {
      const editButton = findEditButton();

      expect(editButton.exists()).toBe(true);
      expect(editButton.attributes('title')).toBe('Edit comment');
      expect(editButton.attributes('aria-label')).toBe('Edit comment');
    });

    it('does not render reply button when isFirstNote is false', () => {
      expect(findReplyButton().exists()).toBe(false);
    });

    it('does not render edit comment form initially', () => {
      expect(findEditCommentForm().exists()).toBe(false);
    });

    it('does not render EditedAt component when note has not been edited', () => {
      expect(findEditedAt().exists()).toBe(false);
    });

    it('renders with correct timeline structure', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  describe('note targeting', () => {
    it('applies target class when note is targeted', () => {
      getLocationHash.mockReturnValue('note_123');
      createComponent();

      expect(findTimelineEntryItem().classes()).toContain('target');
    });

    it('does not apply target class when note is not targeted', () => {
      getLocationHash.mockReturnValue('note_456');
      createComponent();

      expect(findTimelineEntryItem().classes()).not.toContain('target');
    });
  });

  describe('copy link functionality', () => {
    beforeEach(() => {
      setWindowLocation('https://example.com/compliance/violations/123');
    });

    it('copies the correct URL when copy link is clicked', async () => {
      const { stub, mockClose } = createDropdownStub();
      createComponent({ stubs: stub });

      await findCopyLinkAction().vm.$emit('action');

      expect(copyToClipboard).toHaveBeenCalledWith(
        'https://example.com/compliance/violations/123#note_123',
      );
      expect(toast).toHaveBeenCalledWith('Link copied to clipboard.');
      expect(mockClose).toHaveBeenCalled();
    });
  });

  describe('delete note functionality', () => {
    let deleteNoteMutationHandler;

    beforeEach(() => {
      deleteNoteMutationHandler = jest.fn().mockResolvedValue(mockDeleteNoteSuccess);
      createComponent({
        deleteNoteMutationHandler,
      });
    });

    it('deletes note successfully when modal is confirmed', async () => {
      const modal = findDeleteNoteModal();

      await modal.vm.$emit('primary');
      await waitForPromises();

      expect(deleteNoteMutationHandler).toHaveBeenCalledTimes(1);
      expect(deleteNoteMutationHandler).toHaveBeenCalledWith({
        input: {
          id: mockNote.id,
        },
      });
      expect(toast).toHaveBeenCalledWith('Comment deleted successfully.');
    });

    it('handles mutation errors', async () => {
      const errorHandler = jest.fn().mockResolvedValue(mockDeleteNoteError);
      createComponent({
        deleteNoteMutationHandler: errorHandler,
      });

      const modal = findDeleteNoteModal();
      await modal.vm.$emit('primary');
      await waitForPromises();

      expect(errorHandler).toHaveBeenCalledTimes(1);
      expect(errorHandler).toHaveBeenCalledWith({
        input: {
          id: mockNote.id,
        },
      });
      expect(toast).toHaveBeenCalledWith(
        'Something went wrong when deleting the comment. Please try again.',
      );
    });

    it('handles network errors', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      createComponent({
        deleteNoteMutationHandler: errorHandler,
      });

      const modal = findDeleteNoteModal();
      await modal.vm.$emit('primary');
      await waitForPromises();

      expect(errorHandler).toHaveBeenCalledTimes(1);
      expect(toast).toHaveBeenCalledWith(
        'Something went wrong when deleting the comment. Please try again.',
      );
    });
  });

  describe('edit comment functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows edit form when edit button is clicked', async () => {
      expect(findNoteText().exists()).toBe(true);
      expect(findEditCommentForm().exists()).toBe(false);

      await findEditButton().vm.$emit('click');
      await nextTick();

      expect(findNoteText().exists()).toBe(false);
      expect(findEditCommentForm().exists()).toBe(true);
    });

    it('hides note actions when in edit mode', async () => {
      expect(findActionsDropdown().exists()).toBe(true);
      expect(findEditButton().exists()).toBe(true);

      await findEditButton().vm.$emit('click');
      await nextTick();

      expect(findActionsDropdown().exists()).toBe(false);
      expect(findEditButton().exists()).toBe(false);
    });

    it('exits edit mode when form emits cancel', async () => {
      await findEditButton().vm.$emit('click');
      await nextTick();

      await findEditCommentForm().vm.$emit('cancel');
      await waitForPromises();

      expect(findNoteText().exists()).toBe(true);
      expect(findActionsDropdown().exists()).toBe(true);
    });

    it('exits edit mode when comment is updated', async () => {
      await findEditButton().vm.$emit('click');
      await nextTick();

      await findEditCommentForm().vm.$emit('comment-updated');
      await waitForPromises();

      expect(findNoteText().exists()).toBe(true);
      expect(findActionsDropdown().exists()).toBe(true);
    });

    it('emits error event when edit form emits error', async () => {
      const errorMessage = 'Failed to update form';
      await findEditButton().vm.$emit('click');
      await nextTick();

      await findEditCommentForm().vm.$emit('error', errorMessage);
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([[errorMessage]]);
    });
  });

  describe('edited note display', () => {
    it('renders EditedAt component when note has been edited', () => {
      createComponent({
        props: {
          note: mockNoteWithEdit,
        },
      });

      const editedAt = findEditedAt();
      expect(editedAt.exists()).toBe(true);
    });

    it('does not render EditedAt component when in edit mode', async () => {
      createComponent({
        props: {
          note: mockNoteWithEdit,
        },
      });

      expect(findEditedAt().exists()).toBe(true);

      await findEditButton().vm.$emit('click');
      await nextTick();

      expect(findEditedAt().exists()).toBe(false);
    });
  });

  describe('empty content handling', () => {
    it('renders when bodyHtml is empty', () => {
      createComponent({
        props: {
          note: {
            ...mockNote,
            bodyHtml: '',
          },
        },
      });

      const noteText = findNoteText();
      expect(noteText.exists()).toBe(true);
      expect(noteText.text()).toBe('');
    });
  });

  describe('reply button', () => {
    it('renders reply button when isFirstNote is true', () => {
      createComponent({ props: { isFirstNote: true } });

      const replyButton = findReplyButton();
      expect(replyButton.exists()).toBe(true);
    });

    it('emits start-replying when reply button is clicked', async () => {
      createComponent({ props: { isFirstNote: true } });

      await findReplyButton().vm.$emit('click');

      expect(wrapper.emitted('start-replying')).toBeDefined();
      expect(wrapper.emitted('start-replying')).toHaveLength(1);
    });

    it('does not render reply button when in edit mode', async () => {
      createComponent({ props: { isFirstNote: true } });

      expect(findReplyButton().exists()).toBe(true);

      await findEditButton().vm.$emit('click');
      await nextTick();

      expect(findReplyButton().exists()).toBe(false);
    });
  });

  describe('emoji functionality', () => {
    beforeEach(() => {
      window.gon = { current_user_id: 456 };
    });

    afterEach(() => {
      delete window.gon;
    });

    describe('emoji picker', () => {
      it('does not render emoji picker when in edit mode', async () => {
        createComponent();

        expect(findEmojiPicker().exists()).toBe(true);

        await findEditButton().vm.$emit('click');
        await nextTick();

        expect(findEmojiPicker().exists()).toBe(false);
      });

      it('calls setAwardEmoji when emoji is selected', async () => {
        const toggleAwardEmojiMutationHandler = jest
          .fn()
          .mockResolvedValue(mockToggleAwardEmojiSuccess);
        createComponent({ toggleAwardEmojiMutationHandler });

        const emojiPicker = findEmojiPicker();
        await emojiPicker.vm.$emit('click', 'thumbsup');
        await waitForPromises();

        expect(toggleAwardEmojiMutationHandler).toHaveBeenCalledWith({
          awardableId: mockNote.id,
          name: 'thumbsup',
        });
      });
    });

    describe('awards list', () => {
      it('does not render awards list when note has no awards', () => {
        createComponent();

        const awardsList = findAwardsList();
        expect(awardsList.exists()).toBe(false);
      });

      it('renders awards list when note has awards', () => {
        createComponent({
          props: {
            note: mockNoteWithAwards,
          },
        });

        const awardsList = findAwardsList();
        expect(awardsList.exists()).toBe(true);
      });

      it('does not render awards list when in edit mode', async () => {
        createComponent({
          props: {
            note: mockNoteWithAwards,
          },
        });

        expect(findAwardsList().exists()).toBe(true);

        await findEditButton().vm.$emit('click');
        await nextTick();

        expect(findAwardsList().exists()).toBe(false);
      });

      it('calls setAwardEmoji when award is clicked', async () => {
        const toggleAwardEmojiMutationHandler = jest
          .fn()
          .mockResolvedValue(mockToggleAwardEmojiSuccess);
        createComponent({
          props: {
            note: mockNoteWithAwards,
          },
          toggleAwardEmojiMutationHandler,
        });

        const awardsList = findAwardsList();
        await awardsList.vm.$emit('award', 'heart');
        await waitForPromises();

        expect(toggleAwardEmojiMutationHandler).toHaveBeenCalledWith({
          awardableId: mockNote.id,
          name: 'heart',
        });
      });
    });

    describe('setAwardEmoji method', () => {
      it('handles successful emoji toggle', async () => {
        const toggleAwardEmojiMutationHandler = jest
          .fn()
          .mockResolvedValue(mockToggleAwardEmojiSuccess);
        createComponent({ toggleAwardEmojiMutationHandler });

        const emojiPicker = findEmojiPicker();
        await emojiPicker.vm.$emit('click', 'thumbsup');
        await waitForPromises();

        expect(toggleAwardEmojiMutationHandler).toHaveBeenCalledWith({
          awardableId: mockNote.id,
          name: 'thumbsup',
        });
        expect(toast).not.toHaveBeenCalled();
      });

      it('handles emoji toggle errors from mutation', async () => {
        const toggleAwardEmojiMutationHandler = jest
          .fn()
          .mockResolvedValue(mockToggleAwardEmojiError);
        createComponent({ toggleAwardEmojiMutationHandler });

        const emojiPicker = findEmojiPicker();
        await emojiPicker.vm.$emit('click', 'thumbsup');
        await waitForPromises();

        expect(toggleAwardEmojiMutationHandler).toHaveBeenCalledWith({
          awardableId: mockNote.id,
          name: 'thumbsup',
        });
        expect(toast).toHaveBeenCalledWith('Failed to toggle emoji reaction.');
      });

      it('handles network errors', async () => {
        const toggleAwardEmojiMutationHandler = jest
          .fn()
          .mockRejectedValue(new Error('Network error'));
        createComponent({ toggleAwardEmojiMutationHandler });

        const emojiPicker = findEmojiPicker();
        await emojiPicker.vm.$emit('click', 'thumbsup');
        await waitForPromises();

        expect(toast).toHaveBeenCalledWith('Failed to toggle emoji reaction.');
      });
    });
  });
});
