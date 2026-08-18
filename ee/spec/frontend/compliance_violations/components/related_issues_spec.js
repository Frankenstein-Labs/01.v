import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RelatedIssues from 'ee/compliance_violations/components/related_issues.vue';
import linkProjectComplianceViolationIssue from 'ee/compliance_violations/graphql/mutations/link_project_compliance_violation_issue.mutation.graphql';
import unlinkProjectComplianceViolationIssue from 'ee/compliance_violations/graphql/mutations/unlink_project_compliance_violation_issue.mutation.graphql';
import { createAlert } from '~/alert';
import { TYPE_ISSUE } from '~/issues/constants';
import RelatedIssuesBlock from '~/related_issues/components/related_issues_block.vue';
import { PathIdSeparator } from '~/related_issues/constants';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('Compliance Violation related issues component', () => {
  let wrapper;
  let mockApollo;

  const violationId = 'gid://gitlab/ComplianceManagement::Projects::ComplianceViolation/123';
  const projectPath = 'project/path';

  const issue1 = {
    id: 'gid://gitlab/Issue/3',
    iid: '3',
    referencePath: 'project/path#3',
    state: 'opened',
    title: 'First issue',
    webUrl: 'http://gitlab.com/issues/3',
  };
  const issue2 = {
    id: 'gid://gitlab/Issue/25',
    iid: '25',
    referencePath: 'other/project#25',
    state: 'closed',
    title: 'Second issue',
    webUrl: 'http://gitlab.com/issues/25',
  };

  const defaultProps = {
    issues: [issue1, issue2],
    violationId,
    projectPath,
  };

  const mockLinkMutationSuccess = {
    data: {
      linkProjectComplianceViolationIssue: {
        errors: [],
        violation: {
          issues: {
            nodes: [
              issue1,
              issue2,
              {
                id: 'gid://gitlab/Issue/99',
                iid: '99',
                referencePath: 'project/path#99',
                state: 'opened',
                title: 'New issue',
                webUrl: 'http://gitlab.com/issues/99',
              },
            ],
          },
        },
      },
    },
  };

  const mockUnlinkMutationSuccess = {
    data: {
      unlinkProjectComplianceViolationIssue: {
        errors: [],
        violation: {
          issues: {
            nodes: [issue2],
          },
        },
      },
    },
  };

  const createWrapper = ({
    props = {},
    data = {},
    linkMutationHandler = jest.fn().mockResolvedValue(mockLinkMutationSuccess),
    unlinkMutationHandler = jest.fn().mockResolvedValue(mockUnlinkMutationSuccess),
  } = {}) => {
    mockApollo = createMockApollo([
      [linkProjectComplianceViolationIssue, linkMutationHandler],
      [unlinkProjectComplianceViolationIssue, unlinkMutationHandler],
    ]);

    wrapper = shallowMount(RelatedIssues, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      data: () => data,
      apolloProvider: mockApollo,
    });

    // Need this special check because RelatedIssues creates the store and uses its state in the data function
    if (data.state) {
      wrapper.vm.store.state = data.state;
    }
  };

  const relatedIssuesBlock = () => wrapper.findComponent(RelatedIssuesBlock);
  const blockProp = (prop) => relatedIssuesBlock().props(prop);
  const blockEmit = (eventName, data) => relatedIssuesBlock().vm.$emit(eventName, data);

  beforeEach(() => {
    window.gl = { GfmAutoComplete: { dataSources: {} } };
  });

  afterEach(() => {
    mockApollo = null;
  });

  it('passes the expected props to the RelatedIssuesBlock component', () => {
    const data = {
      isFetching: true,
      isSubmitting: true,
      isFormVisible: true,
      inputValue: 'input value',
      state: {
        relatedIssues: [{}, {}, {}],
        pendingReferences: ['#1', '#2', '#3'],
      },
    };

    createWrapper({ data });

    expect(relatedIssuesBlock().props()).toMatchObject({
      isFetching: data.isFetching,
      isSubmitting: data.isSubmitting,
      relatedIssues: data.state.relatedIssues,
      canAdmin: true,
      pendingReferences: data.state.pendingReferences,
      isFormVisible: data.isFormVisible,
      inputValue: data.inputValue,
      autoCompleteSources: window.gl.GfmAutoComplete.dataSources,
      issuableType: TYPE_ISSUE,
      pathIdSeparator: PathIdSeparator.Issue,
      showCategorizedIssues: false,
      headerText: 'Related issues',
      addButtonText: 'Add existing issue',
    });
  });

  describe('initial setup', () => {
    it('initializes with provided issues', () => {
      createWrapper();
      expect(blockProp('relatedIssues')).toHaveLength(2);
      // Check that the issues are formatted correctly by the getFormattedIssue helper
      expect(blockProp('relatedIssues')[0]).toMatchObject({
        id: 3, // converted from GraphQL ID
        iid: 3, // converted from string
        state: issue1.state,
        path: issue1.webUrl, // webUrl is mapped to path
        reference: issue1.reference,
        projectPath: 'project/path',
      });
      expect(blockProp('relatedIssues')[1]).toMatchObject({
        id: 25,
        iid: 25,
        state: issue2.state,
        path: issue2.webUrl,
        reference: issue2.referencePath, // shows different project reference path
        projectPath: 'other/project',
      });
    });

    it('sets up autocomplete sources', () => {
      createWrapper();
      // The component uses $options.autoCompleteSources which is set as a component property
      expect(blockProp('autoCompleteSources')).toEqual(window.gl.GfmAutoComplete.dataSources);
    });
  });

  describe('add related issue', () => {
    let linkMutationHandler;

    beforeEach(() => {
      linkMutationHandler = jest.fn().mockResolvedValue(mockLinkMutationSuccess);
      createWrapper({
        data: { isFormVisible: true },
        linkMutationHandler,
      });
    });

    it('adds related issue successfully', async () => {
      blockEmit('add-issuable-form-submit', { pendingReferences: '#99' });
      await waitForPromises();

      expect(linkMutationHandler).toHaveBeenCalledWith({
        input: {
          violationId,
          projectPath,
          issueIid: '99',
        },
      });
      // Form visibility depends on whether there are errors
      expect(blockProp('inputValue')).toBe('');
    });

    it('adds multiple issues', async () => {
      blockEmit('add-issuable-form-submit', { pendingReferences: '#1 #2 #3' });
      await waitForPromises();

      expect(linkMutationHandler).toHaveBeenCalledTimes(3);
      // Form stays visible if there are errors, but we're mocking success so it should be hidden
      // However, the component might keep it visible during processing
      expect(blockProp('inputValue')).toBe('');
    });

    it('handles mutation errors', async () => {
      const errorHandler = jest.fn().mockResolvedValue({
        data: {
          linkProjectComplianceViolationIssue: {
            errors: ['Issue not found'],
          },
        },
      });
      createWrapper({
        data: { isFormVisible: true },
        linkMutationHandler: errorHandler,
      });

      blockEmit('add-issuable-form-submit', { pendingReferences: '#99' });
      await waitForPromises();

      expect(blockProp('isFormVisible')).toBe(true);
      expect(blockProp('hasError')).toBe(true);
      expect(blockProp('itemAddFailureMessage')).toContain('Issue not found');
    });

    it('handles network errors', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      createWrapper({
        data: { isFormVisible: true },
        linkMutationHandler: errorHandler,
      });

      blockEmit('add-issuable-form-submit', { pendingReferences: '#99' });
      await waitForPromises();

      expect(blockProp('isFormVisible')).toBe(true);
      expect(blockProp('hasError')).toBe(true);
    });
  });

  describe('related issues form', () => {
    it('resets form and hides it', async () => {
      createWrapper({
        data: {
          inputValue: 'some input value',
          isFormVisible: true,
          state: { pendingReferences: ['135', '246'], relatedIssues: [] },
        },
      });

      blockEmit('add-issuable-form-cancel');
      await nextTick();

      expect(blockProp('isFormVisible')).toBe(false);
      expect(blockProp('inputValue')).toBe('');
      expect(blockProp('pendingReferences')).toEqual([]);
    });
  });

  describe('pending references', () => {
    it('adds pending references', async () => {
      const pendingReferences = ['135', '246'];
      const untouchedRawReferences = ['357', '468'];
      const touchedReference = 'touchedReference';
      createWrapper({ data: { state: { pendingReferences, relatedIssues: [] } } });

      blockEmit('add-issuable-form-input', { untouchedRawReferences, touchedReference });
      await nextTick();

      expect(blockProp('pendingReferences')).toEqual(
        pendingReferences.concat(untouchedRawReferences),
      );
      expect(blockProp('inputValue')).toBe(touchedReference);
    });

    it('processes pending references', async () => {
      createWrapper();
      blockEmit('add-issuable-form-blur', '135 246');
      await nextTick();

      expect(blockProp('pendingReferences')).toEqual(['135', '246']);
      expect(blockProp('inputValue')).toBe('');
    });

    it('removes pending reference', async () => {
      createWrapper({
        data: { state: { pendingReferences: ['135', '246', '357'], relatedIssues: [] } },
      });
      blockEmit('pending-issuable-remove-request', 1);
      await nextTick();

      expect(blockProp('pendingReferences')).toEqual(['135', '357']);
    });
  });

  describe('remove related issue', () => {
    let unlinkMutationHandler;

    beforeEach(() => {
      unlinkMutationHandler = jest.fn().mockResolvedValue(mockUnlinkMutationSuccess);
      createWrapper({ unlinkMutationHandler });
    });

    it('removes related issue successfully using the correct project path', async () => {
      blockEmit('related-issue-remove-request', 3);
      await waitForPromises();

      expect(unlinkMutationHandler).toHaveBeenCalledWith({
        input: {
          violationId,
          projectPath: 'project/path',
          issueIid: '3',
        },
      });
    });

    it('removes issue from different project using its project path', async () => {
      blockEmit('related-issue-remove-request', 25);
      await waitForPromises();

      expect(unlinkMutationHandler).toHaveBeenCalledWith({
        input: {
          violationId,
          projectPath: 'other/project',
          issueIid: '25',
        },
      });
    });

    it('falls back to component project path when issue project path is not available', async () => {
      // Create an issue without projectPath to test fallback
      const issueWithoutProjectPath = {
        id: 3,
        iid: 3,
        projectPath: null, // No project path available
      };

      createWrapper({
        data: {
          state: {
            relatedIssues: [issueWithoutProjectPath],
            pendingReferences: [],
          },
        },
        unlinkMutationHandler,
      });

      blockEmit('related-issue-remove-request', 3);
      await waitForPromises();

      expect(unlinkMutationHandler).toHaveBeenCalledWith({
        input: {
          violationId,
          projectPath, // Falls back to component's project path
          issueIid: '3',
        },
      });
    });

    it('shows error message if related issue could not be removed', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('Network error'));
      createWrapper({ unlinkMutationHandler: errorHandler });

      blockEmit('related-issue-remove-request', 3);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong while trying to unlink the issue. Please try again later.',
      });
    });

    it('handles mutation errors', async () => {
      const errorHandler = jest.fn().mockResolvedValue({
        data: {
          unlinkProjectComplianceViolationIssue: {
            errors: ['Cannot remove issue'],
          },
        },
      });
      createWrapper({ unlinkMutationHandler: errorHandler });

      blockEmit('related-issue-remove-request', 3);
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong while trying to unlink the issue. Please try again later.',
      });
    });
  });

  describe('project path handling', () => {
    it('uses project path directly without modification', async () => {
      const linkMutationHandler = jest.fn().mockResolvedValue(mockLinkMutationSuccess);
      createWrapper({
        props: { projectPath: '/root/test' },
        data: { isFormVisible: true },
        linkMutationHandler,
      });

      blockEmit('add-issuable-form-submit', { pendingReferences: '#99' });
      await waitForPromises();

      expect(linkMutationHandler).toHaveBeenCalledWith({
        input: {
          violationId,
          projectPath: '/root/test', // uses projectPath directly, no computed property to remove slash
          issueIid: '99',
        },
      });
    });
  });
});
