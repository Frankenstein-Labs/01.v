import { GlAccordion, GlAccordionItem, GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import AccordionTableList from 'ee/security_orchestration/components/policy_drawer/scan_result/accordion_table_list.vue';

describe('AccordionTableList', () => {
  let wrapper;

  const mockFields = [
    { key: 'name', label: 'Name' },
    { key: 'value', label: 'Value' },
  ];

  const mockItems = [
    { name: 'foo', value: 'bar' },
    { name: 'baz', value: 'qux' },
  ];

  const createComponent = ({ props = {}, scopedSlots = {} } = {}) => {
    wrapper = mountExtended(AccordionTableList, {
      propsData: {
        title: 'Test title',
        fields: mockFields,
        items: mockItems,
        ...props,
      },
      scopedSlots,
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableCell = ({ rowIndex, cellIndex, table = 'tbody', cellType = 'td' }) =>
    findTable().find(table).findAll('tr').at(rowIndex).findAll(cellType).at(cellIndex);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the accordion', () => {
      expect(findAccordion().exists()).toBe(true);
    });

    it('renders the accordion item with the correct title', () => {
      expect(findAccordionItem().props('title')).toBe('Test title');
    });

    it('passes items to the table', () => {
      expect(findTable().props('items')).toEqual(mockItems);
    });

    it('renders the correct column headers', () => {
      expect(
        findTableCell({ rowIndex: 0, cellIndex: 0, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Name');
      expect(
        findTableCell({ rowIndex: 0, cellIndex: 1, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Value');
    });
  });

  describe('decoratedFields', () => {
    it('applies default CSS classes to header cells', () => {
      createComponent();

      const th = findTableCell({ rowIndex: 0, cellIndex: 0, table: 'thead', cellType: 'th' });

      expect(th.classes()).toContain('!gl-pl-0');
      expect(th.classes()).toContain('!gl-text-sm');
      expect(th.classes()).toContain('!gl-border-t-0');
    });

    it('applies default CSS classes to body cells', () => {
      createComponent();

      const td = findTableCell({ rowIndex: 0, cellIndex: 0 });

      expect(td.classes()).toContain('!gl-pl-0');
      expect(td.classes()).toContain('!gl-border-none');
      expect(td.classes()).toContain('!gl-pb-3');
    });

    it('allows field-defined classes to override the defaults', () => {
      createComponent({
        props: {
          fields: [{ key: 'name', label: 'Name', thClass: 'custom-th', tdClass: 'custom-td' }],
          items: [{ name: 'foo' }],
        },
      });

      expect(
        findTableCell({ rowIndex: 0, cellIndex: 0, table: 'thead', cellType: 'th' }).classes(),
      ).toContain('custom-th');
      expect(findTableCell({ rowIndex: 0, cellIndex: 0 }).classes()).toContain('custom-td');
    });
  });

  describe('slot forwarding', () => {
    it('renders custom cell slot content', () => {
      createComponent({
        scopedSlots: {
          'cell(name)': '<span data-testid="custom-cell">{{ props.item.name }}</span>',
        },
      });

      expect(wrapper.findByTestId('custom-cell').text()).toBe('foo');
    });
  });
});
