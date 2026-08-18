import { GlTableLite, GlAccordionItem } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DenyAllowViewList from 'ee/security_orchestration/components/policy_drawer/scan_result/deny_allow_view_list.vue';

describe('DenyAllowViewList', () => {
  let wrapper;

  const ITEMS = {
    licenses: {
      allowed: [
        { license: { text: 'MIT', value: 'mit' } },
        {
          license: { text: 'NPM', value: 'npm' },
          exceptions: ['pkg:npm40angular/animation@12.3.1', 'pkg:npm/foobar@12.3.1'],
        },
      ],
    },
  };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = mountExtended(DenyAllowViewList, {
      propsData: {
        items: ITEMS.licenses.allowed,
        ...propsData,
      },
    });
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableRows = () => findTable().find('tbody').findAll('tr');
  const findTableCell = ({ rowIndex, cellIndex, table = 'tbody', cellType = 'td' }) =>
    findTable().find(table).findAll('tr').at(rowIndex).findAll(cellType).at(cellIndex);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);

  describe('default rendering', () => {
    it('renders an accordion with license table', () => {
      createComponent();

      expect(findAccordionItem().props('title')).toBe('Allowlist details');
      expect(findTableRows()).toHaveLength(2);

      expect(
        findTableCell({ rowIndex: 0, cellIndex: 0, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Allowed licenses');
      expect(
        findTableCell({ rowIndex: 0, cellIndex: 1, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Exceptions that require approval');

      expect(findTableCell({ rowIndex: 0, cellIndex: 0 }).text()).toBe('MIT');
      expect(findTableCell({ rowIndex: 0, cellIndex: 1 }).text()).toBe('No exceptions');

      expect(findTableCell({ rowIndex: 1, cellIndex: 0 }).text()).toBe('NPM');
      expect(findTableCell({ rowIndex: 1, cellIndex: 1 }).text()).toBe(
        'pkg:npm40angular/animation@12.3.1 pkg:npm/foobar@12.3.1',
      );
    });

    it('renders different title', () => {
      createComponent({
        propsData: {
          isDenied: true,
        },
      });

      expect(findAccordionItem().props('title')).toBe('Denylist details');
      expect(
        findTableCell({ rowIndex: 0, cellIndex: 0, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Denied licenses');

      expect(
        findTableCell({ rowIndex: 0, cellIndex: 0, table: 'thead', cellType: 'th' }).classes(),
      ).toEqual(['!gl-pl-0', '!gl-text-sm', '!gl-border-t-0']);

      expect(
        findTableCell({ rowIndex: 0, cellIndex: 1, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Exceptions that do not require approval');
    });
  });
});
