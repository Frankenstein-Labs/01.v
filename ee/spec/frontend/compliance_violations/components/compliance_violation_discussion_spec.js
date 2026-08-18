import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ComplianceViolationDiscussion from 'ee/compliance_violations/components/compliance_violation_discussion.vue';
import DiscussionNote from 'ee/compliance_violations/components/discussion_note.vue';
import ReplyCommentForm from 'ee/compliance_violations/components/reply_comment_form.vue';
import ToggleRepliesWidget from '~/notes/components/toggle_replies_widget.vue';
import DiscussionNotesRepliesWrapper from '~/notes/components/discussion_notes_replies_wrapper.vue';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';

describe('ComplianceViolationDiscussion', () => {
  let wrapper;

  const mockDiscussion = {
    id: 'gid://gitlab/Discussion/1',
    notes: {
      nodes: [
        {
          id: 'gid://gitlab/Note/1',
          body: 'First note',
          bodyHtml: '<p>First note</p>',
          author: {
            id: 'gid://gitlab/User/1',
            name: 'Test User',
            username: 'testuser',
            avatarUrl: 'https://example.com/avatar.jpg',
            webUrl: 'https://example.com/testuser',
          },
          createdAt: '2023-01-01T00:00:00Z',
          discussion: {
            id: 'gid://gitlab/Discussion/1',
          },
        },
        {
          id: 'gid://gitlab/Note/2',
          body: 'Reply note',
          bodyHtml: '<p>Reply note</p>',
          author: {
            id: 'gid://gitlab/User/2',
            name: 'Another User',
            username: 'anotheruser',
            avatarUrl: 'https://example.com/avatar2.jpg',
            webUrl: 'https://example.com/anotheruser',
          },
          createdAt: '2023-01-02T00:00:00Z',
          discussion: {
            id: 'gid://gitlab/Discussion/1',
          },
        },
      ],
    },
  };

  const mockDiscussionWithoutReplies = {
    id: 'gid://gitlab/Discussion/2',
    notes: {
      nodes: [
        {
          id: 'gid://gitlab/Note/3',
          body: 'Single note',
          bodyHtml: '<p>Single note</p>',
          author: {
            id: 'gid://gitlab/User/1',
            name: 'Test User',
            username: 'testuser',
            avatarUrl: 'https://example.com/avatar.jpg',
            webUrl: 'https://example.com/testuser',
          },
          createdAt: '2023-01-01T00:00:00Z',
          discussion: {
            id: 'gid://gitlab/Discussion/2',
          },
        },
      ],
    },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ComplianceViolationDiscussion, {
      propsData: {
        discussion: mockDiscussion,
        violationId: 'gid://gitlab/ComplianceViolation/123',
        ...props,
      },
    });
  };

  const findTimelineEntryItem = () => wrapper.findComponent(TimelineEntryItem);
  const findDiscussionNotes = () => wrapper.findAllComponents(DiscussionNote);
  const findFirstNote = () => findDiscussionNotes().at(0);
  const findReplyNotes = () => findDiscussionNotes().wrappers.slice(1);
  const findToggleRepliesWidget = () => wrapper.findComponent(ToggleRepliesWidget);
  const findDiscussionNotesRepliesWrapper = () =>
    wrapper.findComponent(DiscussionNotesRepliesWrapper);
  const findReplyCommentForm = () => wrapper.findComponent(ReplyCommentForm);
  const findReplyPlaceholder = () => wrapper.findComponentByTestId('discussion-reply-tab');
  const findNoteContainer = () => wrapper.findByTestId('note-container');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders TimelineEntryItem', () => {
      expect(findTimelineEntryItem().exists()).toBe(true);
    });

    it('renders the first note with isFirstNote prop', () => {
      const firstNote = findFirstNote();

      expect(firstNote.exists()).toBe(true);
      expect(firstNote.props()).toMatchObject({
        note: mockDiscussion.notes.nodes[0],
        violationId: 'gid://gitlab/ComplianceViolation/123',
        isFirstNote: true,
      });
    });

    it('renders note container', () => {
      expect(findNoteContainer().exists()).toBe(true);
    });

    it('renders DiscussionNotesRepliesWrapper', () => {
      expect(findDiscussionNotesRepliesWrapper().exists()).toBe(true);
    });
  });

  describe('discussion with replies', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders ToggleRepliesWidget when there are replies', () => {
      const toggleWidget = findToggleRepliesWidget();

      expect(toggleWidget.exists()).toBe(true);
      expect(toggleWidget.props()).toMatchObject({
        collapsed: false,
        replies: mockDiscussion.notes.nodes.slice(1),
      });
    });

    it('renders all reply notes', () => {
      const replyNotes = findReplyNotes();

      expect(replyNotes).toHaveLength(1);
      expect(replyNotes[0].props()).toMatchObject({
        note: mockDiscussion.notes.nodes[1],
        violationId: 'gid://gitlab/ComplianceViolation/123',
        isFirstNote: false,
      });
    });

    it('renders reply placeholder when not replying', () => {
      expect(findReplyPlaceholder().exists()).toBe(true);
    });

    it('does not render ReplyCommentForm initially', () => {
      expect(findReplyCommentForm().exists()).toBe(false);
    });
  });

  describe('discussion without replies', () => {
    beforeEach(() => {
      createComponent({ discussion: mockDiscussionWithoutReplies });
    });

    it('does not render ToggleRepliesWidget', () => {
      expect(findToggleRepliesWidget().exists()).toBe(false);
    });

    it('renders only the first note', () => {
      expect(findDiscussionNotes()).toHaveLength(1);
    });

    it('renders reply placeholder', () => {
      expect(findReplyPlaceholder().exists()).toBe(true);
    });
  });

  describe('toggling discussion', () => {
    beforeEach(() => {
      createComponent();
    });

    it('collapses discussion when toggle is clicked', async () => {
      expect(findReplyNotes()).toHaveLength(1);

      await findToggleRepliesWidget().vm.$emit('toggle');
      await nextTick();

      expect(findReplyNotes()).toHaveLength(0);
      expect(findReplyPlaceholder().exists()).toBe(false);
    });

    it('expands discussion when toggle is clicked again', async () => {
      await findToggleRepliesWidget().vm.$emit('toggle');
      await nextTick();

      expect(findToggleRepliesWidget().props('collapsed')).toBe(true);

      await findToggleRepliesWidget().vm.$emit('toggle');
      await nextTick();

      expect(findToggleRepliesWidget().props('collapsed')).toBe(false);
      expect(findReplyNotes()).toHaveLength(1);
    });
  });

  describe('reply functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows reply form when placeholder is focused', async () => {
      expect(findReplyCommentForm().exists()).toBe(false);
      expect(findReplyPlaceholder().exists()).toBe(true);

      await findReplyPlaceholder().vm.$emit('focus');
      await nextTick();

      expect(findReplyCommentForm().exists()).toBe(true);
      expect(findReplyPlaceholder().exists()).toBe(false);
    });

    it('shows reply form when first note emits start-replying', async () => {
      expect(findReplyCommentForm().exists()).toBe(false);

      await findFirstNote().vm.$emit('start-replying');
      await nextTick();

      expect(findReplyCommentForm().exists()).toBe(true);
      expect(findReplyPlaceholder().exists()).toBe(false);
    });

    it('expands discussion when showing reply form', async () => {
      await findToggleRepliesWidget().vm.$emit('toggle');
      await nextTick();

      expect(findReplyNotes()).toHaveLength(0);

      await findFirstNote().vm.$emit('start-replying');
      await nextTick();

      expect(findReplyNotes()).toHaveLength(1);
    });

    it('hides reply form when cancel is emitted', async () => {
      await findReplyPlaceholder().vm.$emit('focus');
      await nextTick();

      expect(findReplyCommentForm().exists()).toBe(true);

      await findReplyCommentForm().vm.$emit('cancel');
      await nextTick();

      expect(findReplyCommentForm().exists()).toBe(false);
      expect(findReplyPlaceholder().exists()).toBe(true);
    });

    it('hides reply form when replied is emitted', async () => {
      await findReplyPlaceholder().vm.$emit('focus');
      await nextTick();

      expect(findReplyCommentForm().exists()).toBe(true);

      await findReplyCommentForm().vm.$emit('replied');
      await nextTick();

      expect(findReplyCommentForm().exists()).toBe(false);
      expect(findReplyPlaceholder().exists()).toBe(true);
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits error when first note emits error', async () => {
      const errorMessage = 'Something went wrong';

      await findFirstNote().vm.$emit('error', errorMessage);

      expect(wrapper.emitted('error')).toEqual([[errorMessage]]);
    });

    it('emits error when reply note emits error', async () => {
      const errorMessage = 'Reply error';
      const replyNote = findReplyNotes()[0];

      await replyNote.vm.$emit('error', errorMessage);

      expect(wrapper.emitted('error')).toEqual([[errorMessage]]);
    });

    it('emits error when reply form emits error', async () => {
      const errorMessage = 'Form error';

      await findReplyPlaceholder().vm.$emit('focus');
      await nextTick();

      await findReplyCommentForm().vm.$emit('error', errorMessage);

      expect(wrapper.emitted('error')).toEqual([[errorMessage]]);
    });
  });
});
