import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';

const MOCK_BRANCH_EXCEPTIONS = (count = 10) =>
  [...Array(count).keys()].map((i) => `test=list-${i}`);

describe('ToggleList', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ToggleList, {
      propsData: {
        items: MOCK_BRANCH_EXCEPTIONS(),
        ...propsData,
      },
    });
  };

  const findToggleButton = () => wrapper.findComponent(GlButton);
  const findAllListItems = () => wrapper.findAllByTestId('list-item');
  const findItemsList = () => wrapper.findByTestId('items-list');
  const findHiddenItemsText = () => wrapper.findByTestId('hidden-items-text');

  describe('initial state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should hide extra exceptions when length is over 5', () => {
      expect(findToggleButton().exists()).toBe(true);
      expect(findToggleButton().text()).toBe('+ 5 more');
      expect(findAllListItems()).toHaveLength(5);
      expect(findItemsList().classes()).toContain('gl-list-none');
    });

    it('should show all branches when show all is clicked', async () => {
      expect(findAllListItems()).toHaveLength(5);

      findToggleButton().vm.$emit('click');
      await nextTick();

      expect(findAllListItems()).toHaveLength(10);
      expect(findToggleButton().text()).toBe('Hide extra items');
    });
  });

  describe('custom text', () => {
    it('should render custom button text', () => {
      createComponent({
        propsData: {
          customButtonText: 'Hide custom items',
        },
      });
      expect(findAllListItems()).toHaveLength(5);
      expect(findToggleButton().text()).toBe('Hide custom items');
    });

    it('should render custom close button text', async () => {
      createComponent({
        propsData: {
          customCloseButtonText: 'Hide custom items',
        },
      });

      await findToggleButton().vm.$emit('click');

      expect(findToggleButton().text()).toBe('Hide custom items');
      expect(wrapper.emitted('load-next-page')).toBeUndefined();
    });
  });

  describe('without pagination', () => {
    it('should not render toggle button when there are less than 5 exceptions', () => {
      createComponent({
        propsData: {
          items: MOCK_BRANCH_EXCEPTIONS(3),
        },
      });

      expect(findAllListItems()).toHaveLength(3);
      expect(findToggleButton().exists()).toBe(false);
    });

    it('should render bullet style lists', () => {
      createComponent({
        propsData: {
          bulletStyle: true,
        },
      });

      expect(findItemsList().classes()).not.toContain('gl-list-none');
    });
  });

  describe('with pagination', () => {
    it('should emit load more pages event', () => {
      createComponent({
        propsData: {
          hasNextPage: true,
          items: MOCK_BRANCH_EXCEPTIONS(20),
        },
      });

      expect(findAllListItems()).toHaveLength(5);
      expect(findToggleButton().text()).toBe('+ 15 more');

      findToggleButton().vm.$emit('click');

      expect(wrapper.emitted('load-next-page')).toHaveLength(1);
    });

    it('should render hide button when last page is reached', () => {
      createComponent({
        propsData: {
          hasNextPage: false,
          items: MOCK_BRANCH_EXCEPTIONS(20),
          page: 4,
        },
      });

      expect(findAllListItems()).toHaveLength(20);
      expect(findToggleButton().text()).toBe('Hide extra items');

      findToggleButton().vm.$emit('click');

      expect(wrapper.emitted('load-next-page')).toBeUndefined();
    });
  });

  describe('partial rendered list', () => {
    const { length: DEFAULT_ITEMS_LENGTH } = MOCK_BRANCH_EXCEPTIONS();

    it.each`
      itemsToShow | expectedLength | expectedText
      ${2}        | ${2}           | ${'+ 8 more'}
      ${1}        | ${1}           | ${'+ 9 more'}
    `('can show only partial list', ({ itemsToShow, expectedLength, expectedText }) => {
      createComponent({
        propsData: {
          itemsToShow,
        },
      });

      expect(findAllListItems()).toHaveLength(expectedLength);
      expect(findHiddenItemsText().text()).toBe(expectedText);
      expect(findToggleButton().exists()).toBe(false);
    });

    it.each`
      itemsToShow             | expectedLength | hiddenTextExist | toggleButtonExist
      ${10}                   | ${5}           | ${false}        | ${true}
      ${undefined}            | ${5}           | ${false}        | ${true}
      ${NaN}                  | ${5}           | ${false}        | ${true}
      ${null}                 | ${5}           | ${false}        | ${true}
      ${2}                    | ${2}           | ${true}         | ${false}
      ${DEFAULT_ITEMS_LENGTH} | ${5}           | ${false}        | ${true}
    `(
      'shows full list if itemsToShow is more than total number of items',
      ({ itemsToShow, expectedLength, hiddenTextExist, toggleButtonExist }) => {
        createComponent({
          propsData: {
            itemsToShow,
          },
        });

        expect(findAllListItems()).toHaveLength(expectedLength);
        expect(findHiddenItemsText().exists()).toBe(hiddenTextExist);
        expect(findToggleButton().exists()).toBe(toggleButtonExist);
      },
    );
  });

  describe('inline list', () => {
    it('renders unstyled unordered list by default', () => {
      createComponent();

      expect(findItemsList().element.tagName).toBe('UL');
      expect(findAllListItems().at(0).element.tagName).toBe('LI');
      expect(findItemsList().classes()).toContain('gl-list-none');
    });

    it('renders div for inline list', () => {
      createComponent({
        propsData: {
          inlineList: true,
        },
      });

      expect(findItemsList().element.tagName).toBe('DIV');
      expect(findAllListItems().at(0).element.tagName).toBe('SPAN');
      expect(findItemsList().classes()).toContain('gl-flex');
    });
  });
});
