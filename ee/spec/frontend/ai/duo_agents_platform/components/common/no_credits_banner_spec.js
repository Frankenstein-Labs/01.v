import { shallowMount } from '@vue/test-utils';
import { GlAlert, GlSprintf } from '@gitlab/ui';
import NoCreditsBanner from 'ee/ai/duo_agents_platform/components/common/no_credits_banner.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

jest.mock('~/helpers/help_page_helper');

describe('NoCreditsBanner', () => {
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(NoCreditsBanner);
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSprintf = () => wrapper.findComponent(GlSprintf);

  beforeEach(() => {
    helpPagePath.mockReturnValue('/help/subscriptions/gitlab_credits');
    createWrapper();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders the alert component', () => {
    expect(findAlert().exists()).toBe(true);
    expect(findAlert().props('variant')).toBe('info');
    expect(findAlert().props('dismissible')).toBe(false);
  });

  it('renders the sprintf component with the credits message', () => {
    expect(findSprintf().exists()).toBe(true);
    expect(findSprintf().attributes('message')).toContain(
      'No GitLab Credits remain for this billing period',
    );
    expect(findSprintf().attributes('message')).toContain('Learn more');
  });
});
