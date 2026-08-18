import { shallowMount } from '@vue/test-utils';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import ResolveWithDuoDropdownItem from 'ee/notes/components/resolve_with_duo_dropdown_item.vue';
import { RESOLVE_DISCUSSION_AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';
import { DUO_WORKFLOW_DEVELOPER_DEFINITION } from 'ee/ai/constants';

describe('ResolveWithDuoDropdownItem', () => {
  let wrapper;

  const projectPath = 'group/project';
  const sourceBranch = 'feature-branch';
  const iid = 42;

  const defaultDiscussion = {
    id: 'abc123',
    diff_file: { new_path: 'app/models/user.rb' },
    position: { new_line: 10, old_line: null },
    notes: [{ body: 'Please fix this typo.' }],
  };

  const createComponent = ({ props = {} } = {}) => {
    document.body.dataset.projectFullPath = projectPath;

    wrapper = shallowMount(ResolveWithDuoDropdownItem, {
      propsData: {
        discussion: defaultDiscussion,
        sourceBranch,
        iid,
        ...props,
      },
    });
  };

  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  afterEach(() => {
    delete document.body.dataset.projectFullPath;
  });

  it('renders DuoWorkflowAction with the correct props', () => {
    createComponent();

    expect(findDuoWorkflowAction().exists()).toBe(true);
    expect(findDuoWorkflowAction().props()).toMatchObject({
      renderAs: 'dropdown-item',
      projectPath,
      sourceBranch,
      workflowDefinition: DUO_WORKFLOW_DEVELOPER_DEFINITION,
      agentPrivileges: RESOLVE_DISCUSSION_AGENT_PRIVILEGES,
    });
  });

  it('passes the correct source prop', () => {
    createComponent();

    expect(findDuoWorkflowAction().props('source')).toBe('merge_request_resolve_discussion');
  });

  it('builds a goal referencing the discussion, MR, branch, and resolution intent', () => {
    createComponent();
    const goal = findDuoWorkflowAction().props('goal');

    expect(goal).toContain(defaultDiscussion.id);
    expect(goal).toContain(`${projectPath}!${iid}`);
    expect(goal).toContain(sourceBranch);
  });

  describe('event forwarding', () => {
    it('forwards the triggering event', () => {
      createComponent();
      findDuoWorkflowAction().vm.$emit('triggering');
      expect(wrapper.emitted('triggering')).toHaveLength(1);
    });

    it('forwards the triggered event', () => {
      createComponent();
      findDuoWorkflowAction().vm.$emit('triggered');
      expect(wrapper.emitted('triggered')).toHaveLength(1);
    });
  });
});
