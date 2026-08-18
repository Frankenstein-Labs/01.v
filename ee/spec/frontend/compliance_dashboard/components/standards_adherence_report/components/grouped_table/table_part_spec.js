import { mount } from '@vue/test-utils';
import { GlTable, GlLink, GlButton } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import RequirementStatusWithTooltip from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/requirement_status_with_tooltip.vue';
import TablePart from 'ee/compliance_dashboard/components/standards_adherence_report/components/grouped_table/table_part.vue';

describe('TablePart', () => {
  let wrapper;

  const findDetailsButton = () =>
    wrapper.find('tbody tr:first-child td:nth-child(6)').findComponent(GlButton);

  const mockItems = [
    {
      id: 1,
      passCount: 5,
      pendingCount: 2,
      failCount: 1,
      complianceRequirement: { name: 'Requirement 1' },
      complianceFramework: { name: 'Framework 1', color: '#ff0000' },
      project: { name: 'Project 1', webUrl: '/project/1' },
      updatedAt: '2023-01-01T00:00:00Z',
    },
    {
      id: 2,
      passCount: 3,
      pendingCount: 0,
      failCount: 4,
      complianceRequirement: { name: 'Requirement 2' },
      complianceFramework: { name: 'Framework 2', color: '#00ff00' },
      project: { name: 'Project 2', webUrl: '/project/2' },
      updatedAt: '2023-02-01T00:00:00Z',
    },
  ];

  const mockFields = [
    { key: 'status', label: 'Status' },
    { key: 'requirement', label: 'Requirement' },
    { key: 'framework', label: 'Framework' },
    { key: 'project', label: 'Project' },
    { key: 'lastScanned', label: 'Last Scanned' },
    { key: 'fixSuggestions', label: 'Fix Suggestions' },
  ];

  const createComponent = (props = {}) => {
    wrapper = mount(TablePart, {
      propsData: {
        items: mockItems,
        fields: mockFields,
        ...props,
      },
      stubs: {
        GlTable,
        RequirementStatusWithTooltip: true,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders RequirementStatus component in status cell', () => {
    const statusSlot = wrapper.findComponent(RequirementStatusWithTooltip);
    expect(statusSlot.exists()).toBe(true);
    expect(statusSlot.props('status')).toBe(mockItems[0]);
  });

  it('renders requirement name in requirement cell', () => {
    const requirementCell = wrapper.find('tbody tr:first-child td:nth-child(2)');
    expect(requirementCell.text()).toContain(mockItems[0].complianceRequirement.name);
  });

  it('renders FrameworkBadge in framework cell', () => {
    const frameworkBadge = wrapper.findComponent(FrameworkBadge);
    expect(frameworkBadge.exists()).toBe(true);
    expect(frameworkBadge.props('framework')).toEqual(mockItems[0].complianceFramework);
    expect(frameworkBadge.props('popoverMode')).toBe('details');
  });

  it('renders project link in project cell', () => {
    const projectLink = wrapper.findComponent(GlLink);
    expect(projectLink.exists()).toBe(true);
    expect(projectLink.attributes('href')).toBe(mockItems[0].project.webUrl);
    expect(projectLink.text()).toBe(mockItems[0].project.name);
  });

  it('renders TimeAgoTooltip in lastScanned cell', () => {
    const timeAgo = wrapper.findComponent(TimeAgoTooltip);
    expect(timeAgo.exists()).toBe(true);
    expect(timeAgo.props('time')).toBe(mockItems[0].updatedAt);
  });

  it('renders view details button in fixSuggestions cell', () => {
    const button = findDetailsButton();
    expect(button.exists()).toBe(true);
    expect(button.text()).toBe('View details');
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits row-selected when a row is selected', async () => {
      await wrapper.findComponent(GlTable).find('tbody > tr').trigger('click');
      expect(wrapper.emitted('row-selected')[0][0]).toEqual(mockItems[0]);
    });

    it('emits row-selected when view details button is clicked', async () => {
      await findDetailsButton().trigger('click');

      expect(wrapper.emitted('row-selected')[0][0]).toEqual(mockItems[0]);
    });
  });
});
