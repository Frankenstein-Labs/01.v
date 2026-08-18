import { GlAccordion, GlAccordionItem, GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import LicenseOverridesViewList from 'ee/security_orchestration/components/policy_drawer/scan_result/license_overrides_view_list.vue';
import {
  OVERRIDE_MODE_PATCH,
  OVERRIDE_MODE_OVERWRITE,
  OVERRIDE_MODE_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('LicenseOverridesViewList', () => {
  let wrapper;

  const mockItems = [
    { purl: 'pkg:pypi/urllib3', license: 'MIT License', mode: OVERRIDE_MODE_PATCH },
    { purl: 'pkg:gem/rails', license: 'Apache-2.0', mode: OVERRIDE_MODE_OVERWRITE },
  ];

  const createComponent = ({ props = {} } = {}) => {
    wrapper = mountExtended(LicenseOverridesViewList, {
      propsData: {
        items: [],
        ...props,
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableCell = ({ rowIndex, cellIndex, table = 'tbody', cellType = 'td' }) =>
    findTable().find(table).findAll('tr').at(rowIndex).findAll(cellType).at(cellIndex);

  describe('default state (no items)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the accordion', () => {
      expect(findAccordion().exists()).toBe(true);
    });

    it('renders the accordion item with correct title', () => {
      expect(findAccordionItem().props('title')).toBe('License override details');
    });

    it('renders the correct column headers', () => {
      expect(
        findTableCell({ rowIndex: 0, cellIndex: 0, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Package (purl)');
      expect(
        findTableCell({ rowIndex: 0, cellIndex: 1, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Override license');
      expect(
        findTableCell({ rowIndex: 0, cellIndex: 2, table: 'thead', cellType: 'th' }).text(),
      ).toBe('Mode');
    });
  });

  describe('with items', () => {
    beforeEach(() => {
      createComponent({ props: { items: mockItems } });
    });

    it('renders the purl for each row', () => {
      expect(findTableCell({ rowIndex: 0, cellIndex: 0 }).text()).toBe('pkg:pypi/urllib3');
      expect(findTableCell({ rowIndex: 1, cellIndex: 0 }).text()).toBe('pkg:gem/rails');
    });

    it('renders the license for each row', () => {
      expect(findTableCell({ rowIndex: 0, cellIndex: 1 }).text()).toBe('MIT License');
      expect(findTableCell({ rowIndex: 1, cellIndex: 1 }).text()).toBe('Apache-2.0');
    });

    it('renders the correct mode text for patch', () => {
      expect(findTableCell({ rowIndex: 0, cellIndex: 2 }).text()).toBe(
        OVERRIDE_MODE_OPTIONS[OVERRIDE_MODE_PATCH],
      );
    });

    it('renders the correct mode text for overwrite', () => {
      expect(findTableCell({ rowIndex: 1, cellIndex: 2 }).text()).toBe(
        OVERRIDE_MODE_OPTIONS[OVERRIDE_MODE_OVERWRITE],
      );
    });

    it('defaults to patch mode text for unknown mode', () => {
      createComponent({
        props: { items: [{ purl: 'pkg:npm/foo', license: 'MIT', mode: 'unknown_mode' }] },
      });

      expect(findTableCell({ rowIndex: 0, cellIndex: 2 }).text()).toBe(
        OVERRIDE_MODE_OPTIONS[OVERRIDE_MODE_PATCH],
      );
    });

    it('defaults to patch mode text for undefined mode', () => {
      createComponent({
        props: { items: [{ purl: 'pkg:npm/foo', license: 'MIT' }] },
      });

      expect(findTableCell({ rowIndex: 0, cellIndex: 2 }).text()).toBe(
        OVERRIDE_MODE_OPTIONS[OVERRIDE_MODE_PATCH],
      );
    });
  });
});
