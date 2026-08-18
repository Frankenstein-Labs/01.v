import {
  GlLoadingIcon,
  GlSearchBoxByClick,
  GlTable,
  GlLink,
  GlModal,
  GlAlert,
  GlDisclosureDropdown,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createApolloProvider } from '@vue/apollo-option';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { useFakeDate } from 'helpers/fake_date';
import waitForPromises from 'helpers/wait_for_promises';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import {
  createComplianceFrameworksReportResponse,
  createFramework,
  addRequirementsToFrameworks,
  createFrameworksWithManyRequirements,
} from 'ee_jest/compliance_dashboard/mock_data';
import FrameworksTable from 'ee/compliance_dashboard/components/frameworks_report/frameworks_table.vue';
import FrameworkInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/framework_info_drawer.vue';
import { ROUTE_EDIT_FRAMEWORK, ROUTE_EXPORT_FRAMEWORK } from 'ee/compliance_dashboard/constants';
import { DOCS_URL } from '~/constants';
import DeleteModal from 'ee/compliance_dashboard/components/frameworks_report/wizard/components/delete_modal.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import updateComplianceFrameworkMutation from 'ee/compliance_dashboard/graphql/mutations/update_compliance_framework.mutation.graphql';
import { createMockClient } from 'helpers/mock_apollo_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

// 2025-05-03T00:00:00.000Z
useFakeDate(2025, 4, 3);

Vue.use(VueApollo);

jest.mock('~/lib/utils/axios_utils');
jest.mock('~/lib/utils/copy_to_clipboard', () => ({
  copyToClipboard: jest.fn().mockResolvedValue(),
}));

