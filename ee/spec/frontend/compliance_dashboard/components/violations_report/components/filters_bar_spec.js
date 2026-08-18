import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import FiltersBar from 'ee/compliance_dashboard/components/violations_report/components/filters_bar.vue';
import StatusToken from 'ee/compliance_dashboard/components/violations_report/components/tokens/status_token.vue';
import ProjectToken from 'ee/compliance_dashboard/components/standards_adherence_report/components/filters_bar/tokens/project_token.vue';
import ControlToken from 'ee/compliance_dashboard/components/violations_report/components/tokens/control_token.vue';
import DateToken from '~/vue_shared/components/filtered_search_bar/tokens/date_token.vue';

describe('FiltersBar component', () => {
  let wrapper;

  const groupPath = 'test-group';

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  const createComponent = (props = {}) => {
    wrapper = shallowMount(FiltersBar, {
      propsData: {
        groupPath,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders GlFilteredSearch component', () => {
    expect(findFilteredSearch().exists()).toBe(true);
  });

  it('renders filter label', () => {
    expect(wrapper.text()).toContain('Filter by');
  });

  describe('filter tokens', () => {
    it('renders all filter tokens (status, project, control, createdAfter, createdBefore)', () => {
      const filteredSearch = findFilteredSearch();
      const tokens = filteredSearch.props('availableTokens');

      expect(tokens).toHaveLength(5);
      expect(tokens[0].type).toBe('status');
      expect(tokens[1].type).toBe('projectId');
      expect(tokens[2].type).toBe('controlId');
      expect(tokens[3].type).toBe('createdAfter');
      expect(tokens[4].type).toBe('createdBefore');
    });

    it.each`
      index | type               | title                | tokenComponent
      ${3}  | ${'createdAfter'}  | ${'Detected after'}  | ${DateToken}
      ${4}  | ${'createdBefore'} | ${'Detected before'} | ${DateToken}
    `('configures $type token correctly', ({ index, title, tokenComponent }) => {
      const filteredSearch = findFilteredSearch();
      const tokens = filteredSearch.props('availableTokens');
      const dateToken = tokens[index];

      expect(dateToken.title).toBe(title);
      expect(dateToken.token).toBe(tokenComponent);
      expect(dateToken.unique).toBe(true);
      expect(dateToken.operators).toEqual([{ value: '=', description: 'is' }]);
    });

    it('configures status token correctly', () => {
      const filteredSearch = findFilteredSearch();
      const tokens = filteredSearch.props('availableTokens');
      const statusToken = tokens[0];

      expect(statusToken.title).toBe('Status');
      expect(statusToken.token).toBe(StatusToken);
      expect(statusToken.unique).toBe(true);
      expect(statusToken.operators).toEqual([{ value: '=', description: 'is' }]);
    });

    it('configures project token correctly', () => {
      const filteredSearch = findFilteredSearch();
      const tokens = filteredSearch.props('availableTokens');
      const projectToken = tokens[1];

      expect(projectToken.title).toBe('Project');
      expect(projectToken.token).toBe(ProjectToken);
      expect(projectToken.unique).toBe(true);
      expect(projectToken.fullPath).toBe(groupPath);
      expect(projectToken.operators).toEqual([{ value: '=', description: 'is' }]);
    });

    it('configures control token correctly', () => {
      const filteredSearch = findFilteredSearch();
      const tokens = filteredSearch.props('availableTokens');
      const controlToken = tokens[2];

      expect(controlToken.title).toBe('Control');
      expect(controlToken.token).toBe(ControlToken);
      expect(controlToken.unique).toBe(true);
      expect(controlToken.groupPath).toBe(groupPath);
      expect(controlToken.operators).toEqual([{ value: '=', description: 'is' }]);
    });

    it('passes groupPath prop to project and control tokens', () => {
      const filteredSearch = findFilteredSearch();
      const tokens = filteredSearch.props('availableTokens');
      const projectToken = tokens.find((t) => t.type === 'projectId');
      const controlToken = tokens.find((t) => t.type === 'controlId');

      expect(projectToken.fullPath).toBe(groupPath);
      expect(controlToken.groupPath).toBe(groupPath);
    });
  });

  describe('filter submission', () => {
    it('emits update:filters event on filter submit with correct format', () => {
      const filterValue = [
        { type: 'status', value: { data: 'detected', operator: '=' } },
        { type: 'projectId', value: { data: 'gid://gitlab/Project/1', operator: '=' } },
      ];

      findFilteredSearch().vm.$emit('submit', filterValue);

      expect(wrapper.emitted('update:filters')).toHaveLength(1);
      expect(wrapper.emitted('update:filters')[0][0]).toEqual({
        status: 'DETECTED',
        projectId: 'gid://gitlab/Project/1',
      });
    });

    it('filters out tokens without type', () => {
      const filterValue = [
        { type: 'status', value: { data: 'detected', operator: '=' } },
        { type: '', value: { data: 'invalid', operator: '=' } },
        { type: 'projectId', value: { data: 'gid://gitlab/Project/1', operator: '=' } },
      ];

      findFilteredSearch().vm.$emit('submit', filterValue);

      expect(wrapper.emitted('update:filters')[0][0]).toEqual({
        status: 'DETECTED',
        projectId: 'gid://gitlab/Project/1',
      });
    });

    it('updates selectedTokens on filter submit', () => {
      const filterValue = [{ type: 'status', value: { data: 'detected', operator: '=' } }];

      findFilteredSearch().vm.$emit('submit', filterValue);

      // Check that the component emits the expected filter values
      expect(wrapper.emitted('update:filters')).toHaveLength(1);
    });
  });

  describe('filter clearing', () => {
    it('emits update:filters with empty object on clear', () => {
      findFilteredSearch().vm.$emit('clear');

      expect(wrapper.emitted('update:filters')).toHaveLength(1);
      expect(wrapper.emitted('update:filters')[0][0]).toEqual({});
    });

    it('resets selectedTokens on clear', () => {
      // First submit a filter to set state
      const filterValue = [{ type: 'status', value: { data: 'detected', operator: '=' } }];
      findFilteredSearch().vm.$emit('submit', filterValue);

      // Then clear
      findFilteredSearch().vm.$emit('clear');

      // Check that empty filters are emitted
      expect(wrapper.emitted('update:filters')[1][0]).toEqual({});
    });
  });
});
