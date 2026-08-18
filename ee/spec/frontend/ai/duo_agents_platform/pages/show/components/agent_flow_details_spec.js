import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { GlCollapse } from '@gitlab/ui';
import AgentFlowDetails from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_details.vue';
import AgentFlowHeader from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_header.vue';
import AgentFlowInfo from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_info.vue';
import AgentActivityLogs from 'ee/ai/duo_agents_platform/pages/show/components/agent_activity_logs.vue';
import AgentFlowErrorAlert from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_error_alert.vue';
import NoCreditsBanner from 'ee/ai/duo_agents_platform/components/common/no_credits_banner.vue';
import UsageBillingForbiddenBanner from 'ee/ai/duo_agents_platform/components/common/usage_billing_forbidden_banner.vue';

import { mockDuoMessages, mockUser1, mockWorkItem, mockMergeRequest } from '../../../../mocks';

describe('AgentFlowDetails', () => {
  let wrapper;

  const defaultProps = {
    isLoading: false,
    status: 'RUNNING',
    humanStatus: 'Running',
    agentFlowDefinition: 'software_development',
    title: '',
    duoMessages: mockDuoMessages,
    allExecutorUrls: ['https://gitlab.com/gitlab-org/gitlab/-/jobs/123'],
    createdAt: '2023-01-01T00:54:00Z',
    updatedAt: '2024-01-02T00:34:00Z',
    user: mockUser1,
    workflowId: '123',
    canUpdateWorkflow: true,
    canResumeWorkflow: true,
    workItem: mockWorkItem,
    mergeRequest: mockMergeRequest,
    project: {
      id: 'gid://gitlab/Project/1',
      name: 'Test Project',
      fullPath: 'gitlab-org/test-project',
      namespace: {
        id: 'gid://gitlab/Group/1',
        name: 'gitlab-org',
      },
    },
  };

  const createComponent = ({ props = {}, provide = {}, apolloData = {} } = {}) => {
    const defaultApolloData = {
      isMaximized: false,
      infoToggleStates: {},
    };

    wrapper = shallowMount(AgentFlowDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        isSidePanelView: false,
        creditsAvailable: true,
        ...provide,
      },
      data() {
        return {
          ...defaultApolloData,
          ...apolloData,
        };
      },
    });
  };

  const findAgentFlowHeader = () => wrapper.findComponent(AgentFlowHeader);
  const findAgentFlowInfo = () => wrapper.findComponent(AgentFlowInfo);
  const findAgentActivityLogs = () => wrapper.findComponent(AgentActivityLogs);
  const findErrorAlert = () => wrapper.findComponent(AgentFlowErrorAlert);
  const findNoCreditsBanner = () => wrapper.findComponent(NoCreditsBanner);
  const findUsageBillingForbiddenBanner = () => wrapper.findComponent(UsageBillingForbiddenBanner);
  const findCollapse = () => wrapper.findComponent(GlCollapse);

  describe('when not in side panel view', () => {
    beforeEach(() => {
      createComponent({ provide: { isSidePanelView: false } });
    });

    it('renders header with information icon', () => {
      expect(findAgentFlowHeader().exists()).toBe(true);
    });

    it('renders info and activity logs components', () => {
      expect(findAgentFlowInfo().exists()).toBe(true);
      expect(findAgentActivityLogs().exists()).toBe(true);
    });

    it('does not render collapse component', () => {
      expect(findCollapse().exists()).toBe(false);
    });
  });

  describe('when in side panel view', () => {
    beforeEach(() => {
      createComponent({ provide: { isSidePanelView: true } });
    });

    it('does not render the agent flow header', () => {
      expect(findAgentFlowHeader().exists()).toBe(false);
    });

    it('renders info and activity logs components', () => {
      expect(findAgentFlowInfo().exists()).toBe(true);
      expect(findAgentActivityLogs().exists()).toBe(true);
    });

    it('renders collapse component for info section', () => {
      expect(findCollapse().exists()).toBe(true);
    });
  });

  describe('props passing', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes duoMessages to AgentActivityLogs', () => {
      expect(findAgentActivityLogs().props('duoMessages')).toEqual(mockDuoMessages);
    });

    it('passes correct props to AgentFlowInfo', () => {
      const {
        duoMessages,
        workflowId,
        agentFlowCheckpoint,
        creditsAvailable,
        canResumeWorkflow,
        title,
        ...agentFlowInfoProps
      } = defaultProps;

      expect(findAgentFlowInfo().props()).toEqual(
        expect.objectContaining({
          ...agentFlowInfoProps,
          isLoading: false,
          canUpdateWorkflow: true,
        }),
      );
    });

    it('passes correct props to AgentFlowHeader when not in side panel', () => {
      const headerProps = findAgentFlowHeader().props();
      expect(headerProps.isLoading).toBe(false);
      expect(headerProps.title).toBe(defaultProps.title);
      expect(headerProps.agentFlowDefinition).toBe(defaultProps.agentFlowDefinition);
    });
  });

  describe('collapse behavior', () => {
    it('renders collapse component only in side panel view', () => {
      createComponent({ provide: { isSidePanelView: true } });
      expect(findCollapse().exists()).toBe(true);
    });

    it('emits cancel-session event from AgentFlowInfo', () => {
      createComponent();
      findAgentFlowInfo().vm.$emit('cancel-session');
      expect(wrapper.emitted('cancel-session')).toEqual([[]]);
    });
  });

  describe('session information toggle', () => {
    it('shows collapse when session info is visible', () => {
      const toggleStates = { 'ai_panel:123': true };
      createComponent({
        provide: { isSidePanelView: true },
        apolloData: { infoToggleStates: toggleStates },
      });

      expect(findCollapse().props('visible')).toBe(true);
    });

    it('hides collapse when session info is not visible', () => {
      createComponent({ provide: { isSidePanelView: true } });

      expect(findCollapse().props('visible')).toBe(false);
    });
  });

  describe('layout classes based on maximize state', () => {
    const findContainer = () => wrapper.find('[data-testid="agent-flow-details-wrapper"]');

    it.each`
      isSidePanelView | isMaximized | expectedClasses                              | notExpectedClasses
      ${true}         | ${false}    | ${['gl-flex-col']}                           | ${['lg:gl-flex-row-reverse']}
      ${true}         | ${true}     | ${['gl-flex-col', 'lg:gl-flex-row-reverse']} | ${[]}
      ${false}        | ${false}    | ${['gl-flex-col-reverse', 'xl:gl-flex-row']} | ${[]}
    `(
      'applies correct layout when isSidePanelView=$isSidePanelView and isMaximized=$isMaximized',
      async ({ isSidePanelView, isMaximized, expectedClasses, notExpectedClasses }) => {
        createComponent({
          provide: { isSidePanelView },
          apolloData: { isMaximized },
        });

        await nextTick();

        const classes = findContainer().classes();
        expectedClasses.forEach((cls) => expect(classes).toContain(cls));
        notExpectedClasses.forEach((cls) => expect(classes).not.toContain(cls));
      },
    );
  });

  describe('error alert', () => {
    it('does not render when status is not FAILED', () => {
      createComponent({ props: { status: 'RUNNING' } });

      expect(findErrorAlert().exists()).toBe(false);
    });

    it('renders when status is FAILED', () => {
      createComponent({ props: { status: 'FAILED' } });

      expect(findErrorAlert().exists()).toBe(true);
    });

    it('hides after being dismissed', async () => {
      createComponent({ props: { status: 'FAILED' } });

      findErrorAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findErrorAlert().exists()).toBe(false);
    });

    it('does not render when billing is forbidden, showing the billing forbidden banner instead', () => {
      createComponent({
        props: { status: 'FAILED' },
        provide: { creditsAvailable: false, billingForbidden: true },
      });

      expect(findErrorAlert().exists()).toBe(false);
      expect(findUsageBillingForbiddenBanner().exists()).toBe(true);
    });
  });

  describe('no credits banner', () => {
    it.each`
      creditsAvailable | description
      ${true}          | ${'does not render the no credits banner'}
      ${false}         | ${'renders the no credits banner'}
    `('$description when creditsAvailable is $creditsAvailable', ({ creditsAvailable }) => {
      createComponent({ provide: { creditsAvailable } });

      expect(findNoCreditsBanner().exists()).toBe(!creditsAvailable);
    });

    it('does not render the no credits banner when billing is forbidden', () => {
      createComponent({ provide: { creditsAvailable: false, billingForbidden: true } });

      expect(findNoCreditsBanner().exists()).toBe(false);
    });
  });

  describe('usage billing forbidden banner', () => {
    it('does not render when credits are available', () => {
      createComponent({ provide: { creditsAvailable: true, billingForbidden: true } });

      expect(findUsageBillingForbiddenBanner().exists()).toBe(false);
    });

    it('does not render when billing is not forbidden', () => {
      createComponent({ provide: { creditsAvailable: false, billingForbidden: false } });

      expect(findUsageBillingForbiddenBanner().exists()).toBe(false);
    });

    it('renders when credits are unavailable and billing is forbidden', () => {
      createComponent({ provide: { creditsAvailable: false, billingForbidden: true } });

      expect(findUsageBillingForbiddenBanner().exists()).toBe(true);
    });
  });
});
