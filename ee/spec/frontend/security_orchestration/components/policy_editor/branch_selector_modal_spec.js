import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormTextarea, GlModal, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchSelectorModal from 'ee/security_orchestration/components/policy_editor/branch_selector_modal.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import branchesQuery from '~/projects/settings/branch_rules/queries/branches.query.graphql';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';

describe('BranchSelectorModal', () => {
  let wrapper;
  let requestHandler;

  const hideMock = jest.fn();
  const openMock = jest.fn();

  const VALID_BRANCHES_STRING = 'test@project, test1@project';
  const BRANCHES_WITHOUT_PROJECT_STRING = 'test@project, test1';
  const BRANCHES_WITH_DUPLICATES_STRING = 'test@project, test@project, test2@project';

  const VALID_BRANCHES = [
    {
      full_path: 'project',
      name: 'test',
      type: 'protected',
      value: 'test@project',
    },
    {
      full_path: 'project',
      name: 'test1',
      type: 'protected',
      value: 'test1@project',
    },
  ];

  const INVALID_BRANCHES = [
    {
      invalid_path: 'project',
      invalid_name: 'test',
      invalid_type: 'protected',
    },
    {
      invalid_path: 'project',
      invalid_name: 'test1',
      invalid_type: 'protected',
    },
  ];

  const mockDefaultRequestHandler = (branchNames = VALID_BRANCHES.map(({ name }) => name)) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          id: '1',
          repository: {
            branchNames,
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[branchesQuery, handler]]);
  };

  const createComponent = ({ propsData = {}, handler = mockDefaultRequestHandler() } = {}) => {
    wrapper = shallowMountExtended(BranchSelectorModal, {
      propsData,
      apolloProvider: createMockApolloProvider(handler),
      provide: {
        namespacePath: 'gitlab-policies',
      },
      stubs: {
        GlSprintf,
        GlModal: stubComponent(GlModal, {
          methods: {
            open: openMock,
            hide: hideMock,
          },
          template: RENDER_ALL_SLOTS_TEMPLATE,
        }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findAddButton = () => wrapper.findComponentByTestId('add-button');
  const findLoadingState = () => wrapper.findByTestId('loading-state');
  const findTextArea = () => wrapper.findComponent(GlFormTextarea);
  const findAsyncValidationError = () => wrapper.findByTestId('async-validation-error');
  const findValidationError = () => wrapper.findByTestId('validation-error');
  const findDuplicationError = () => wrapper.findByTestId('duplicate-error');
  const findModalDescription = () => wrapper.findByTestId('branch-exceptions-modal-description');

  describe('initial state for regular branches', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should render required components', () => {
      expect(findAddButton().exists()).toBe(true);
      expect(findModalDescription().exists()).toBe(true);
      expect(findModalDescription().text()).toBe(
        'List branches in the format branch-name@group-name/project-name, separated by a comma (,).',
      );

      expect(findTextArea().props('value')).toBe('');
      expect(findModal().props('title')).toBe('Add regular branches');
    });

    it('adds new branches', async () => {
      findTextArea().vm.$emit('input', VALID_BRANCHES_STRING);
      findAddButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('add-branches')).toEqual([
        [
          [
            {
              fullPath: 'project',
              name: 'test',
              value: 'test@project',
            },
            {
              fullPath: 'project',
              name: 'test1',
              value: 'test1@project',
            },
          ],
        ],
      ]);
    });

    it('adds current project path to branches without full path on project level', async () => {
      findTextArea().vm.$emit('input', BRANCHES_WITHOUT_PROJECT_STRING);
      findAddButton().vm.$emit('click');
      await waitForPromises();

      expect(wrapper.emitted('add-branches')).toEqual([
        [
          [
            {
              fullPath: 'project',
              name: 'test',
              value: 'test@project',
            },
            {
              fullPath: 'gitlab-policies',
              name: 'test1',
              value: 'test1@gitlab-policies',
            },
          ],
        ],
      ]);
    });

    it('should validate input for duplicates', async () => {
      findTextArea().vm.$emit('input', BRANCHES_WITH_DUPLICATES_STRING);
      await findAddButton().vm.$emit('click');

      expect(findDuplicationError().exists()).toBe(true);
      expect(wrapper.emitted('add-branches')).toBeUndefined();
    });
  });

  describe('has validation', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          hasValidation: true,
        },
      });
    });

    it('validates branches without full path on project level', async () => {
      findTextArea().vm.$emit('input', BRANCHES_WITHOUT_PROJECT_STRING);
      await findAddButton().vm.$emit('click');

      expect(findValidationError().exists()).toBe(true);
      expect(wrapper.emitted('add-branches')).toBeUndefined();
    });
  });

  describe('existing branches', () => {
    it.each`
      branches            | expectedResult
      ${VALID_BRANCHES}   | ${VALID_BRANCHES_STRING}
      ${INVALID_BRANCHES} | ${''}
    `('renders existing branches in textarea', ({ branches, expectedResult }) => {
      createComponent({
        propsData: {
          branches,
        },
      });

      expect(findTextArea().props('value')).toBe(expectedResult);
    });

    it('does not validate branches when validation is disabled', async () => {
      createComponent({
        propsData: {
          branches: VALID_BRANCHES,
        },
      });

      expect(findTextArea().props('value')).toBe(VALID_BRANCHES_STRING);

      findAddButton().vm.$emit('click');
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledTimes(0);
    });

    it('emits same branches when there are now changes', async () => {
      createComponent({
        propsData: {
          hasValidation: true,
          branches: VALID_BRANCHES,
        },
      });

      expect(findTextArea().props('value')).toBe(VALID_BRANCHES_STRING);
      findAddButton().vm.$emit('click');
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalled();
      expect(wrapper.emitted('add-branches')).toEqual([
        [
          [
            {
              fullPath: 'project',
              name: 'test',
              value: 'test@project',
            },
            {
              fullPath: 'project',
              name: 'test1',
              value: 'test1@project',
            },
          ],
        ],
      ]);
    });
  });

  describe('branches type', () => {
    it.each`
      forProtectedBranches | title
      ${true}              | ${'Add protected branches'}
      ${false}             | ${'Add regular branches'}
    `('renders correct header for branch type', ({ forProtectedBranches, title }) => {
      createComponent({
        propsData: {
          forProtectedBranches,
        },
      });

      expect(findModal().props('title')).toBe(title);
    });
  });

  describe('branches async validation', () => {
    it('renders validation error if branch does not exist', async () => {
      createComponent({
        propsData: {
          hasValidation: true,
        },
        handler: mockDefaultRequestHandler([]),
      });

      findTextArea().vm.$emit('input', VALID_BRANCHES_STRING);
      await findAddButton().vm.$emit('click');

      expect(findLoadingState().exists()).toBe(true);

      await waitForPromises();

      expect(requestHandler).toHaveBeenCalled();
      expect(findLoadingState().exists()).toBe(false);
      expect(findAsyncValidationError().exists()).toBe(true);
      expect(findAsyncValidationError().text()).toBe(
        'Branch: test was not found in project: project. Edit or remove this entry.\r\nBranch: test1 was not found in project: project. Edit or remove this entry.',
      );
    });

    it('renders validation error if project does not exist', async () => {
      createComponent({
        propsData: {
          hasValidation: true,
        },
        handler: jest.fn().mockResolvedValue({
          data: {
            project: null,
          },
        }),
      });

      findTextArea().vm.$emit('input', VALID_BRANCHES_STRING);
      await findAddButton().vm.$emit('click');

      expect(findLoadingState().exists()).toBe(true);

      await waitForPromises();

      expect(requestHandler).toHaveBeenCalled();

      expect(findAsyncValidationError().text()).toBe(
        "Can't find project: project. Edit or remove this entry.\r\nCan't find project: project. Edit or remove this entry.",
      );
    });
  });
});
