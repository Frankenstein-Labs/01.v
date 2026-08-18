import { shallowMount } from '@vue/test-utils';
import GroupedTable from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/grouped_table.vue';
import TablePart from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/table_part.vue';
import GroupedPart from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/grouped_part.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import { GROUP_BY } from 'ee/compliance_dashboard/components/standards_adherence_report/constants';

const fakeGroup = [
  {
    id: 1,
    status: 'failed',
    requirement: 'req1',
    framework: 'fw1',
    project: 'proj1',
    lastScanned: '2023-01-01',
  },
  {
    id: 2,
    status: 'passed',
    requirement: 'req2',
    framework: 'fw2',
    project: 'proj2',
    lastScanned: '2023-01-02',
  },
];

const mockGroupedItems = [
  {
    id: 'group-1',
    groupValue: { name: 'Test Framework', webUrl: '/framework/1' },
    failCount: 3,
    children: fakeGroup,
  },
  {
    id: 'group-2',
    groupValue: { name: 'Another Framework', webUrl: '/framework/2' },
    failCount: 1,
    children: [fakeGroup[0]],
  },
];

const mockProjectGroupedItems = [
  {
    id: 'project-1',
    groupValue: { name: 'Test Project', webUrl: '/project/1' },
    failCount: 2,
    children: fakeGroup,
  },
];

describe('GroupedTable', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(GroupedTable, {
      propsData: {
        items: [{ group: null, children: fakeGroup }],
        ...props,
      },
      stubs: {
        GroupedPart,
      },
    });
  };

  const findTablePart = () => wrapper.findComponent(TablePart);
  const findAllTableParts = () => wrapper.findAllComponents(TablePart);
  const findAllGroupedParts = () => wrapper.findAllComponents(GroupedPart);
  const findFrameworkBadge = () => wrapper.findComponent(FrameworkBadge);

  describe('when grouping is not present', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders only one TablePart component', () => {
      expect(findAllTableParts()).toHaveLength(1);
      expect(findAllGroupedParts()).toHaveLength(0);
    });

    it('passes the correct props to TablePart', () => {
      const tablePart = findTablePart();
      expect(tablePart.props('items')).toStrictEqual(fakeGroup);
      expect(tablePart.props('fields')).toBeDefined();
    });

    it('includes all fields when no grouping is applied', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      expect(fields).toHaveLength(6);
      expect(fields.map((f) => f.key)).toEqual([
        'status',
        'requirement',
        'framework',
        'project',
        'lastScanned',
        'fixSuggestions',
      ]);
    });

    it('applies correct field widths for ungrouped view', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      const requirementField = fields.find((f) => f.key === 'requirement');
      const frameworkField = fields.find((f) => f.key === 'framework');
      const projectField = fields.find((f) => f.key === 'project');

      expect(requirementField.tdClass).toBe('@md/panel:gl-w-3/20');
      expect(frameworkField.tdClass).toBe('@md/panel:gl-w-3/20');
      expect(projectField.tdClass).toBe('@md/panel:gl-w-4/20');
    });
  });

  describe('when grouping by frameworks', () => {
    beforeEach(() => {
      createComponent({
        items: mockGroupedItems,
        groupBy: GROUP_BY.FRAMEWORKS,
      });
    });

    it('renders header TablePart and GroupedPart components', () => {
      expect(findAllTableParts()).toHaveLength(3); // 1 header + 2 grouped
      expect(findAllGroupedParts()).toHaveLength(2);
    });

    it('renders header TablePart with empty items', () => {
      const headerTablePart = findAllTableParts().at(0);
      expect(headerTablePart.props('items')).toEqual([]);
    });

    it('excludes framework field from fields when grouping by frameworks', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      expect(fields).toHaveLength(5);
      expect(fields.map((f) => f.key)).toEqual([
        'status',
        'requirement',
        'project',
        'lastScanned',
        'fixSuggestions',
      ]);
      expect(fields.find((f) => f.key === 'framework')).toBeUndefined();
    });

    it('applies correct field widths for framework grouping', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      const requirementField = fields.find((f) => f.key === 'requirement');
      const projectField = fields.find((f) => f.key === 'project');

      expect(requirementField.tdClass).toBe('@md/panel:gl-w-5/20');
      expect(projectField.tdClass).toBe('@md/panel:gl-w-5/20');
    });

    it('renders FrameworkBadge in group headers', () => {
      const frameworkBadge = findFrameworkBadge();
      expect(frameworkBadge.exists()).toBe(true);
      expect(frameworkBadge.props('framework')).toEqual(mockGroupedItems[0].groupValue);
      expect(frameworkBadge.props('popoverMode')).toBe('hidden');
    });

    it('passes correct items to grouped TableParts', () => {
      const groupedTableParts = findAllTableParts().filter((_, index) => index > 0);
      expect(groupedTableParts.at(0).props('items')).toEqual(mockGroupedItems[0].children);
      expect(groupedTableParts.at(1).props('items')).toEqual(mockGroupedItems[1].children);
    });

    it('applies hidden thead class to grouped TableParts', () => {
      const groupedTableParts = findAllTableParts().filter((_, index) => index > 0);
      expect(groupedTableParts.at(0).props('theadClass')).toBe('gl-hidden');
      expect(groupedTableParts.at(1).props('theadClass')).toBe('gl-hidden');
    });
  });

  describe('when grouping by projects', () => {
    beforeEach(() => {
      createComponent({
        items: mockProjectGroupedItems,
        groupBy: GROUP_BY.PROJECTS,
      });
    });

    it('excludes project field from fields when grouping by projects', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      expect(fields).toHaveLength(5);
      expect(fields.map((f) => f.key)).toEqual([
        'status',
        'requirement',
        'framework',
        'lastScanned',
        'fixSuggestions',
      ]);
      expect(fields.find((f) => f.key === 'project')).toBeUndefined();
    });

    it('applies correct field widths for project grouping', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      const requirementField = fields.find((f) => f.key === 'requirement');
      const frameworkField = fields.find((f) => f.key === 'framework');

      expect(requirementField.tdClass).toBe('@md/panel:gl-w-5/20');
      expect(frameworkField.tdClass).toBe('@md/panel:gl-w-5/20');
    });

    it('renders group name in headers', () => {
      expect(wrapper.text()).toContain('Test Project');
    });
  });

  describe('when grouping by requirements', () => {
    beforeEach(() => {
      createComponent({
        items: mockGroupedItems,
        groupBy: GROUP_BY.REQUIREMENTS,
      });
    });

    it('excludes requirement field from fields when grouping by requirements', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      expect(fields).toHaveLength(5);
      expect(fields.map((f) => f.key)).toEqual([
        'status',
        'framework',
        'project',
        'lastScanned',
        'fixSuggestions',
      ]);
      expect(fields.find((f) => f.key === 'requirement')).toBeUndefined();
    });

    it('applies correct field widths for requirement grouping', () => {
      const tablePart = findTablePart();
      const fields = tablePart.props('fields');

      const frameworkField = fields.find((f) => f.key === 'framework');
      const projectField = fields.find((f) => f.key === 'project');

      expect(frameworkField.tdClass).toBe('@md/panel:gl-w-5/20');
      expect(projectField.tdClass).toBe('@md/panel:gl-w-5/20');
    });

    it('renders group name in header', () => {
      expect(wrapper.text()).toContain('Test Framework');
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes through row-selected event when TablePart emits it', () => {
      const rowData = { id: 1 };
      findTablePart().vm.$emit('row-selected', rowData);
      expect(wrapper.emitted('row-selected')[0]).toEqual([rowData]);
    });
  });
});
