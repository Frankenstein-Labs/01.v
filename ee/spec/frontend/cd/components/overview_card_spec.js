import { GlKeysetPagination, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import OverviewCard from 'ee/cd/components/overview_card.vue';

describe('OverviewCard', () => {
  let wrapper;

  const findCollapsedCard = () => wrapper.findByTestId('overview-card-collapsed');
  const findExpandedCard = () => wrapper.findByTestId('overview-card-expanded');
  const findExpandButton = () => wrapper.findComponentByTestId('expand-button');
  const findCollapseButton = () => wrapper.findComponentByTestId('collapse-button');
  const findContent = () => wrapper.findByTestId('card-content');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findError = () => wrapper.findByTestId('card-error');
  const findEmpty = () => wrapper.findByTestId('card-empty');
  const findTitle = () => wrapper.find('h3');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findPageSizeDropdown = () => wrapper.findComponentByTestId('page-size-dropdown');

  const createComponent = (props = {}, slots = {}) => {
    wrapper = shallowMountExtended(OverviewCard, {
      propsData: {
        title: 'Services',
        expanded: false,
        expandAriaLabel: 'Expand services',
        collapseAriaLabel: 'Collapse services',
        ...props,
      },
      slots: {
        default: '<div data-testid="card-content">body</div>',
        ...slots,
      },
    });
  };

  it('renders the title and slot content', () => {
    createComponent();

    expect(findTitle().text()).toBe('Services');
    expect(findContent().exists()).toBe(true);
  });

  describe('when filters slot is provided', () => {
    beforeEach(() => {
      createComponent({}, { filters: '<div data-testid="filters">filters</div>' });
    });

    it('renders filters slot content', () => {
      expect(wrapper.findByTestId('filters').text()).toBe('filters');
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ loading: true });
    });

    it('renders a skeleton loader instead of the slot content', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findContent().exists()).toBe(false);
      expect(findError().exists()).toBe(false);
    });
  });

  describe('when in error', () => {
    beforeEach(() => {
      createComponent({ error: true, errorMessage: 'Failed to load releases.' });
    });

    it('renders the error message instead of the slot content', () => {
      expect(findError().text()).toBe('Failed to load releases.');
      expect(findContent().exists()).toBe(false);
      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });

  it('prefers the loading state over the error state', () => {
    createComponent({ loading: true, error: true, errorMessage: 'boom' });

    expect(findSkeletonLoader().exists()).toBe(true);
    expect(findError().exists()).toBe(false);
  });

  describe('when empty text is provided', () => {
    beforeEach(() => {
      createComponent({ emptyText: 'No releases available.' });
    });

    it('renders the empty text instead of the slot content', () => {
      expect(findEmpty().text()).toBe('No releases available.');
      expect(findContent().exists()).toBe(false);
    });

    it('still renders the filters slot', () => {
      createComponent(
        { emptyText: 'No releases available.' },
        { filters: '<div data-testid="filters">filters</div>' },
      );

      expect(wrapper.findByTestId('filters').exists()).toBe(true);
      expect(findEmpty().exists()).toBe(true);
    });
  });

  describe('when collapsed', () => {
    beforeEach(() => {
      createComponent({ expanded: false });
    });

    it('grows to fill the row, wrapping at 1 / 2 / 4 per row across breakpoints', () => {
      expect(findCollapsedCard().exists()).toBe(true);
      expect(findExpandedCard().exists()).toBe(false);
      expect(findCollapsedCard().classes()).toEqual(
        expect.arrayContaining(['gl-grow', 'gl-basis-full', '@sm:gl-basis-1/3', '@lg:gl-basis-0']),
      );
    });

    it('renders the expand button and emits toggle on click', () => {
      expect(findExpandButton().exists()).toBe(true);

      findExpandButton().vm.$emit('click');

      expect(wrapper.emitted('toggle')).toHaveLength(1);
    });
  });

  describe('when expanded', () => {
    beforeEach(() => {
      createComponent({ expanded: true });
    });

    it('renders the expanded card spanning a full row', () => {
      expect(findExpandedCard().exists()).toBe(true);
      expect(findCollapsedCard().exists()).toBe(false);
      expect(findExpandedCard().classes()).toContain('gl-basis-full');
    });

    it('renders the collapse button and emits toggle on click', () => {
      expect(findCollapseButton().exists()).toBe(true);

      findCollapseButton().vm.$emit('click');

      expect(wrapper.emitted('toggle')).toHaveLength(1);
    });
  });

  describe('pagination', () => {
    const pageInfo = {
      hasNextPage: true,
      hasPreviousPage: false,
      startCursor: 'start',
      endCursor: 'end',
    };

    describe('when expanded with more pages', () => {
      beforeEach(() => {
        createComponent({ expanded: true, pageInfo });
      });

      it('renders the pagination control', () => {
        expect(findPagination().exists()).toBe(true);
      });

      describe('when the control requests the next page', () => {
        beforeEach(() => {
          findPagination().vm.$emit('next', 'end');
        });

        it('emits next with the end cursor', () => {
          expect(wrapper.emitted('next')).toEqual([['end']]);
        });
      });

      describe('when the control requests the previous page', () => {
        beforeEach(() => {
          findPagination().vm.$emit('prev', 'start');
        });

        it('emits prev with the start cursor', () => {
          expect(wrapper.emitted('prev')).toEqual([['start']]);
        });
      });
    });

    describe('when expanded with no further pages', () => {
      beforeEach(() => {
        createComponent({
          expanded: true,
          pageInfo: { hasNextPage: false, hasPreviousPage: false },
        });
      });

      it('does not render the pagination control', () => {
        expect(findPagination().exists()).toBe(false);
      });
    });

    describe('when collapsed with more pages', () => {
      beforeEach(() => {
        createComponent({ expanded: false, pageInfo });
      });

      it('does not render the pagination control', () => {
        expect(findPagination().exists()).toBe(false);
      });
    });
  });

  describe('page size', () => {
    describe('when expanded with a page size', () => {
      beforeEach(() => {
        createComponent({ expanded: true, pageSize: 5 });
      });

      it('renders the dropdown with the current size selected', () => {
        expect(findPageSizeDropdown().exists()).toBe(true);
        expect(findPageSizeDropdown().props('selected')).toBe(5);
        expect(findPageSizeDropdown().props('toggleText')).toBe('Show 5 items');
      });

      it('offers 5, 10 and 20 items per page', () => {
        expect(findPageSizeDropdown().props('items')).toEqual([
          { value: 5, text: 'Show 5 items' },
          { value: 10, text: 'Show 10 items' },
          { value: 20, text: 'Show 20 items' },
        ]);
      });

      it('emits page-size-change with the selected size', () => {
        findPageSizeDropdown().vm.$emit('select', 10);

        expect(wrapper.emitted('page-size-change')).toEqual([[10]]);
      });
    });

    describe('when expanded without a page size', () => {
      beforeEach(() => {
        createComponent({ expanded: true });
      });

      it('does not render the dropdown', () => {
        expect(findPageSizeDropdown().exists()).toBe(false);
      });
    });

    describe('when collapsed with a page size', () => {
      beforeEach(() => {
        createComponent({ expanded: false, pageSize: 5 });
      });

      it('does not render the dropdown', () => {
        expect(findPageSizeDropdown().exists()).toBe(false);
      });
    });
  });
});
