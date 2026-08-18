import { GlPopover, GlIcon, GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import MergeRequestBadge from 'ee/security_dashboard/components/shared/merge_request_badge.vue';

const TEST_MERGE_REQUEST_DATA = {
  webUrl: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/48820',
  state: 'merged',
  iid: 48820,
};

describe('Merge Request Badge component', () => {
  let wrapper;
  const createWrapper = (mergeRequestProps) => {
    return mount(MergeRequestBadge, {
      propsData: {
        mergeRequest: { ...TEST_MERGE_REQUEST_DATA, ...mergeRequestProps },
      },
      stubs: {
        GlPopover: true,
      },
    });
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);

  it('popover should have wrapping div as target', () => {
    expect(findPopover().props('target')()).toBe(wrapper.element);
  });

  it('popover should contain Icon with passed status', () => {
    expect(findPopover().findComponent(GlIcon).props('name')).toBe('merge');
  });

  it('popover should contain Link with passed href', () => {
    expect(findLink().attributes('href')).toBe(TEST_MERGE_REQUEST_DATA.webUrl);
  });
});
