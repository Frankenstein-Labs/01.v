import { GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import ArchivalBadge from 'ee/vulnerabilities/components/archival_badge.vue';

const TOOLTIP_TITLE = 'Vulnerability will be archived on 2026-03-01';

describe('Archival badge component', () => {
  let wrapper;

  const findBadge = () => wrapper.findComponent(GlBadge);

  const createWrapper = () => {
    return shallowMount(ArchivalBadge, {
      propsData: {
        expectedDate: '2026-03-01',
      },
    });
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  it('should display the correct icon', () => {
    expect(findBadge().props('icon')).toBe('archive');
  });

  it('should have the correct title', () => {
    expect(findBadge().attributes('title')).toBe(TOOLTIP_TITLE);
  });

  it('should have the correct aria label', () => {
    expect(findBadge().attributes('aria-label')).toBe(TOOLTIP_TITLE);
  });
});
