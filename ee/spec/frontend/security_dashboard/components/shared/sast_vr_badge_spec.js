import { GlBadge, GlButton, GlIcon, GlLoadingIcon, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SastVrBadge from 'ee/security_dashboard/components/shared/sast_vr_badge.vue';

describe('SastVrBadge', () => {
  let wrapper;

  const baseItem = {
    id: 'gid://gitlab/Vulnerability/42',
    project: { id: 'gid://gitlab/Project/7', fullPath: 'group/project' },
    aiWorkflows: { nodes: [] },
  };

  const itemWithWorkflow = (status = 'RUNNING') => ({
    ...baseItem,
    aiWorkflows: {
      nodes: [
        {
          workflowName: 'RESOLVE_SAST_VULNERABILITY',
          workflow: {
            id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/123',
            status,
            createdAt: '2024-01-15T10:30:00Z',
          },
        },
      ],
    },
  });

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(SastVrBadge, {
      propsData: { item: baseItem, ...props },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLoader = () => wrapper.findComponent(GlLoadingIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findReviewButton = () => wrapper.findComponent(GlButton);
  const findInProgressBadgeText = () => wrapper.findByTestId('sast-vr-in-progress-badge-text');

  describe('available mode (no active workflow)', () => {
    beforeEach(() => createWrapper());

    it('renders a badge with tier variant', () => {
      expect(findBadge().props('variant')).toBe('tier');
    });

    it('renders the tanuki-ai icon', () => {
      expect(findIcon().props('name')).toBe('tanuki-ai');
    });

    it('renders the badge text', () => {
      expect(findBadge().text()).toContain('VR available');
    });

    it('renders a popover with the review button', () => {
      expect(findPopover().exists()).toBe(true);
      expect(findReviewButton().text()).toBe('Resolve vulnerability');
    });

    it('emits "resolve" when the review button is clicked', () => {
      findReviewButton().vm.$emit('click', new Event('click'));
      expect(wrapper.emitted('resolve')).toHaveLength(1);
    });
  });

  describe('in-progress mode (active workflow)', () => {
    describe('with a resolvable session URL', () => {
      beforeEach(() => createWrapper({ item: itemWithWorkflow('RUNNING') }));

      it('renders an info (blue) badge', () => {
        expect(findBadge().props('variant')).toBe('info');
      });

      it('links to the agent session URL', () => {
        expect(findBadge().attributes('href')).toContain('/group/project');
        expect(findBadge().attributes('href')).toContain('123');
      });

      it('opens the session in a new tab', () => {
        expect(findBadge().attributes('target')).toBe('_blank');
      });

      it('renders the tanuki-ai icon, not the loader', () => {
        expect(findIcon().exists()).toBe(true);
        expect(findLoader().exists()).toBe(false);
      });

      it('uses the ready tooltip', () => {
        expect(findBadge().attributes('title')).toContain('Vulnerability resolution is running');
      });

      it('renders the "View session" text', () => {
        expect(findInProgressBadgeText().text()).toBe('View session');
      });
    });

    describe('treats CREATED workflow status as in-progress', () => {
      beforeEach(() => createWrapper({ item: itemWithWorkflow('CREATED') }));

      it('renders the in-progress badge', () => {
        expect(findBadge().props('variant')).toBe('info');
      });
    });

    describe('with pendingTrigger but no workflow yet', () => {
      beforeEach(() => createWrapper({ pendingTrigger: true }));

      it('renders the loader instead of the icon', () => {
        expect(findLoader().exists()).toBe(true);
        expect(findIcon().exists()).toBe(false);
      });

      it('does not render an href', () => {
        expect(findBadge().attributes('href')).toBeUndefined();
      });

      it('uses the loading tooltip', () => {
        expect(findBadge().attributes('title')).toContain('Starting Vulnerability Resolution');
      });

      it('renders the "Starting session" text', () => {
        expect(findInProgressBadgeText().text()).toBe('Starting session');
      });
    });

    describe('with pendingTrigger and an active workflow', () => {
      beforeEach(() => createWrapper({ item: itemWithWorkflow('RUNNING'), pendingTrigger: true }));

      it('still shows the loader while the trigger is pending', () => {
        expect(findLoader().exists()).toBe(true);
        expect(findIcon().exists()).toBe(false);
      });

      it('still links to the agent session', () => {
        expect(findBadge().attributes('href')).toContain('123');
      });
    });
  });
});
