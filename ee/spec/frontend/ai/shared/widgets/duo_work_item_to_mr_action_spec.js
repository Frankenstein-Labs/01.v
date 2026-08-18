import { shallowMount } from '@vue/test-utils';
import DuoWorkItemToMrAction from 'ee/ai/shared/widgets/duo_work_item_to_mr_action.vue';
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import { DUO_CHAT_AGENT_GITLAB_DUO } from 'ee/ai/constants';

describe('DuoWorkItemToMrAction component', () => {
  let wrapper;

  const defaultProps = {
    projectPath: 'group/project',
    workItemIid: '42',
    workItemType: 'Issue',
    workItemWebUrl: 'http://gdk.test/group/project/-/issues/42',
  };

  const createComponent = ({ props = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMount(DuoWorkItemToMrAction, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        glFeatures: {
          agenticFoundationalFlowTool: false,
          ...glFeatures,
        },
      },
    });
  };

  const findDuoChatQuickAction = () => wrapper.findComponent(DuoChatQuickAction);
  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  beforeEach(() => {
    window.gon = { current_username: 'testuser' };
  });

  describe('when runDuoDeveloperInChat is true', () => {
    describe('and agenticFoundationalFlowTool feature flag is enabled', () => {
      beforeEach(() => {
        createComponent({
          props: { runDuoDeveloperInChat: true },
          glFeatures: { agenticFoundationalFlowTool: true },
        });
      });

      it('renders duo-chat-quick-action', () => {
        expect(findDuoChatQuickAction().exists()).toBe(true);
      });

      describe('when DuoChatQuickAction is rendered', () => {
        it('does not render duo-workflow-action', () => {
          expect(findDuoWorkflowAction().exists()).toBe(false);
        });

        it('passes workItemIid as resourceId', () => {
          expect(findDuoChatQuickAction().props('resourceId')).toBe('42');
        });

        it('passes hardcoded size via buttonOptions', () => {
          expect(findDuoChatQuickAction().props('buttonOptions')).toMatchObject({ size: 'medium' });
        });

        it('computes the goal from props and current username', () => {
          const { agenticPrompt } = findDuoChatQuickAction().props('command');

          expect(agenticPrompt).toContain(
            '@testuser assigned you to solve the following issue: http://gdk.test/group/project/-/issues/42',
          );
          expect(agenticPrompt).toContain('@mention @testuser in a comment on the issue');
        });

        it('specifies the default GitLab Duo agent', () => {
          const { agent } = findDuoChatQuickAction().props('command');

          expect(agent).toEqual({ name: DUO_CHAT_AGENT_GITLAB_DUO });
        });

        it('passes hardcoded button text', () => {
          expect(findDuoChatQuickAction().props('buttonText')).toBe('Implement');
        });
        describe('when workItemType is provided', () => {
          beforeEach(() => {
            createComponent({
              props: { workItemType: 'Epic', runDuoDeveloperInChat: true },
              glFeatures: { agenticFoundationalFlowTool: true },
            });
          });

          it('uses the lowercased workItemType in the goal', () => {
            expect(findDuoChatQuickAction().props('command').agenticPrompt).toContain(
              '@testuser assigned you to solve the following epic:',
            );
          });
        });

        describe('when current_username is not set', () => {
          beforeEach(() => {
            window.gon = {};
            createComponent({
              props: { runDuoDeveloperInChat: true },
              glFeatures: { agenticFoundationalFlowTool: true },
            });
          });

          it('uses an empty username in the goal', () => {
            const { agenticPrompt } = findDuoChatQuickAction().props('command');

            expect(agenticPrompt).toContain('@ assigned you to solve the following issue:');
          });
        });

        describe('when additionalGoalContext is provided', () => {
          it('prepends the context before the base goal', () => {
            createComponent({
              props: {
                additionalGoalContext: 'Read the workplan first.',
                runDuoDeveloperInChat: true,
              },
              glFeatures: { agenticFoundationalFlowTool: true },
            });

            const { agenticPrompt } = findDuoChatQuickAction().props('command');

            expect(agenticPrompt).toContain('Read the workplan first.\n\n@testuser assigned you');
          });
        });

        describe('when additionalGoalContext is not provided', () => {
          beforeEach(() => {
            createComponent({
              props: { runDuoDeveloperInChat: true },
              glFeatures: { agenticFoundationalFlowTool: true },
            });
          });

          it('starts with the base goal directly', () => {
            const { agenticPrompt } = findDuoChatQuickAction().props('command');

            expect(agenticPrompt).toContain(
              'Start the duo developer flow with the following goal: @testuser assigned you',
            );
            expect(agenticPrompt).not.toContain('Read the workplan first.');
          });
        });
      });
    });
  });

  describe('when agenticFoundationalFlowTool feature flag is disabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders DuoWorkflowAction', () => {
      expect(findDuoWorkflowAction().exists()).toBe(true);
    });

    it('does not render DuoChatQuickAction', () => {
      expect(findDuoChatQuickAction().exists()).toBe(false);
    });
  });

  describe('when runDuoDeveloperInChat is false', () => {
    beforeEach(() => {
      createComponent({ props: { runDuoDeveloperInChat: false } });
    });

    it('renders DuoWorkflowAction', () => {
      expect(findDuoWorkflowAction().exists()).toBe(true);
    });

    it('does not render DuoChatQuickAction', () => {
      expect(findDuoChatQuickAction().exists()).toBe(false);
    });
  });

  describe('when DuoWorkflowAction is rendered', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes correct props to DuoWorkflowAction', () => {
      expect(findDuoWorkflowAction().props()).toMatchObject({
        projectPath: 'group/project',
        hoverMessage: 'Implement work item with GitLab Duo',
        goal: expect.stringContaining(
          '@testuser assigned you to solve the following issue: http://gdk.test/group/project/-/issues/42',
        ),
        workflowDefinition: 'developer/v1',
        agentPrivileges: [1, 2, 3, 4, 5],
        size: 'medium',
        variant: 'default',
        category: 'primary',
        workItemIid: '42',
      });
    });

    it('forwards custom generateMrButtonOptions to DuoWorkflowAction', () => {
      createComponent({
        props: {
          generateMrButtonOptions: { size: 'small', variant: 'confirm', category: 'secondary' },
        },
        glFeatures: { agenticFoundationalFlowTool: false },
      });

      expect(findDuoWorkflowAction().props()).toMatchObject({
        size: 'small',
        variant: 'confirm',
        category: 'secondary',
      });
    });

    it('renders slot text', () => {
      expect(findDuoWorkflowAction().text()).toBe('Implement work item');
    });

    it('passes the correct source prop', () => {
      expect(findDuoWorkflowAction().props('source')).toBe('work_item_to_merge_request');
    });

    describe('when additionalGoalContext is provided', () => {
      it('prepends the context before the base goal', () => {
        createComponent({
          props: { additionalGoalContext: 'Read the workplan first.' },
          glFeatures: { agenticFoundationalFlowTool: false },
        });

        const goal = findDuoWorkflowAction().props('goal');

        expect(goal).toMatch(/^Read the workplan first\.\n\n@testuser assigned you/);
      });
    });
  });
});
