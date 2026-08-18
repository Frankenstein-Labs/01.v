import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoWorkflowAction from 'ee_component/ai/shared/widgets/duo_workflow_action.vue';
import ResolveWithDuoButton from 'ee/merge_conflicts/components/resolve_with_duo_button.vue';

describe('ResolveWithDuoButton', () => {
  let wrapper;

  const defaultProps = {
    mr: {
      targetProjectFullPath: 'gitlab-org/gitlab',
      sourceBranch: 'feature-branch',
      iid: 123,
      canResolveWithAi: true,
    },
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(ResolveWithDuoButton, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  describe('when the MR allows resolving with AI', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders DuoWorkflowAction', () => {
      expect(findDuoWorkflowAction().exists()).toBe(true);
    });

    it('passes correct props to DuoWorkflowAction', () => {
      const action = findDuoWorkflowAction();

      expect(action.props('projectPath')).toBe('gitlab-org/gitlab');
      expect(action.props('sourceBranch')).toBe('feature-branch');
      expect(action.props('mergeRequestId')).toBe(123);
      expect(action.props('size')).toBe('medium');
      expect(action.props('variant')).toBe('default');
      expect(action.props('category')).toBe('primary');
      expect(action.props('source')).toBe('merge_request_code_conflict');
    });

    it('forwards custom category and variant props', () => {
      createComponent({ props: { category: 'tertiary', variant: 'confirm' } });

      expect(findDuoWorkflowAction().props('category')).toBe('tertiary');
      expect(findDuoWorkflowAction().props('variant')).toBe('confirm');
    });
  });

  describe('when the MR does not allow resolving with AI', () => {
    it('does not render DuoWorkflowAction', () => {
      createComponent({
        props: { mr: { ...defaultProps.mr, canResolveWithAi: false } },
      });

      expect(findDuoWorkflowAction().exists()).toBe(false);
    });
  });

  describe('goal', () => {
    let goal;

    beforeEach(() => {
      createComponent();
      goal = findDuoWorkflowAction().props('goal');
    });

    it('references the merge request project path and iid', () => {
      expect(goal).toContain('gitlab-org/gitlab');
      expect(goal).toContain('123');
    });

    it('frames the task as reconciling existing changes, not introducing new behavior', () => {
      expect(goal).toContain('reconcile');
      expect(goal).toContain('not to introduce new behavior');
    });

    it('directs the agent to the MR intent when branches disagree', () => {
      expect(goal).toMatch(/MR's intent.*title, description, and commits/);
    });

    it('allows preserving cosmetic changes alongside semantic ones', () => {
      expect(goal).toContain('cosmetic');
    });

    it('requires a ⚠️ Needs review flag for ambiguous resolutions', () => {
      expect(goal).toContain('⚠️ Needs review:');
    });

    it('restricts the agent to files with unresolved conflict markers', () => {
      expect(goal).toContain('git diff --name-only --diff-filter=U');
    });

    it('forbids broad staging commands', () => {
      expect(goal).toContain("Do NOT use 'git add .' or 'git add -A'");
    });

    it('directs the agent to flag and exit if the commit would touch non-conflicted files', () => {
      expect(goal).toMatch(
        /⚠️ Needs review:" that lists the unexpected files, then exit without pushing/,
      );
    });

    it('groups file-scope rules under a <scope> tag', () => {
      expect(goal).toMatch(/<scope>[\s\S]*git diff --name-only --diff-filter=U[\s\S]*<\/scope>/);
    });

    it('groups reconciliation guidance under a <role> tag', () => {
      expect(goal).toMatch(/<role>[\s\S]*reconcile[\s\S]*<\/role>/);
    });
  });
});
