import {
  GlFormCheckbox,
  GlLabel,
  GlLoadingIcon,
  GlTable,
  GlModal,
  GlAlert,
  GlLink,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import CreateForm from 'ee/groups/settings/compliance_frameworks/components/create_form.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import { DOCS_URL } from '~/constants';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

import {
  createComplianceFrameworksResponse,
  createProjectUpdateComplianceFrameworksResponse,
  createComplianceFrameworksReportResponse,
} from 'ee_jest/compliance_dashboard/mock_data';
import FrameworkSelectionBox from 'ee/compliance_dashboard/components/projects_report/framework_selection_box.vue';
import ProjectsTable from 'ee/compliance_dashboard/components/projects_report/projects_table.vue';
import SelectionOperations from 'ee/compliance_dashboard/components/projects_report/selection_operations.vue';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';
import getComplianceFrameworksCompactQuery from 'ee/compliance_dashboard/components/projects_report/graphql/get_compliance_frameworks_compact.query.graphql';

import { mapProjects } from 'ee/compliance_dashboard/graphql/mappers';

import updateComplianceFrameworksMutation from 'ee/compliance_dashboard/graphql/mutations/project_update_compliance_frameworks.graphql';

Vue.use(VueApollo);

describe('ProjectsTable component', () => {
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  let apolloProvider;
  let updateComplianceFrameworkMockResponse;
  let toastMock;

  const GlModalStub = stubComponent(GlModal, { methods: { show: jest.fn(), hide: jest.fn() } });

  const groupPath = 'group-path';
  const subgroupPath = 'group-path/child';
  const rootAncestor = {
    path: 'group-path',
    name: 'Root Ancestor',
    complianceCenterPath: 'group-path/compliance_dashboard',
  };
  const hasFilters = false;

  const COMPLIANCE_FRAMEWORK_COLUMN_IDX = 3;
  const ACTION_COLUMN_IDX = 4;
  const ROW_WITH_FRAMEWORK_IDX = 0;
  const ROW_WITHOUT_FRAMEWORK_IDX = 1;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableHeaders = () => findTable().findAll('th > div > span');
  const findTableRowData = (idx) => findTable().findAll('tbody > tr').at(idx).findAll('td');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findByTestId('projects-table-empty-state');

  const findModalByModalId = (modalId) =>
    wrapper.findAllComponents(GlModal).wrappers.find((w) => w.props('modalId') === modalId);

  const findCreateModal = () => findModalByModalId('create-framework-form-modal');
  const findNoFrameworksAlert = () => wrapper.findComponent(GlAlert);

  const findSelectAllCheckbox = () =>
    findTable().findAll('th > div').at(0).findComponent(GlFormCheckbox);
  const findSelectedRows = () => findTable().findAll('.b-table-row-selected');

  const selectRow = (index) => findTableRowData(index).at(0).trigger('click');
  const getMockFrameworksGraphQl = (count = 2) =>
    jest.fn().mockResolvedValue(createComplianceFrameworksReportResponse({ count, projects: 2 }));
  const createComponent = (
    props = {},
    mockFrameworksGraphQlResponse = getMockFrameworksGraphQl(),
    provide = {},
  ) => {
    updateComplianceFrameworkMockResponse = jest
      .fn()
      .mockResolvedValue(createProjectUpdateComplianceFrameworksResponse());

    apolloProvider = createMockApollo([
      [updateComplianceFrameworksMutation, updateComplianceFrameworkMockResponse],
      [getComplianceFrameworksCompactQuery, mockFrameworksGraphQlResponse],
    ]);

    toastMock = { show: jest.fn() };
    return mountExtended(ProjectsTable, {
      apolloProvider,
      propsData: {
        groupPath,
        rootAncestor,
        hasFilters,
        ...props,
      },
      provide: {
        canAdminComplianceFrameworks: true,
        ...provide,
      },
      stubs: {
        FrameworkSelectionBox: stubComponent(FrameworkSelectionBox, {
          template: '<div>add-framework-stub</div>',
        }),
        CreateForm: true,
        EditForm: true,
        GlModal: GlModalStub,
      },
      mocks: {
        $toast: toastMock,
      },
      attachTo: document.body,
    });
  };

  describe('default behavior', () => {
    it('renders the loading indicator while loading', () => {
      wrapper = createComponent({ projects: [], isLoading: true });

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTable().text()).not.toContain('No projects found');
    });

    it('renders the empty state when no projects found', () => {
      wrapper = createComponent({ projects: [], isLoading: false });

      const emptyState = findEmptyState();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.text()).toBe('No projects found');
    });

    it('has the correct table headers', () => {
      wrapper = createComponent({ projects: [], isLoading: false });
      const headerTexts = findTableHeaders().wrappers.map((h) => h.text());

      expect(headerTexts).toStrictEqual([
        'Project name',
        'Project path',
        'Compliance frameworks',
        'Action',
      ]);
    });
  });

  describe('when filters are applied and no projects are found', () => {
    it('renders the empty state with updated text', () => {
      wrapper = createComponent({ projects: [], isLoading: false, hasFilters: true });

      const emptyState = findEmptyState();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.text()).toBe('No projects found that match filters');
    });
  });

  describe('when there are projects', () => {
    const projectsResponse = createComplianceFrameworksResponse({
      count: 3,
      groupPath,
      archivedProject: 1,
    });
    projectsResponse.data.group.projects.nodes[1].complianceFrameworks.nodes = [];

    const projects = mapProjects(projectsResponse.data.group.projects.nodes);

    beforeEach(() => {
      wrapper = createComponent({
        projects,
        isLoading: false,
      });
    });

    describe('no frameworks alert', () => {
      it('does not render alert in top level group', () => {
        expect(findNoFrameworksAlert().exists()).toBe(false);
      });

      it('renders alert with links for sub group', () => {
        const links = () => findNoFrameworksAlert().findAllComponents(GlLink);
        wrapper = createComponent(
          { projects, isLoading: false, groupPath: 'sub-group-path' },
          getMockFrameworksGraphQl(0),
        );

        expect(findNoFrameworksAlert().text()).toMatchInterpolatedText(
          'No frameworks found. Create a framework in top-level group Root Ancestor to assign it to a project. Learn more.',
        );
        expect(links().at(0).attributes('href')).toBe('group-path/compliance_dashboard');
        expect(links().at(1).attributes('href')).toBe(
          `${DOCS_URL}/user/group/compliance_frameworks.html#prerequisites`,
        );
      });

      it('does not render alert for sub group when there are frameworks', async () => {
        wrapper = await createComponent({
          projects,
          isLoading: false,
          groupPath: 'sub-group-path',
        });
        await waitForPromises();
        expect(findNoFrameworksAlert().exists()).toBe(false);
      });
    });

    describe('correctly handles select all checkbox', () => {
      it('renders select all checkbox in header', () => {
        expect(findSelectAllCheckbox().exists()).toBe(true);
      });

      it('renders empty state when no rows are selected', () => {
        expect(findSelectAllCheckbox().find('input').element.checked).toBe(false);
      });

      it('renders indeterminate state when not all rows are selected', async () => {
        await selectRow(0);

        expect(findSelectAllCheckbox().props('indeterminate')).toBe(true);
      });

      it('does not render indeterminate state when all rows are selected', async () => {
        for (let i = 0; i < projects.length; i += 1) {
          // eslint-disable-next-line no-await-in-loop
          await selectRow(i);
        }

        expect(findSelectAllCheckbox().props('indeterminate')).toBe(false);
      });

      it('renders checked state when all rows are selected', async () => {
        for (let i = 0; i < projects.length; i += 1) {
          // eslint-disable-next-line no-await-in-loop
          await selectRow(i);
        }

        expect(findSelectAllCheckbox().find('input').element.checked).toBe(true);
      });

      it('clears selection when clicking checkbox in indeterminate state', async () => {
        await selectRow(0);
        await findSelectAllCheckbox().find('label').trigger('click');

        expect(findSelectedRows()).toHaveLength(0);
      });

      it('selects all rows', async () => {
        await findSelectAllCheckbox().find('label').trigger('click');

        expect(findSelectedRows()).toHaveLength(projects.length);
      });
    });

    it('passes selection to selection operations component', async () => {
      await selectRow(0);

      expect(wrapper.findComponent(SelectionOperations).props().selection).toHaveLength(1);
      expect(wrapper.findComponent(SelectionOperations).props().selection[0]).toStrictEqual(
        projects[0],
      );
    });

    it('passes group path to selection operations component', () => {
      expect(wrapper.findComponent(SelectionOperations).props().groupPath).toBe(groupPath);
    });

    it.each(Object.keys(projects))('has the correct data for row %s', (idx) => {
      const [, projectName, projectPath, framework] = findTableRowData(idx).wrappers.map((d) =>
        d.text(),
      );
      const expectedFrameworkName = projects[idx].complianceFrameworks[0]?.name ?? 'No frameworks';

      const isProjectArchived = projects[idx].archived === true;
      if (isProjectArchived) {
        expect(projectName).toContain('Archived');
      } else {
        expect(projectName).toBe(`Project ${idx}`);
      }
      expect(projectPath).toBe(`${groupPath}/project${idx}`);
      expect(framework).toContain(expectedFrameworkName);
    });

    function itCallsUpdateFrameworksMutation(operations) {
      const isBulkAction = operations.length > 1;
      it('calls mutation', () => {
        expect(updateComplianceFrameworkMockResponse).toHaveBeenCalledTimes(operations.length);
        operations.forEach((operation) => {
          expect(updateComplianceFrameworkMockResponse).toHaveBeenCalledWith({
            projectId: operation.projectId,
            complianceFrameworkIds: operation.frameworkIds,
          });
        });
      });

      if (isBulkAction) {
        it('displays toast', async () => {
          await waitForPromises();

          expect(toastMock.show).toHaveBeenCalled();
        });
      }

      it('emits update event', async () => {
        await waitForPromises();
        expect(wrapper.emitted('updated')).toHaveLength(1);
      });

      it('tracks update_compliance_framework event', async () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        await waitForPromises();
        expect(trackEventSpy).toHaveBeenCalledWith(
          'apply_compliance_framework',
          {
            property: operations.map((operation) => operation.projectId).join(','),
          },
          undefined,
        );
      });

      if (isBulkAction) {
        it('clicking undo in toast reverts changes', async () => {
          await waitForPromises();
          toastMock.show.mock.calls[0][1].action.onClick();

          expect(updateComplianceFrameworkMockResponse).toHaveBeenCalledTimes(
            operations.length * 2,
          );
          const expectedCalls = [
            ...operations.map((operation) => ({
              complianceFrameworkIds: operation.frameworkIds,
              projectId: operation.projectId,
            })),
            ...operations.map((operation) => ({
              complianceFrameworkIds: operation.previousFrameworkIds,
              projectId: operation.projectId,
            })),
          ];

          expectedCalls.forEach((expectedCall) => {
            expect(updateComplianceFrameworkMockResponse).toHaveBeenCalledWith(
              expect.objectContaining(expectedCall),
            );
          });
        });
      }
    }

    describe('when selection operations component emits change event', () => {
      const operations = [
        {
          projectId: 'someId',
          frameworkIds: ['framework-id'],
          previousFrameworkIds: ['previous-framework-id'],
        },
        {
          projectId: 'someId-2',
          frameworkIds: ['framework-id', 'framework-id-2'],
          previousFrameworkIds: ['framework-id'],
        },
      ];

      beforeEach(() => {
        wrapper.findComponent(SelectionOperations).vm.$emit('change', operations);
      });

      itCallsUpdateFrameworksMutation(operations);
    });

    describe('when clicking close sign of framework badge', () => {
      const frameworkId = 'framework-to-remove';
      beforeEach(() => {
        findTableRowData(0)
          .at(COMPLIANCE_FRAMEWORK_COLUMN_IDX)
          .findComponent(GlLabel)
          .vm.$emit('close', frameworkId);
      });

      itCallsUpdateFrameworksMutation([
        {
          projectId: projects[ROW_WITH_FRAMEWORK_IDX].id,
          frameworkIds: [],
          previousFrameworkIds: projects[ROW_WITH_FRAMEWORK_IDX].complianceFrameworks.map(
            (f) => f.id,
          ),
        },
      ]);

      it('renders loading indicator while loading', () => {
        expect(
          findTableRowData(ROW_WITH_FRAMEWORK_IDX)
            .at(COMPLIANCE_FRAMEWORK_COLUMN_IDX)
            .findComponent(GlLoadingIcon)
            .exists(),
        ).toBe(true);
      });
    });

    describe('when new framework requested from framework selection', () => {
      beforeEach(() => {
        findTableRowData(ROW_WITHOUT_FRAMEWORK_IDX)
          .at(ACTION_COLUMN_IDX)
          .findComponent(FrameworkSelectionBox)
          .vm.$emit('create');
      });

      it('opens create modal', () => {
        expect(GlModalStub.methods.show).toHaveBeenCalled();
      });

      it('when create modal successfully creates framework calls mutation on selected project', () => {
        const NEW_FRAMEWORK = { id: 'new-framework-id' };

        findCreateModal()
          .findComponent(CreateForm)
          .vm.$emit('success', { framework: NEW_FRAMEWORK });

        expect(updateComplianceFrameworkMockResponse).toHaveBeenCalledTimes(1);
        expect(updateComplianceFrameworkMockResponse).toHaveBeenCalledWith({
          projectId: projects[ROW_WITHOUT_FRAMEWORK_IDX].id,
          complianceFrameworkIds: [NEW_FRAMEWORK.id],
        });
      });

      it('closes modal on cancel', () => {
        findCreateModal().findComponent(CreateForm).vm.$emit('cancel');

        expect(GlModalStub.methods.hide).toHaveBeenCalled();
      });
    });

    describe('when add framework selection is made', () => {
      const NEW_FRAMEWORK_ID = 'new-framework-id';

      beforeEach(() => {
        findTableRowData(ROW_WITHOUT_FRAMEWORK_IDX)
          .at(ACTION_COLUMN_IDX)
          .findComponent(FrameworkSelectionBox)
          .vm.$emit('update', [NEW_FRAMEWORK_ID]);
      });

      itCallsUpdateFrameworksMutation([
        {
          projectId: projects[ROW_WITHOUT_FRAMEWORK_IDX].id,
          frameworkIds: [NEW_FRAMEWORK_ID],
          previousFrameworkIds: [],
        },
      ]);

      it('renders loading indicator while loading', () => {
        expect(
          findTableRowData(ROW_WITHOUT_FRAMEWORK_IDX)
            .at(COMPLIANCE_FRAMEWORK_COLUMN_IDX)
            .findComponent(GlLoadingIcon)
            .exists(),
        ).toBe(true);
      });
    });
  });

  describe('when used in subgroup', () => {
    const projectsResponse = createComplianceFrameworksResponse({
      count: 2,
      groupPath: subgroupPath,
    });
    const projects = mapProjects(projectsResponse.data.group.projects.nodes);

    beforeEach(() => {
      wrapper = createComponent({
        projects,
        groupPath: subgroupPath,
        isLoading: false,
      });
    });

    it('does not allow framework editing', () => {
      const badge = findTableRowData(0)
        .at(COMPLIANCE_FRAMEWORK_COLUMN_IDX)
        .findComponent(FrameworkBadge);

      expect(badge.props('popoverMode')).toBe('details');
    });

    it('does not render framework selection if no frameworks', async () => {
      wrapper = createComponent(
        { projects, isLoading: false, groupPath: subgroupPath },
        getMockFrameworksGraphQl(0),
      );
      await waitForPromises();
      expect(wrapper.findComponent(FrameworkSelectionBox).exists()).toBe(false);
    });
  });

  describe('when used in project', () => {
    const projectsResponse = createComplianceFrameworksResponse({
      count: 2,
      groupPath: subgroupPath,
    });
    const projects = mapProjects(projectsResponse.data.group.projects.nodes);

    beforeEach(() => {
      wrapper = createComponent({
        projects,
        projectPath: `${subgroupPath}/demo`,
        projectId: 37,
        groupPath: subgroupPath,
        isLoading: false,
      });
    });

    it('does not render selection operations', () => {
      expect(wrapper.findComponent(SelectionOperations).exists()).toBe(false);
    });

    it('does not render selection column', async () => {
      await waitForPromises();
      expect(findTable().props('fields')).not.toContain(
        expect.objectContaining({
          key: 'selected',
        }),
      );
    });

    it('does not allow framework edit if not allowed to admin compliance framework', () => {
      wrapper = createComponent(
        {
          projects,
          projectPath: `${subgroupPath}/demo`,
          projectId: 37,
          groupPath: subgroupPath,
          isLoading: false,
        },
        getMockFrameworksGraphQl(),
        { canAdminComplianceFrameworks: false },
      );
      // We do not render checkbox column
      const COLUMN_IDX = COMPLIANCE_FRAMEWORK_COLUMN_IDX - 1;

      const badge = findTableRowData(0).at(COLUMN_IDX).findComponent(FrameworkBadge);

      expect(badge.props('closeable')).toBe(false);
    });
  });
});
