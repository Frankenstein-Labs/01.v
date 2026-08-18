import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ActionItem from 'ee/pages/projects/get_started/components/action_item.vue';
import eventHub from '~/invite_members/event_hub';
import { LEARN_GITLAB } from 'ee/invite_members/constants';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';

describe('ActionItem', () => {
  let wrapper;
  let trackingSpy;

  const createComponent = (actionProps = {}) => {
    wrapper = shallowMountExtended(ActionItem, {
      propsData: {
        action: {
          title: 'Test Action',
          url: 'https://example.com',
          trackLabel: 'test_action',
          ...actionProps,
        },
      },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
    });
  };

  beforeEach(() => {
    trackingSpy = mockTracking('_category_', undefined, jest.spyOn);
  });

  afterEach(() => {
    unmockTracking();
  });

  const disabledMessage = () => wrapper.findByTestId('action-disabled');
  const actionLink = () => wrapper.findComponent(GlLink);
  const disabledIcon = () => wrapper.findComponentByTestId('disabled-icon');

  describe('rendering', () => {
    it('renders the action title', () => {
      createComponent();

      expect(wrapper.text()).toContain('Test Action');
    });

    it('renders a link when action is not disabled', () => {
      createComponent({ enabled: true });

      expect(actionLink().exists()).toBe(true);
      expect(actionLink().attributes('href')).toBe('https://example.com');
    });

    it('renders a disabled span with tooltip when action is disabled', () => {
      createComponent({ enabled: false });

      expect(disabledMessage().exists()).toBe(true);
      expect(actionLink().exists()).toBe(false);
      expect(disabledIcon().props('name')).toBe('lock');
    });
  });

  describe('disabled state', () => {
    it('renders as disabled when action is disabled', () => {
      createComponent({ enabled: false });

      expect(disabledMessage().attributes('aria-disabled')).toBe('true');
      expect(actionLink().exists()).toBe(false);
    });

    it('renders as enabled when action is enabled', () => {
      createComponent({ enabled: true });

      expect(disabledMessage().exists()).toBe(false);
      expect(actionLink().exists()).toBe(true);
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      jest.spyOn(eventHub, '$emit');
    });

    it('tracks click events when link is clicked', async () => {
      createComponent();
      await actionLink().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith('projects:learn_gitlab:show', 'click_link', {
        category: 'projects:learn_gitlab:show',
        label: 'test_action',
      });
    });

    it('emits open-modal event when action urlType is "invite"', async () => {
      createComponent({ urlType: 'invite' });
      await actionLink().vm.$emit('click');

      expect(eventHub.$emit).toHaveBeenCalledWith('open-modal', { source: LEARN_GITLAB });
    });

    it('does not emit open-modal event when action urlType is not "invite"', async () => {
      createComponent({ urlType: 'other' });
      await actionLink().vm.$emit('click');

      expect(eventHub.$emit).not.toHaveBeenCalledWith('open-modal', expect.anything());
    });
  });

  describe('accessibility', () => {
    it('has appropriate aria attributes for disabled actions', () => {
      createComponent({ enabled: false });

      expect(disabledMessage().exists()).toBe(true);
      expect(disabledMessage().attributes('aria-disabled')).toBe('true');
      expect(disabledMessage().attributes('aria-label')).toContain(
        "You don't have sufficient access",
      );
    });
  });
});
