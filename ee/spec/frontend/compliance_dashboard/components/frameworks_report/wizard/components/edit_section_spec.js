import EditSection from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/edit_section.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('EditSection', () => {
  let wrapper;

  const title = 'Foo';
  const description = 'Bar';
  const itemsCount = 10;

  const findTitle = () => wrapper.findByText(title);
  const findDescription = () => wrapper.findByText(description);
  const findCountBadge = () => wrapper.findByTestId('count-badge');
  const findStatusBadge = () => wrapper.findComponentByTestId('status-badge');

  const createComponent = (propsData = {}) => {
    wrapper = mountExtended(EditSection, {
      propsData: {
        title,
        description,
        ...propsData,
      },
      slots: {
        default: '<p data-testid="slot-content">slot content</p>',
      },
    });
  };

  it('renders title', () => {
    createComponent();
    expect(findTitle().exists()).toBe(true);
  });

  it('renders description', () => {
    createComponent();
    expect(findDescription().exists()).toBe(true);
  });

  it('always renders the slot content (not collapsible)', () => {
    createComponent();
    expect(wrapper.findByTestId('slot-content').exists()).toBe(true);
  });

  describe('count badge rendering', () => {
    it('does not render count badge by default', () => {
      createComponent();
      expect(findCountBadge().exists()).toBe(false);
    });

    it('renders count badge with number when itemsCount is provided', () => {
      createComponent({ itemsCount });
      expect(findCountBadge().text()).toBe('10');
    });
  });

  describe('status badge rendering', () => {
    it('renders status badge as Optional by default', () => {
      createComponent();
      expect(findStatusBadge().text()).toBe('Optional');
    });

    it('renders status badge as Required when isRequired prop is true', () => {
      createComponent({ isRequired: true });
      expect(findStatusBadge().text()).toBe('Required');
    });

    it('does not render icon by default', () => {
      createComponent();
      expect(findStatusBadge().props('icon')).toBe('');
    });

    it('renders icon when items count is passed', () => {
      createComponent({ itemsCount });
      expect(findStatusBadge().props('icon')).toBe('check-circle');
    });

    it('renders icon when isCompleted is true', () => {
      createComponent({ isCompleted: true });
      expect(findStatusBadge().props('icon')).toBe('check-circle');
    });
  });
});
