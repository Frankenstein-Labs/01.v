import { GlButton, GlCard, GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import StatisticsCardRow from 'ee/security_configuration/components/scan_profiles/statistics_card_row.vue';

describe('StatisticsCardRow', () => {
  let wrapper;

  const cards = [
    { title: 'Apples', value: 3, description: 'Three apples' },
    { title: 'Oranges', value: 5, description: 'Five oranges' },
  ];

  const createComponent = (props = {}) => {
    wrapper = mountExtended(StatisticsCardRow, {
      propsData: { cards, ...props },
    });
  };

  const findCards = () => wrapper.findAllComponents(GlCard);
  const findSingleStats = () => wrapper.findAllComponents(GlSingleStat);
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findButtons = () => wrapper.findAllComponents(GlButton);

  describe('when loading', () => {
    beforeEach(() => createComponent({ loading: true }));

    it('renders a skeleton-loading card for each card', () => {
      expect(findCards()).toHaveLength(cards.length);
      findCards().wrappers.forEach((card) => {
        expect(card.findComponent(GlSkeletonLoader).exists()).toBe(true);
      });
    });

    it('does not render any stats', () => {
      expect(findSingleStats()).toHaveLength(0);
    });
  });

  describe('with data', () => {
    beforeEach(() => createComponent());

    it('does not render skeleton loaders', () => {
      expect(findSkeletonLoaders()).toHaveLength(0);
    });

    it('renders a card per item with its title and description', () => {
      expect(findCards()).toHaveLength(2);
      expect(findCards().at(0).text()).toContain('Apples');
      expect(findCards().at(0).text()).toContain('Three apples');
      expect(findCards().at(1).text()).toContain('Oranges');
      expect(findCards().at(1).text()).toContain('Five oranges');
    });

    it('renders each value', () => {
      expect(findSingleStats().at(0).props('value')).toBe(3);
      expect(findSingleStats().at(1).props('value')).toBe(5);
    });
  });

  describe('on error', () => {
    beforeEach(() => createComponent({ error: true }));

    it('renders a dash instead of each value', () => {
      findSingleStats().wrappers.forEach((stat) => {
        expect(stat.props('value')).toBe('—');
      });
    });

    it('still renders the titles and descriptions', () => {
      expect(findCards().at(1).text()).toContain('Oranges');
      expect(findCards().at(1).text()).toContain('Five oranges');
    });
  });

  describe('card links', () => {
    describe('when a card has linkText and a route', () => {
      beforeEach(() =>
        createComponent({
          cards: [
            {
              title: 'Scanners enabled',
              value: 1,
              description: 'One scanner enabled',
              linkText: 'Enable scanners',
              to: { name: 'enable_scanners' },
            },
          ],
        }),
      );

      it('renders a router link with the card linkText pointing at the route', () => {
        expect(findLinks()).toHaveLength(1);
        expect(findLinks().at(0).text()).toBe('Enable scanners');
        expect(findLinks().at(0).props('to')).toEqual({ name: 'enable_scanners' });
      });

      it('does not render a "View projects" link for that card', () => {
        expect(wrapper.text()).not.toContain('View projects');
      });

      it('does not emit view-projects when the link is clicked', async () => {
        await findLinks().at(0).vm.$emit('click');

        expect(wrapper.emitted('view-projects')).toBeUndefined();
      });
    });

    describe('when a card has no linkText or route', () => {
      const card = { title: 'Needs attention', value: 2, description: 'Two projects' };

      beforeEach(() => createComponent({ cards: [card] }));

      it('renders a "View projects" button', () => {
        expect(findButtons()).toHaveLength(1);
        expect(findButtons().at(0).text()).toBe('View projects');
      });

      it('emits view-projects with the card when the button is clicked', async () => {
        await findButtons().at(0).vm.$emit('click');

        expect(wrapper.emitted('view-projects')).toEqual([[card]]);
      });
    });
  });
});
