import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ReplyCommentForm from 'ee/compliance_violations/components/reply_comment_form.vue';
import BaseCommentForm from 'ee/compliance_violations/components/base_comment_form.vue';
import createNoteMutation from 'ee/compliance_violations/graphql/mutations/create_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';

Vue.use(VueApollo);

describe('ReplyCommentForm', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    violationId: 'gid://gitlab/ComplianceViolation/123',
    discussionId: 'gid://gitlab/Discussion/456',
  };

  const mockNote = {
    id: 'gid://gitlab/Note/789',
    body: 'Test reply',
    bodyHtml: '<p>Test reply</p>',
    author: {
      name: 'Test User',
      username: 'testuser',
    },
    discussion: {
      id: 'gid://gitlab/Discussion/456',
      __typename: 'Discussion',
    },
  };

  const mockCreateNoteSuccess = {
    data: {
      createNote: {
        errors: [],
        note: mockNote,
      },
    },
  };

  const mockCreateNoteError = {
    data: {
      createNote: {
        errors: ['Something went wrong'],
        note: null,
      },
    },
  };

  const mockComplianceViolationData = {
    projectComplianceViolation: {
      id: 'gid://gitlab/ComplianceViolation/123',
      discussions: {
        nodes: [
          {
            id: 'gid://gitlab/Discussion/456',
            notes: {
              nodes: [
                {
                  id: 'gid://gitlab/Note/1',
                  body: 'First note',
                },
              ],
            },
          },
        ],
      },
    },
  };

  const createComponent = ({
    props = {},
    createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess),
  } = {}) => {
    mockApollo = createMockApollo([[createNoteMutation, createNoteMutationHandler]]);

    mockApollo.defaultClient.cache.readQuery = jest
      .fn()
      .mockReturnValue(mockComplianceViolationData);
    mockApollo.defaultClient.cache.writeQuery = jest.fn();

    wrapper = shallowMountExtended(ReplyCommentForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      apolloProvider: mockApollo,
    });
  };

  const findBaseCommentForm = () => wrapper.findComponent(BaseCommentForm);

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders BaseCommentForm', () => {
      expect(findBaseCommentForm().exists()).toBe(true);
    });
  });

  describe('form submission', () => {
    it('creates reply successfully', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test reply');
      await waitForPromises();

      expect(createNoteMutationHandler).toHaveBeenCalledWith({
        input: {
          noteableId: 'gid://gitlab/ComplianceViolation/123',
          body: 'Test reply',
          discussionId: 'gid://gitlab/Discussion/456',
        },
      });

      expect(wrapper.emitted('replied')).toBeDefined();
      expect(wrapper.emitted('replied')).toHaveLength(1);
    });

    it('handles mutation errors', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteError);
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test reply');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when creating the reply. Please try again.'],
      ]);
      expect(wrapper.emitted('replied')).toBeUndefined();
    });

    it('handles network errors', async () => {
      const createNoteMutationHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test reply');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when creating the reply. Please try again.'],
      ]);
      expect(wrapper.emitted('replied')).toBeUndefined();
    });

    it('sets submitting state during submission', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      expect(baseForm.props('isSubmitting')).toBe(false);

      baseForm.vm.$emit('submit', 'Test reply');
      await waitForPromises();

      expect(baseForm.props('isSubmitting')).toBe(false);
    });
  });

  describe('cache updates', () => {
    it('updates Apollo cache when reply is created', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test reply');
      await waitForPromises();

      expect(mockApollo.defaultClient.cache.readQuery).toHaveBeenCalledWith({
        query: complianceViolationQuery,
        variables: { id: 'gid://gitlab/ComplianceViolation/123' },
      });

      expect(mockApollo.defaultClient.cache.writeQuery).toHaveBeenCalled();

      const writeQueryCall = mockApollo.defaultClient.cache.writeQuery.mock.calls[0][0];
      expect(writeQueryCall.query).toBe(complianceViolationQuery);
      expect(writeQueryCall.variables).toEqual({ id: 'gid://gitlab/ComplianceViolation/123' });

      const updatedData = writeQueryCall.data;
      const updatedDiscussion = updatedData.projectComplianceViolation.discussions.nodes.find(
        (d) => d.id === 'gid://gitlab/Discussion/456',
      );

      expect(updatedDiscussion.notes.nodes).toHaveLength(2);
    });

    it('handles missing cache data gracefully', async () => {
      const freshMockApollo = createMockApollo([
        [createNoteMutation, jest.fn().mockResolvedValue(mockCreateNoteSuccess)],
      ]);
      freshMockApollo.defaultClient.cache.readQuery = jest.fn().mockReturnValue(null);
      freshMockApollo.defaultClient.cache.writeQuery = jest.fn();

      wrapper = shallowMountExtended(ReplyCommentForm, {
        propsData: defaultProps,
        apolloProvider: freshMockApollo,
      });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test reply');
      await waitForPromises();

      expect(freshMockApollo.defaultClient.cache.writeQuery).not.toHaveBeenCalled();
    });

    it('only updates the correct discussion', async () => {
      const dataWithMultipleDiscussions = {
        projectComplianceViolation: {
          id: 'gid://gitlab/ComplianceViolation/123',
          discussions: {
            nodes: [
              {
                id: 'gid://gitlab/Discussion/456',
                notes: {
                  nodes: [{ id: 'gid://gitlab/Note/1', body: 'First note' }],
                },
              },
              {
                id: 'gid://gitlab/Discussion/789',
                notes: {
                  nodes: [{ id: 'gid://gitlab/Note/2', body: 'Other discussion' }],
                },
              },
            ],
          },
        },
      };

      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      mockApollo = createMockApollo([[createNoteMutation, createNoteMutationHandler]]);
      mockApollo.defaultClient.cache.readQuery = jest
        .fn()
        .mockReturnValue(dataWithMultipleDiscussions);
      mockApollo.defaultClient.cache.writeQuery = jest.fn();

      wrapper = shallowMountExtended(ReplyCommentForm, {
        propsData: defaultProps,
        apolloProvider: mockApollo,
      });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test reply');
      await waitForPromises();

      const writeQueryCall = mockApollo.defaultClient.cache.writeQuery.mock.calls[0][0];
      const updatedData = writeQueryCall.data;
      const discussions = updatedData.projectComplianceViolation.discussions.nodes;

      expect(discussions[0].notes.nodes).toHaveLength(2);
      expect(discussions[1].notes.nodes).toHaveLength(1);
    });
  });

  describe('cancel functionality', () => {
    it('emits cancel event when form is cancelled', async () => {
      createComponent();

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('cancel');

      expect(wrapper.emitted('cancel')).toBeDefined();
      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });
});
