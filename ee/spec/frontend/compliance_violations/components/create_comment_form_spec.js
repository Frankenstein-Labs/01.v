import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CreateCommentForm from 'ee/compliance_violations/components/create_comment_form.vue';
import BaseCommentForm from 'ee/compliance_violations/components/base_comment_form.vue';
import createNoteMutation from 'ee/compliance_violations/graphql/mutations/create_compliance_violation_note.mutation.graphql';
import complianceViolationQuery from 'ee/compliance_violations/graphql/compliance_violation.query.graphql';

Vue.use(VueApollo);

describe('CreateCommentForm', () => {
  let wrapper;
  let mockApollo;

  const defaultProps = {
    violationId: 'gid://gitlab/ComplianceViolation/123',
    numericViolationId: '123',
  };

  const defaultProvide = {
    uploadsPath: '/uploads',
    markdownPreviewPath: '/preview',
  };

  const mockNote = {
    id: 'gid://gitlab/Note/456',
    body: 'Test comment',
    bodyHtml: '<p>Test comment</p>',
    author: {
      name: 'Test User',
      username: 'testuser',
    },
    discussion: {
      id: 'gid://gitlab/Discussion/789',
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
        nodes: [],
      },
    },
  };

  const createComponent = ({
    props = {},
    provide = {},
    createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess),
  } = {}) => {
    mockApollo = createMockApollo([[createNoteMutation, createNoteMutationHandler]]);

    mockApollo.defaultClient.cache.readQuery = jest
      .fn()
      .mockReturnValue(mockComplianceViolationData);
    mockApollo.defaultClient.cache.writeQuery = jest.fn();

    wrapper = shallowMountExtended(CreateCommentForm, {
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

    it('renders BaseCommentForm', () => {
      const baseForm = findBaseCommentForm();

      expect(baseForm.exists()).toBe(true);
    });
  });

  describe('form submission', () => {
    it('creates comment successfully', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test comment');
      await waitForPromises();

      expect(createNoteMutationHandler).toHaveBeenCalledWith({
        input: {
          noteableId: 'gid://gitlab/ComplianceViolation/123',
          body: 'Test comment',
        },
      });

      expect(wrapper.emitted('comment-created')).toBeDefined();
      expect(wrapper.emitted('comment-created')).toHaveLength(1);
    });

    it('handles mutation errors', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteError);
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test comment');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when creating the comment. Please try again.'],
      ]);
      expect(wrapper.emitted('comment-created')).toBeUndefined();
    });

    it('handles network errors', async () => {
      const createNoteMutationHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test comment');
      await waitForPromises();

      expect(wrapper.emitted('error')).toEqual([
        ['Something went wrong when creating the comment. Please try again.'],
      ]);
      expect(wrapper.emitted('comment-created')).toBeUndefined();
    });
  });

  describe('cache updates', () => {
    it('updates Apollo cache when note is created', async () => {
      const createNoteMutationHandler = jest.fn().mockResolvedValue(mockCreateNoteSuccess);
      createComponent({ createNoteMutationHandler });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test comment');
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
        [createNoteMutation, jest.fn().mockResolvedValue(mockCreateNoteSuccess)],
      ]);
      freshMockApollo.defaultClient.cache.readQuery = jest.fn().mockReturnValue(null);
      freshMockApollo.defaultClient.cache.writeQuery = jest.fn();

      wrapper = shallowMountExtended(CreateCommentForm, {
        propsData: defaultProps,
        provide: defaultProvide,
        apolloProvider: freshMockApollo,
      });

      const baseForm = findBaseCommentForm();
      await baseForm.vm.$emit('submit', 'Test comment');
      await waitForPromises();

      expect(freshMockApollo.defaultClient.cache.writeQuery).not.toHaveBeenCalled();
    });
  });
});