describe('FrameworksTable component', () => {
  let wrapper;
  let $router;
  const $toast = {
    show: jest.fn(),
  };

  const GROUP_PATH = 'group';
  const SUBGROUP_PATH = `${GROUP_PATH}/subgroup`;
  const PROJECTS_TOTAL_COUNT = 50;
  const frameworksResponse = createComplianceFrameworksReportResponse({
    count: 2,
    projects: 2,
    projectsTotalCount: PROJECTS_TOTAL_COUNT,
    groupPath: GROUP_PATH,
  });
  const frameworks = frameworksResponse.data.namespace.complianceFrameworks.nodes;
  const projects = frameworks[0].projects.nodes;
  const rowCheckIndex = 0;
  const modalStub = { show: jest.fn(), hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });
  const frameworksWithRequirements = addRequirementsToFrameworks(frameworks);
  const frameworksWithManyRequirements = createFrameworksWithManyRequirements(frameworks, 15);

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableHeaders = () => findTable().findAll('th > div > span');
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findByText('No frameworks found');
  const findTableLinks = (idx) => findTableRow(idx).findAllComponents(GlLink);
  const findFrameworkInfoSidebar = () => wrapper.findComponent(FrameworkInfoDrawer);
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByClick);
  const findNoFrameworksAlert = () => wrapper.findComponent(GlAlert);
  const findActionsDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findActionsDropdownItems = () => findActionsDropdowns().at(0).findAll('.gl-mx-2');
  const findEditAction = () => wrapper.findComponentByTestId('action-edit');
  const findDeleteAction = () => wrapper.findComponentByTestId('action-delete');
  const findSetAsDefaultAction = () => wrapper.findByTestId('action-set-as-default');
  const findCopyIdAction = () => wrapper.findComponentByTestId('action-copy-id');
  const findDeleteActionTooltip = () => wrapper.findByTestId('delete-tooltip');
  const findSetAsDefaultActionTooltip = () => wrapper.findByTestId('set-as-default-tooltip');
  const findDeleteModal = () => wrapper.findComponent(DeleteModal);
  const findBadge = () => wrapper.findComponent(FrameworkBadge);
  const findRequirementsColumn = (idx) => findTableRowData(idx).at(2);

  const toggleSidebar = async () => {
    findTableRow(rowCheckIndex).trigger('click');
    await nextTick();
  };

  const createComponent = (props = {}, queryParams = {}, options = {}) => {
    const currentQueryParams = { ...queryParams };
    $router = {
      push: jest.fn().mockImplementation(({ query }) => {
        Object.assign(currentQueryParams, query);
      }),
    };

    const defaultApolloProvider =
      options.apolloProvider ||
      createApolloProvider({
        defaultClient: createMockClient(),
      });

    return mountExtended(FrameworksTable, {
      propsData: {
        groupPath: GROUP_PATH,
        rootAncestor: {
          path: GROUP_PATH,
          name: 'Group',
          complianceCenterPath: 'group/compliance_dashboard',
        },
        frameworks: [],
        isLoading: true,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      provide: {
        groupSecurityPoliciesPath: '/example-group-security-policies-path',
        policyDisplayLimit: 10,
      },
      mocks: {
        $route: { query: currentQueryParams },
        $router,
        $toast,
      },
      stubs: {
        EditForm: true,
        FrameworkInfoDrawer: true,
        GlModal: GlModalStub,
        ...options.stubs,
      },
      apolloProvider: defaultApolloProvider,
      attachTo: document.body,
    });
  };

  describe('default behavior', () => {
    it('renders the loading indicator while loading', () => {
      wrapper = createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTable().text()).not.toContain('No frameworks found');
    });

    it('renders the empty state when no frameworks found', () => {
      wrapper = createComponent({ isLoading: false });

      const emptyState = findEmptyState();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.text()).toBe('No frameworks found');
    });

    it('has the correct table headers for top-level group', () => {
      wrapper = createComponent({ isLoading: false });

      const headerTexts = findTableHeaders().wrappers.map((h) => h.text());
      expect(headerTexts).toStrictEqual([
        'Frameworks',
        'Source',
        'Requirements',
        'Associated projects',
        'Policies',
        'Last updated',
        'Action',
      ]);
    });

    it('emits search event when underlying search box is submitted', () => {
      wrapper = createComponent({ isLoading: false });

      findSearchBox().vm.$emit('submit', 'test');
      expect(wrapper.emitted('search').at(-1)).toStrictEqual(['test']);
    });

    it('emits search event with empty value when underlying search box is cleared', () => {
      wrapper = createComponent({ isLoading: false });

      findSearchBox().vm.$emit('clear');
      expect(wrapper.emitted('search').at(-1)).toStrictEqual(['']);
    });

    it('emits sort-changed when sorting items', async () => {
      wrapper = createComponent({ isLoading: false });

      const expectedPayload = { sortBy: 'updatedAt', sortDesc: false };

      await findTable().vm.$emit('sort-changed', expectedPayload);

      expect(wrapper.emitted('sort-changed')[0]).toEqual([expectedPayload]);
    });
  });

  describe('when projectPath is provided', () => {
    it('has the correct table headers', () => {
      wrapper = createComponent({ isLoading: false, groupPath: null, projectPath: 'foo/bar' });

      const headerTexts = findTableHeaders().wrappers.map((h) => h.text());
      expect(headerTexts).toStrictEqual([
        'Frameworks',
        'Source',
        'Requirements',
        'Policies',
        'Last updated',
        'Action',
      ]);
    });

    it('does not render search bar', () => {
      wrapper = createComponent({ isLoading: false, groupPath: null, projectPath: 'foo/bar' });

      expect(findSearchBox().exists()).toBe(false);
    });
  });

  describe('No frameworks alert', () => {
    it('does not render for a top-level group when there are frameworks', () => {
      wrapper = createComponent({
        isLoading: false,
      });
      expect(findNoFrameworksAlert().exists()).toBe(false);
    });

    it('renders alert with links for a sub group when there are no frameworks', () => {
      const links = () => findNoFrameworksAlert().findAllComponents(GlLink);
      wrapper = createComponent({
        isLoading: false,
        groupPath: SUBGROUP_PATH,
      });
      expect(findNoFrameworksAlert().text()).toMatchInterpolatedText(
        'No frameworks found. Create a framework in top-level group Group. Learn more.',
      );
      expect(links().at(0).attributes('href')).toBe('group/compliance_dashboard');
      expect(links().at(1).attributes('href')).toBe(
        `${DOCS_URL}/user/group/compliance_frameworks.html#prerequisites`,
      );
    });

    it('does not render for a sub group when there are frameworks', () => {
      wrapper = createComponent({
        frameworks,
        groupPath: SUBGROUP_PATH,
        isLoading: false,
      });
      expect(findNoFrameworksAlert().exists()).toBe(false);
    });
  });

  describe('Requirements column', () => {
    it('displays requirements names in the requirements column', () => {
      wrapper = createComponent({
        frameworks: frameworksWithRequirements,
        isLoading: false,
      });

      const requirementsColumn = findRequirementsColumn(0);
      const findRequirementItems = requirementsColumn.findAll('[data-testid="requirement-item"]');

      expect(requirementsColumn.text()).toContain('SOC2');
      expect(requirementsColumn.text()).toContain('GitLab');
      expect(requirementsColumn.text()).toContain('External');
      expect(findRequirementItems).toHaveLength(3);
    });

    it('separates requirements with commas', () => {
      wrapper = createComponent({
        frameworks: frameworksWithRequirements,
        isLoading: false,
      });

      const requirementsColumn = findRequirementsColumn(0);
      const findRequirementItems = requirementsColumn.findAll('[data-testid="requirement-item"]');

      expect(requirementsColumn.text()).toContain('SOC2,');
      expect(requirementsColumn.text()).toContain('GitLab,');
      expect(findRequirementItems).toHaveLength(3);
    });

    it(`limits the displayed requirements to 10 items`, () => {
      wrapper = createComponent({
        frameworks: frameworksWithManyRequirements,
        isLoading: false,
      });

      const requirementsColumn = findRequirementsColumn(0);
      const findRequirementItems = requirementsColumn.findAll('[data-testid="requirement-item"]');

      expect(findRequirementItems).toHaveLength(10);
    });

    it('does not show and X more when requirements are within display limit', () => {
      wrapper = createComponent({
        frameworks: frameworksWithRequirements,
        isLoading: false,
      });

      const requirementsColumn = findRequirementsColumn(0);
      const findRequirementItems = requirementsColumn.findAll('[data-testid="requirement-item"]');

      expect(requirementsColumn.text()).not.toContain('and');
      expect(requirementsColumn.text()).not.toContain('more');
      expect(findRequirementItems).toHaveLength(3);
    });
  });

  describe('Last updated column', () => {
    describe('when relative time is set to true', () => {
      it('displays last updated relative time for groups', () => {
        wrapper = createComponent({
          frameworks,
          isLoading: false,
        });

        frameworks.forEach((framework, idx) => {
          const date = findTableRowData(idx).at(5);
          expect(date.text()).toBe('4 weeks ago');
        });
      });

      it('displays last updated for relative time projects', () => {
        wrapper = createComponent({
          frameworks,
          isLoading: false,
          groupPath: null,
          projectPath: 'my-group/my-project',
        });

        frameworks.forEach((framework, idx) => {
          const date = findTableRowData(idx).at(4);
          expect(date.text()).toBe('4 weeks ago');
        });
      });
    });

    describe('when relative time is set to false', () => {
      beforeEach(() => {
        window.gon = { time_display_relative: false };
      });

      it('displays last updated absolute time for groups', () => {
        wrapper = createComponent({
          frameworks,
          isLoading: false,
        });

        frameworks.forEach((framework, idx) => {
          const date = findTableRowData(idx).at(5);
          expect(date.text()).toBe('Apr 3, 2025, 2:01 AM');
        });
      });

      it('displays last updated absolute time for projects', () => {
        wrapper = createComponent({
          frameworks,
          isLoading: false,
          groupPath: null,
          projectPath: 'my-group/my-project',
        });

        frameworks.forEach((framework, idx) => {
          const date = findTableRowData(idx).at(4);
          expect(date.text()).toBe('Apr 3, 2025, 2:01 AM');
        });
      });
    });
  });

  describe('when there are policies', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it.each(Object.keys(frameworks))('has the correct data for row %s', (idx) => {
      const policyCell = findTableRowData(idx).at(4);
      const frameworkPolicies = policyCell.text().replace(/,\s+/g, ', ');

      expect(frameworkPolicies).toMatch(
        frameworks[idx].securityPolicies.nodes.map((x) => x.name).join(', '),
      );
    });
  });

  describe('when there are projects', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it.each(Object.keys(frameworks))('has the correct data for row %s', (idx) => {
      const [frameworkName] = findTableRowData(idx).wrappers.map((d) => d.text());
      expect(frameworkName).toContain(frameworks[idx].name);

      const projectLinks = findTableLinks(idx);

      expect(projectLinks.wrappers).toHaveLength(2);
      expect(projectLinks.wrappers.map((w) => w.attributes('href'))).toStrictEqual(
        projects.map((p) => p.webUrl),
      );
    });

    describe('Sidebar', () => {
      describe('edit button in sidebar', () => {
        describe('when query has framework id', () => {
          beforeEach(() => {
            wrapper = createComponent(
              {
                frameworks,
                isLoading: false,
              },
              { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
            );
          });

          it('passes the selected framework as a framework prop', () => {
            expect(findFrameworkInfoSidebar().props('framework')).toMatchObject(
              frameworks[rowCheckIndex],
            );
          });
        });

        describe('when query does not have framework id', () => {
          it('the framework prop is null', () => {
            expect(findFrameworkInfoSidebar().props('framework')).toBe(null);
          });

          it('adds id to the query after sidebar is open', async () => {
            await toggleSidebar();

            expect($router.push).toHaveBeenCalledWith({
              query: { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
            });
          });
        });

        it('opens edit form for the framework', async () => {
          await toggleSidebar();

          await findFrameworkInfoSidebar().vm.$emit('edit', frameworks[rowCheckIndex]);

          expect($router.push).toHaveBeenCalledWith({
            name: ROUTE_EDIT_FRAMEWORK,
            params: { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
          });
        });
      });

      describe('closing the sidebar', () => {
        it('has the correct props when closed', async () => {
          await toggleSidebar();

          await findFrameworkInfoSidebar().vm.$emit('close');

          await nextTick();

          expect(findFrameworkInfoSidebar().props('framework')).toBe(null);
        });

        it('removes query', async () => {
          await toggleSidebar();

          await findFrameworkInfoSidebar().vm.$emit('close');

          expect($router.push).toHaveBeenCalledWith({
            query: null,
          });
        });
      });
    });
  });

  describe('actions dropdown', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it('renders dropdown with actions for each framework', () => {
      expect(findActionsDropdowns()).toHaveLength(frameworks.length);
      expect(findActionsDropdowns().at(0).props('icon')).toBe('ellipsis_v');
      expect(findActionsDropdowns().at(0).props('toggleText')).toBe(
        "Actions for Auditor's framework 1",
      );
    });

    it('dropdown has five actions', () => {
      expect(findActionsDropdownItems()).toHaveLength(5);
    });

    describe('edit action', () => {
      it('has correct text', () => {
        expect(findEditAction().text()).toBe('Edit');
      });

      it('redirects to edit framework page on action', () => {
        findEditAction().vm.$emit('click');
        expect($router.push).toHaveBeenCalledWith({
          name: ROUTE_EDIT_FRAMEWORK,
          params: { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
        });
      });
    });

    describe('set as default action', () => {
      describe('when framework is not default', () => {
        it('renders expected text', () => {
          expect(findSetAsDefaultAction().text()).toBe('Set as default');
        });

        it('shows correct tooltip', () => {
          const tooltipElement = findSetAsDefaultActionTooltip();
          expect(tooltipElement.exists()).toBe(true);
          expect(tooltipElement.text()).toBe('Set as default');
        });

        it('triggers updateDefaultFramework when clicked', async () => {
          const component = wrapper.findComponent(FrameworksTable);
          jest.spyOn(component.vm, 'updateDefaultFramework');
          await findSetAsDefaultAction().trigger('click');
          expect(component.vm.updateDefaultFramework).toHaveBeenCalledWith(
            expect.objectContaining({ isDefault: true }),
          );
        });
      });

      describe('when framework is default', () => {
        beforeEach(async () => {
          const defaultFramework = createFramework({ isDefault: true });

          wrapper = createComponent({
            frameworks: [defaultFramework],
            isLoading: false,
          });

          await nextTick();
        });

        it('renders expected text', () => {
          expect(findSetAsDefaultAction().text()).toBe('Remove as default');
        });

        it('shows correct tooltip', () => {
          const tooltipElement = findSetAsDefaultActionTooltip();
          expect(tooltipElement.exists()).toBe(true);
          expect(tooltipElement.text()).toBe('Remove as default');
        });
      });
    });

    describe('delete action', () => {
      it('renders expected text', () => {
        expect(findDeleteAction().text()).toBe('Delete');
      });

      it('shows delete modal on action', () => {
        findDeleteAction().vm.$emit('click');
        expect(modalStub.show).toHaveBeenCalled();
        findDeleteModal().vm.$emit('delete');
        expect(wrapper.emitted('delete-framework')).toEqual([[frameworks[rowCheckIndex].id]]);
      });

      it('disables delete action and shows correct tooltip when framework is default', async () => {
        const defaultFramework = createFramework();
        wrapper = createComponent({
          frameworks: [defaultFramework],
          isLoading: false,
        });

        await nextTick();
        expect(findDeleteAction().props('disabled')).toBe(true);

        const tooltip = getBinding(findDeleteActionTooltip().element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
        expect(findDeleteActionTooltip().attributes('title')).toBe(
          "Compliance frameworks that are linked to an active policy can't be deleted",
        );
      });

      it('disables delete action and shows correct tooltip when framework has linked policies', async () => {
        const frameworkWithPolicies = createFramework();
        wrapper = createComponent({
          frameworks: [frameworkWithPolicies],
          isLoading: false,
        });

        await nextTick();

        expect(findDeleteAction().props('disabled')).toBe(true);

        const tooltip = getBinding(findDeleteActionTooltip().element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
        expect(findDeleteActionTooltip().attributes('title')).toBe(
          "Compliance frameworks that are linked to an active policy can't be deleted",
        );
      });

      it('enables delete action when framework is not default and has no linked policies', async () => {
        const frameworkWithoutPolicies = createFramework({
          options: {
            securityPolicies: { nodes: [] },
          },
        });
        wrapper = createComponent({
          frameworks: [frameworkWithoutPolicies],
          isLoading: false,
        });

        await nextTick();

        expect(findDeleteAction().props('disabled')).toBe(false);
        expect(findDeleteActionTooltip().attributes('title')).toBe('');
      });
    });

    describe('copy id action', () => {
      let dropdownStub;
      let closeAndFocusSpy;

      beforeEach(() => {
        closeAndFocusSpy = jest.fn();
        dropdownStub = {
          template: '<div><slot></slot></div>',
          methods: {
            closeAndFocus: closeAndFocusSpy,
          },
        };

        wrapper = createComponent(
          {
            frameworks,
            isLoading: false,
          },
          {},
          {
            stubs: {
              GlDisclosureDropdown: dropdownStub,
            },
          },
        );
      });

      it('has expected text', () => {
        expect(findCopyIdAction().text()).toBe('Copy ID: 1');
      });

      it('renders help text', () => {
        const tooltip = getBinding(findCopyIdAction().element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
        expect(findCopyIdAction().attributes('title')).toBe(
          'Use the compliance framework ID in configuration or API requests.',
        );
      });

      it('copies id to clipboard, shows toast, and closes dropdown on action', async () => {
        await findCopyIdAction().vm.$emit('click');
        await waitForPromises();

        expect(copyToClipboard).toHaveBeenCalledWith('1');
        expect($toast.show).toHaveBeenCalledWith('Framework ID copied to clipboard.');
        expect(closeAndFocusSpy).toHaveBeenCalled();
      });
    });
  });

  describe('framework badge', () => {
    it('sets popover mode to edit in top-level group', () => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });

      expect(findBadge().props('popoverMode')).toBe('edit');
    });

    it('sets popover mode to details in subgroup', () => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
        groupPath: SUBGROUP_PATH,
      });

      expect(findBadge().props('popoverMode')).toBe('details');
    });
  });

  describe('when opened in a subgroup', () => {
    const subgroupFrameworksResponse = createComplianceFrameworksReportResponse({
      count: 2,
      projects: 2,
      groupPath: GROUP_PATH,
    });
    const subgroupFrameworks = subgroupFrameworksResponse.data.namespace.complianceFrameworks.nodes;
    const subgroupProjects = subgroupFrameworks[0].projects.nodes;
    subgroupProjects[1].fullPath = `${SUBGROUP_PATH}/project1`;

    beforeEach(() => {
      wrapper = createComponent({
        groupPath: SUBGROUP_PATH,
        frameworks: subgroupFrameworks,
        isLoading: false,
      });
    });

    it('does not render associated projects column in subgroup', () => {
      expect(findTableHeaders().wrappers.map((w) => w.text())).not.toContain('Associated projects');
    });

    it('renders only copy id action in action dropdown', () => {
      expect(findActionsDropdownItems()).toHaveLength(1);
      expect(findActionsDropdownItems().at(0).text()).toBe('Copy ID: 1');
    });

    it('sets framework badge popover mode to details', () => {
      expect(findBadge().props('popoverMode')).toBe('details');
    });
  });

  describe('exportFramework', () => {
    const mockFrameworkId = '123';
    const expectedUrl = '/groups/group-path/-/security/compliance_frameworks/123.json';
    let locationMock;
    let dropdownStub;
    let closeAndFocusSpy;

    beforeEach(() => {
      dropdownStub = {
        template: '<div><slot></slot></div>',
        methods: {
          closeAndFocus: jest.fn(),
        },
      };

      closeAndFocusSpy = dropdownStub.methods.closeAndFocus;

      locationMock = {
        href: 'http://test.host/',
      };

      jest.spyOn(window, 'location', 'get').mockImplementation(() => locationMock);

      wrapper = createComponent(
        {
          groupPath: 'group-path',
        },
        {},
        {
          GlDisclosureDropdown: dropdownStub,
        },
      );

      jest.clearAllMocks();
    });

    it('redirects to framework export URL when export succeeds', async () => {
      const framework = { id: mockFrameworkId };
      const resolvedRoute = { href: expectedUrl };

      $router.resolve = jest.fn().mockReturnValue(resolvedRoute);

      await wrapper.vm.exportFramework(framework);

      expect($router.resolve).toHaveBeenCalledWith({
        name: ROUTE_EXPORT_FRAMEWORK,
        params: { id: getIdFromGraphQLId(mockFrameworkId) },
      });
      expect(locationMock.href).toBe(expectedUrl);
    });

    it('shows error toast when export fails', async () => {
      const error = new Error('Export failed');
      const toastSpy = jest.spyOn(wrapper.vm.$toast, 'show');

      $router.resolve = jest.fn().mockImplementation(() => {
        throw error;
      });

      await wrapper.vm.exportFramework({ id: mockFrameworkId });

      expect(toastSpy).toHaveBeenCalledWith('Failed to export framework');
    });

    it('does not close dropdown if export fails', async () => {
      $router.resolve = jest.fn().mockImplementation(() => {
        throw new Error('Failed to resolve route');
      });

      await wrapper.vm.exportFramework({ id: mockFrameworkId });
      await nextTick();

      expect(closeAndFocusSpy).not.toHaveBeenCalled();
    });
  });

  describe('setAsDefaultFramework', () => {
    let mutationResolver;
    let apolloProvider;

    beforeEach(() => {
      mutationResolver = jest.fn().mockResolvedValue({
        data: {
          updateComplianceFramework: {
            errors: [],
            clientMutationId: 'test-id',
            complianceFramework: {
              id: 'gid://gitlab/ComplianceFramework/1',
              name: 'Test Framework',
              description: 'Test Description',
              color: '#FF0000',
              pipelineConfigurationFullPath: '/path/to/pipeline',
              projects: {
                nodes: [
                  {
                    id: 'gid://gitlab/Project/1',
                    name: 'Test Project',
                    fullPath: 'test-project',
                    visibility: 'public',
                    webUrl: 'https://gitlab.com/test-project',
                    description: 'Test Description',
                    namespace: {
                      id: 'gid://gitlab/Group/1',
                      name: 'Test Group',
                      fullName: 'Test Group',
                      webUrl: 'https://gitlab.com/test-group',
                    },
                  },
                ],
              },
            },
          },
        },
      });

      const mockApolloClient = createMockClient([
        [updateComplianceFrameworkMutation, mutationResolver],
      ]);

      apolloProvider = createApolloProvider({
        defaultClient: mockApolloClient,
      });

      wrapper = createComponent(
        {
          frameworks,
          isLoading: false,
        },
        {},
        { apolloProvider },
      );
    });

    it.each([
      {
        isDefault: true,
        expectedMessage: 'Default framework set successfully',
      },
      {
        isDefault: false,
        expectedMessage: 'Default framework removed successfully',
      },
    ])(
      'handles setting framework default status to $isDefault',
      async ({ isDefault, expectedMessage }) => {
        const framework = { id: 'gid://gitlab/ComplianceFramework/1' };

        await wrapper.vm.updateDefaultFramework({ framework, isDefault });

        expect(mutationResolver).toHaveBeenCalledWith(
          expect.objectContaining({
            input: {
              id: framework.id,
              params: {
                default: isDefault,
              },
            },
          }),
        );
        expect(wrapper.emitted('update-frameworks')).toHaveLength(1);
        expect($toast.show).toHaveBeenCalledWith(expectedMessage);
      },
    );

    it('shows error toast and logs to Sentry when mutation fails', async () => {
      const framework = { id: 'gid://gitlab/ComplianceFramework/1' };
      const error = new Error('GraphQL error');
      jest.spyOn(Sentry, 'captureException');
      mutationResolver.mockRejectedValueOnce(error);

      await wrapper.vm.updateDefaultFramework({ framework, isDefault: true });

      expect(wrapper.emitted('update-frameworks')).toBeUndefined();
      expect($toast.show).toHaveBeenCalledWith('Failed to set default framework');
      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        tags: {
          vue_component: 'frameworks_table',
        },
      });
    });

    it('shows error toast and logs to Sentry when mutation returns errors', async () => {
      const framework = { id: 'gid://gitlab/ComplianceFramework/1' };
      const mutationError = 'Something went wrong';
      jest.spyOn(Sentry, 'captureException');
      mutationResolver.mockResolvedValueOnce({
        data: {
          updateComplianceFramework: {
            errors: [mutationError],
            clientMutationId: 'test-id',
            complianceFramework: null,
          },
        },
      });

      await wrapper.vm.updateDefaultFramework({ framework, isDefault: true });

      expect(wrapper.emitted('update-frameworks')).toBeUndefined();
      expect($toast.show).toHaveBeenCalledWith('Failed to set default framework');
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error(mutationError), {
        tags: {
          vue_component: 'frameworks_table',
        },
      });
    });
  });

  describe('CSP framework behavior', () => {
    describe('source column', () => {
      beforeEach(() => {
        const inheritedFrameworks = [
          createFramework({
            id: 1,
            options: { namespaceId: 'gid://gitlab/Types::Namespace/456' }, // Different namespace
          }),
          createFramework({
            id: 2,
            options: { namespaceId: 'gid://gitlab/Types::Namespace/123' }, // Same namespace
          }),
        ];

        wrapper = createComponent({
          frameworks: inheritedFrameworks,
          isLoading: false,
          namespaceId: 'gid://gitlab/Group/123', // Current namespace
        });
      });

      it('shows "CSP Group" for inherited frameworks', () => {
        const sourceCell = findTableRowData(0).at(1);
        expect(sourceCell.text()).toBe('CSP group');
      });

      it('shows "This group" for non-inherited frameworks', () => {
        const sourceCell = findTableRowData(1).at(1);
        expect(sourceCell.text()).toBe('This group');
      });

      it('includes source column in table headers', () => {
        const headerTexts = findTableHeaders().wrappers.map((h) => h.text());
        expect(headerTexts).toContain('Source');
      });
    });

    describe('disabled actions for inherited frameworks', () => {
      beforeEach(() => {
        const inheritedFramework = createFramework({
          id: 1,
          options: {
            namespaceId: 'gid://gitlab/Types::Namespace/456',
            securityPolicies: { nodes: [] },
            default: false,
          },
        });

        wrapper = createComponent({
          frameworks: [inheritedFramework],
          isLoading: false,
          namespaceId: 'gid://gitlab/Group/123',
        });
      });

      it('disables delete action for inherited frameworks', () => {
        expect(findDeleteAction().props('disabled')).toBe(true);
      });

      it('shows tooltip for inherited frameworks', () => {
        const tooltip = getBinding(findDeleteActionTooltip().element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
      });

      it('disables the set as default button', () => {
        const setAsDefaultButton = wrapper.find('[data-testid="action-set-as-default"]');

        expect(setAsDefaultButton.attributes('aria-disabled')).toBe('true');
      });
    });

    describe('framework badge showDefault behavior', () => {
      beforeEach(() => {
        const frameworksWithDefaults = [
          createFramework({
            id: 1,
            isDefault: true,
            options: { namespaceId: 'gid://gitlab/Types::Namespace/456' },
          }),
          createFramework({
            id: 2,
            isDefault: true,
            options: { namespaceId: 'gid://gitlab/Types::Namespace/123' },
          }),
        ];

        wrapper = createComponent({
          frameworks: frameworksWithDefaults,
          isLoading: false,
          namespaceId: 'gid://gitlab/Group/123',
        });
      });

      it('hides default badge for inherited frameworks', () => {
        const firstBadge = findTableRowData(0).at(0).findComponent(FrameworkBadge);
        expect(firstBadge.props('showDefault')).toBe(false);
      });

      it('shows default badge for non-inherited frameworks', () => {
        const secondBadge = findTableRowData(1).at(0).findComponent(FrameworkBadge);
        expect(secondBadge.props('showDefault')).toBe(true);
      });
    });

    describe('shouldDisableDeleteAction method', () => {
      it('returns true for inherited frameworks even when not default and no policies', () => {
        const inheritedFramework = createFramework({
          options: {
            namespaceId: 'gid://gitlab/Types::Namespace/456',
            default: false,
            securityPolicies: { nodes: [] },
          },
        });

        wrapper = createComponent({
          frameworks: [inheritedFramework],
          isLoading: false,
          namespaceId: 'gid://gitlab/Group/123',
        });

        expect(wrapper.vm.shouldDisableDeleteAction(inheritedFramework)).toBe(true);
      });

      it('returns false for non-inherited frameworks when not default and no policies', () => {
        const nonInheritedFramework = createFramework({
          options: {
            namespaceId: 'gid://gitlab/Types::Namespace/123',
            default: false,
            securityPolicies: { nodes: [] },
          },
        });

        wrapper = createComponent({
          frameworks: [nonInheritedFramework],
          isLoading: false,
          namespaceId: 'gid://gitlab/Group/123',
        });

        expect(wrapper.vm.shouldDisableDeleteAction(nonInheritedFramework)).toBe(false);
      });
    });
  });
});
