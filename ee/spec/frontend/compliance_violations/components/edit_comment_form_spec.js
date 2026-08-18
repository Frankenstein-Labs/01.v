import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import EditCommentForm from 'ee/compliance_violations/components/edit_comment_form.vue';
import BaseCommentForm from 'ee/compliance_violations/components/base_comment_form.vue';
import updateNoteMutation from 'ee/compliance_violations/graphql/mutations/update_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';

Vue.use(VueApollo);

describe('EditCommentForm', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    violationId: 'gid://gitlab/ComplianceViolation/123',
    noteId: 'gid://gitlab/Note/456',
    numericNoteId: 456,
    initialValue: 'Initial comment text',
  };

  const defaultProvide = {
    uploadsPath: '/uploads',
    markdownPreviewPath: '/preview',
  };

  const mockUpdatedNote = {
    id: 'gid://gitlab/Note/456',
    body: 'Updated comment',
    bodyHtml: '<p>Updated comment</p>',
    author: {
      name: 'Test User',
      username: 'testuser',
    },
  };

  const mockUpdateNoteSuccess = {
    data: {
      updateNote: {
        errors: [],
        note: mockUpdatedNote,
      },
    },
  };

  const mockUpdateNoteError = {
    data: {
      updateNote: {
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
            id: 'gid://gitlab/Discussion/1',
            notes: {
              nodes: [
                {
                  id: 'gid://gitlab/Note/456',
                  body: 'Original comment',
                  bodyHtml: '<p>Original comment</p>',
                },
              ],
            },
          },
          {
            id: 'gid://gitlab/Discussion/2',
            notes: {
              nodes: [
                {
                  id: 'gid://gitlab/Note/789',
                  body: 'Another comment',
                  bodyHtml: '<p>Another comment</p>',
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
    provide = {},
    updateNoteMutationHandler = jest.fn().mockResolvedValue(mockUpdateNoteSuccess),
  } = {}) => {
    mockApollo = createMockApollo([[updateNoteMutation, updateNoteMutationHandler]]);

    // Mock the cache read for updateCache method
    mockApollo.defaultClient.cache.readQuery = jest
      .fn()
      .mockReturnValue(mockComplianceViolationData);
    mockApollo.defaultClient.cache.writeQuery = jest.fn();

    wrapper = shallowMountExtended(EditCommentForm, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
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

    it('renders BaseCommentForm with correct props', () => {
      const baseForm = findBaseCommentForm();

      expect(baseForm.exists()).toBe(true);
      expect(baseForm.props()).toMatchObject({
        initialValue: 'Initial comment text',
        autosaveKey: 'compliance-violation-edit-comment-456',
        formFieldProps: {
          'aria-label': 'Edit comment',
          placeholder: 'Write a comment or drag your files here…',
          id: 'compliance-violation-edit-comment-456',
          name: 'compliance-violation-edit-comment-456',
        },
        submitButtonText: 'Save comment',
        confirmCancelText: 'Are you sure you want to cancel editing this comment?',
        isSubmitting: false,
      });
    });

    it('handles numeric noteId as string', () => {
      createComponent({ props: { numericNoteId: 456 } });

      const baseForm = findBaseCommentForm();
      expect(baseForm.props('formFieldProps').id).toBe('compliance-violation-edit-comment-456');
    });
  });

  describe('form submission', () => {
    it('updates comment successfully', async () => {
      const updateNoteMutationHandler = jest.fn().mockResolvedValue(mockUpdateNoteSuccess);
      createComponent({ updateNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Updated comment');
      await waitForPromises();

      expect(updateNoteMutationHandler).toHaveBeenCalledWith({
        input: {
          id: 'gid://gitlab/Note/456',
          body: 'Updated comment',
        },
      });

      // Check that the event was emitted
      expect(wrapper.emitted('comment-updated')).toBeDefined();
      expect(wrapper.emitted('comment-updated')).toHaveLength(1);
    });

    it('handles mutation errors', async () => {
      const updateNoteMutationHandler = jest.fn().mockResolvedValue(mockUpdateNoteError);
      createComponent({ updateNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Update comment');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when updating the comment. Please try again.'],
      ]);
      expect(wrapper.emitted('comment-updated')).toBeUndefined();
    });

    it('handles network errors', async () => {
      const updateNoteMutationHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      createComponent({ updateNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Update comment');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when updating the comment. Please try again.'],
      ]);
      expect(wrapper.emitted('comment-updated')).toBeUndefined();
    });
  });

  describe('cache updates', () => {
    it('updates Apollo cache when note is updated', async () => {
      const updateNoteMutationHandler = jest.fn().mockResolvedValue(mockUpdateNoteSuccess);
      createComponent({ updateNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Update comment');
      await waitForPromises();

      expect(mockApollo.defaultClient.cache.readQuery).toHaveBeenCalledWith({
        query: complianceViolationQuery,
        variables: { id: 'gid://gitlab/ComplianceViolation/123' },
      });

      expect(mockApollo.defaultClient.cache.writeQuery).toHaveBeenCalled();

      const writeQueryCall = mockApollo.defaultClient.cache.writeQuery.mock.calls[0][0];
      expect(writeQueryCall.query).toBe(complianceViolationQuery);
      expect(writeQueryCall.variables).toEqual({ id: 'gid://gitlab/ComplianceViolation/123' });
    });

    it('handles missing cache data gracefully', async () => {
      const freshMockApollo = createMockApollo([
        [updateNoteMutation, jest.fn().mockResolvedValue(mockUpdateNoteSuccess)],
      ]);
      freshMockApollo.defaultClient.cache.readQuery = jest.fn().mockReturnValue(null);
      freshMockApollo.defaultClient.cache.writeQuery = jest.fn();

      wrapper = shallowMountExtended(EditCommentForm, {
        propsData: defaultProps,
        provide: defaultProvide,
        apolloProvider: freshMockApollo,
      });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Update comment');
      await waitForPromises();

      expect(freshMockApollo.defaultClient.cache.writeQuery).not.toHaveBeenCalled();
    });

    it('handles missing notes in cache data gracefully', async () => {
      const cacheDataWithoutNotes = {
        projectComplianceViolation: {
          id: 'gid://gitlab/ComplianceViolation/123',
          discussions: null,
        },
      };

      const updateNoteMutationHandler = jest.fn().mockResolvedValue(mockUpdateNoteSuccess);
      createComponent({ updateNoteMutationHandler });

      mockApollo.defaultClient.cache.readQuery = jest.fn().mockReturnValue(cacheDataWithoutNotes);

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Update comment');
      await waitForPromises();

      expect(mockApollo.defaultClient.cache.writeQuery).toHaveBeenCalled();

      const writeQueryCall = mockApollo.defaultClient.cache.writeQuery.mock.calls[0][0];
      expect(writeQueryCall.query).toBe(complianceViolationQuery);
      expect(writeQueryCall.variables).toEqual({ id: 'gid://gitlab/ComplianceViolation/123' });
    });
  });

  describe('event forwarding', () => {
    it('forwards cancel event from BaseCommentForm', async () => {
      createComponent();

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('cancel');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });
});
