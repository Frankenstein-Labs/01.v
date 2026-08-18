import { shallowMount } from '@vue/test-utils';
import { GlFilteredSearch } from '@gitlab/ui';
import Filters from 'ee/compliance_dashboard/components/standards_adherence_report/filters.vue';

describe('ComplianceStandardsAdherenceFilters component', () => {
  let wrapper;

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const createComponent = (props) => {
    wrapper = shallowMount(Filters, {
      propsData: {
        groupPath: 'foo',
        ...props,
      },
    });
  };

  it('includes projects token when projects list is provided', () => {
    const projects = [1, 2, 3];
    createComponent({ projects });
    expect(
      findFilteredSearch()
        .props('availableTokens')
        .map((x) => x.type),
    ).toContain('project');
  });

  it('does not include projects token when no projects are provided', () => {
    const projects = null;
    createComponent({ projects });
    expect(
      findFilteredSearch()
        .props('availableTokens')
        .map((x) => x.type),
    ).not.toContain('project');
  });
});
