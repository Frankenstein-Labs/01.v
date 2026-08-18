import { GlButton, GlEmptyState, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import EmptyAdminAppsSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-admin-apps-md.svg';
import EmptyState from 'ee/integrations/edit/components/google_artifact_management/empty_state.vue';
import InviteMembersTrigger from '~/invite_members/components/invite_members_trigger.vue';

describe('EmptyState', () => {
  let wrapper;

  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findInviteMembersTrigger = () => wrapper.findComponent(InviteMembersTrigger);
  const findButton = () => wrapper.findComponent(GlButton);
  const findTitle = () => wrapper.find('h3');
  const findDescription = () => wrapper.find('p');

  const createComponent = () => {
    wrapper = shallowMount(EmptyState, {
      propsData: {
        path: '/path',
      },
      stubs: {
        GlEmptyState,
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders gl-empty-state', () => {
    expect(findGlEmptyState().props('svgPath')).toBe(EmptyAdminAppsSvg);
  });

  it('renders title', () => {
    expect(findTitle().text()).toBe('Use Google Cloud securely');
  });

  it('renders description', () => {
    expect(findDescription().text()).toBe(
      'First, secure your usage with the Google Cloud IAM integration. Simplify access without the need to manage accounts or keys.',
    );
  });

  it('renders gl-button in actions slot', () => {
    expect(findButton().attributes('href')).toBe('/path');
    expect(findButton().props('variant')).toBe('confirm');
    expect(findButton().text()).toBe('Set up Google Cloud IAM');
  });

  it('renders invite-members-trigger in actions slot', () => {
    expect(findInviteMembersTrigger().props()).toMatchObject({
      displayText: 'Invite member to set up',
      triggerSource: 'google_artifact_management_setup',
    });
  });
});
