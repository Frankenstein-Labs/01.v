import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormCheckbox, GlTable } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import EnableScannersSelectItems from 'ee/security_configuration/components/enable_scanners_wizard/select_items.vue';
import CheckboxCell from 'ee/security_inventory/components/checkbox_cell.vue';
import InventoryDashboardFilteredSearchBar from 'ee/security_inventory/components/inventory_dashboard_filtered_search_bar.vue';
import groupScannerDetailsProjectsQuery from 'ee/security_configuration/graphql/scan_profiles/group_scanner_details_projects.query.graphql';

Vue.use(VueApollo);

describe('EnableScannersSelectItems', () => {
  let wrapper;
  let enableScanners;

  const mockProject = (id) => ({
    id: `gid://gitlab/Project/${id}`,
    avatarUrl: null,
    name: `Project ${id}`,
    fullPath: `group/project-${id}`,
    group: { id: 'gid://gitlab/Group/1', name: 'Group', webPath: '/group' },
    securityConfigurationPath: `/group/project-${id}/-/security/configuration`,
    securityScanProfiles: [],
    analyzerStatuses: [],
    scanProfileStatuses: [],
    securityAttributes: { nodes: [] },
    __typename: 'Project',
  });

  const projects = [mockProject(1), mockProject(2)];

  const projectsResponse = (nodes = projects) => ({
    data: {
      namespaceSecurityProjects: {
        __typename: 'NamespaceSecurityProjectConnection',
        pageInfo: {
          __typename: 'PageInfo',
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
        nodes,
      },
    },
  });

  const createComponent = ({
    canReadAttributes = true,
    selectedItems = [],
    toggleItem = jest.fn(),
    toggleVisibleItems = jest.fn(),
    queryHandler = jest.fn().mockResolvedValue(projectsResponse()),
  } = {}) => {
    enableScanners = { selectedItems, toggleItem, toggleVisibleItems };

    wrapper = mountExtended(EnableScannersSelectItems, {
      apolloProvider: createMockApollo([[groupScannerDetailsProjectsQuery, queryHandler]]),
      provide: {
        groupFullPath: 'group/path',
        groupId: 1,
        canReadAttributes,
        enableScanners,
      },
      stubs: {
        GlTable: stubComponent(GlTable, {
          props: ['items', 'fields', 'busy'],
          template: `
            <div>
              <slot name="head(checkbox)" />
              <div v-for="(item, index) in items" :key="index">
                <slot name="cell(checkbox)" :item="item" />
              </div>
            </div>
          `,
        }),
        GlDisclosureDropdown: true,
        GlDisclosureDropdownItem: true,
        InventoryDashboardFilteredSearchBar: true,
        NameCell: true,
        ToolCoverageCell: true,
        AttributesCell: true,
      },
    });
  };

  const findSearchBar = () => wrapper.findComponent(InventoryDashboardFilteredSearchBar);
  const findSelectAllCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findItemCheckboxes = () => wrapper.findAllComponents(CheckboxCell);
  const findWarningIcon = () => wrapper.findByTestId('warning-icon');

  describe('projects table', () => {
    it('lists the projects returned by the graphql query', async () => {
      createComponent();
      await waitForPromises();

      expect(findItemCheckboxes()).toHaveLength(projects.length);
    });

    it('passes the active search and filter values as query variables', async () => {
      const queryHandler = jest.fn().mockResolvedValue(projectsResponse());
      createComponent({ queryHandler });
      await waitForPromises();

      const filters = {
        search: 'my term',
        securityAnalyzerFilters: [{ analyzerType: 'SAST' }],
        vulnerabilityCountFilters: [{ severity: 'HIGH' }],
        attributeFilters: [{ id: 'gid://gitlab/Attribute/1' }],
      };
      findSearchBar().vm.$emit('filter-subgroups-and-projects', filters);
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(expect.objectContaining(filters));
    });
  });

  describe('selection summary', () => {
    it('shows a count of selected items', () => {
      createComponent({ selectedItems: [projects[0], projects[1]] });

      expect(wrapper.text()).toContain('2 items selected');
      expect(findWarningIcon().exists()).toBe(false);
    });

    it('shows a warning icon when the selection limit is reached', () => {
      const selectedItems = Array.from({ length: 100 }, (_, i) => mockProject(i));
      createComponent({ selectedItems });

      expect(findWarningIcon().exists()).toBe(true);
    });
  });

  describe('select-all checkbox', () => {
    it('calls toggleVisibleItems with the visible items on change', async () => {
      const toggleVisibleItems = jest.fn();

      createComponent({ toggleVisibleItems });
      await waitForPromises();

      findSelectAllCheckbox().vm.$emit('change', true);

      expect(toggleVisibleItems).toHaveBeenCalledWith(true, projects);
    });
  });

  describe('item checkbox', () => {
    it('calls toggleItem on change', async () => {
      const toggleItem = jest.fn();

      createComponent({ toggleItem });
      await waitForPromises();

      const checkbox = findItemCheckboxes().at(0);
      const item = checkbox.props('item');

      checkbox.vm.$emit('select-item', item, true);

      expect(toggleItem).toHaveBeenCalledWith(item, true);
    });

    it('is checked when the item is in selectedItems', async () => {
      createComponent({ selectedItems: [{ id: projects[0].id }] });
      await waitForPromises();

      expect(findItemCheckboxes().at(0).props('isSelected')).toBe(true);
    });

    it('is disabled when the selection limit is reached', async () => {
      const selectedItems = Array.from({ length: 100 }, (_, i) => mockProject(i));
      createComponent({ selectedItems });
      await waitForPromises();

      expect(findItemCheckboxes().at(0).props('isSelectedLimitReached')).toBe(true);
    });
  });
});
