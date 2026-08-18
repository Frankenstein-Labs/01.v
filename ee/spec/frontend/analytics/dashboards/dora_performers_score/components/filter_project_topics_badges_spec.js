import { GlBadge, GlButton, GlPopover } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FilterProjectTopicsBadges from 'ee/analytics/dashboards/dora_performers_score/components/filter_project_topics_badges.vue';

describe('Filter project topics badges', () => {
  let wrapper;

  const mockTopics = ['one', 'two', 'three'];
  const topicsExploreProjectsPath = '/explore/projects/topics';

  const createWrapper = (props = {}) => {
    wrapper = mountExtended(FilterProjectTopicsBadges, {
      provide: {
        topicsExploreProjectsPath,
      },
      propsData: {
        topics: mockTopics,
        ...props,
      },
    });
  };

  const expectBadge = (badge, text) => {
    expect(badge.text()).toEqual(text);
    expect(badge.attributes('href')).toEqual(`${topicsExploreProjectsPath}/${text}`);
  };

  const findPrimaryBadges = () => wrapper.findByTestId('primary-badges').findAllComponents(GlBadge);
  const findSeeMoreButton = () => wrapper.findComponent(GlButton);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findPopoverBadges = () => findPopover().findAllComponents(GlBadge);

  describe('badges', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders a maximum of 2 badges on the page', () => {
      expect(findPrimaryBadges()).toHaveLength(2);
      [0, 1].forEach((index) => expectBadge(findPrimaryBadges().at(index), mockTopics[index]));
    });

    it('renders all badges in the popover', () => {
      expect(findPopoverBadges()).toHaveLength(3);
      [0, 1, 2].forEach((index) => expectBadge(findPopoverBadges().at(index), mockTopics[index]));
    });
  });

  it('encodes the topic name in the badge href', () => {
    createWrapper({ topics: ['space test'] });

    const href = findPrimaryBadges().at(0).attributes('href');
    expect(href).toEqual(`${topicsExploreProjectsPath}/space%20test`);
  });

  describe('see more button', () => {
    it('does not render for < 3 topics', () => {
      createWrapper({ topics: [mockTopics[0]] });

      expect(findSeeMoreButton().exists()).toBe(false);
      expect(findPopover().exists()).toBe(false);
    });

    it('renders for >= 3 topics', () => {
      createWrapper();

      expect(findSeeMoreButton().exists()).toBe(true);
      expect(findSeeMoreButton().text()).toBe('+ 1 more');
      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props().target()).toBe(findSeeMoreButton().vm.$el);
    });
  });
});
