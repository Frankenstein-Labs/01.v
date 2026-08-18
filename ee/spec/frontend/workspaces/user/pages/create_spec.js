import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import { cloneDeep } from 'lodash-es';
import { GlForm, GlFormSelect, GlLink, GlSprintf, GlFormGroup } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';
import SearchProjectsListbox from 'ee/workspaces/user/components/search_projects_listbox.vue';
import DevfileListbox from 'ee/workspaces/user/components/devfile_listbox.vue';
import DevfileHelpDrawer from 'ee/workspaces/user/components/devfile_help_drawer.vue';
import GetProjectDetailsQuery from 'ee/workspaces/common/components/get_project_details_query.vue';
import WorkspaceVariables from 'ee/workspaces/user/components/workspace_variables.vue';
import WorkspaceCreate, { i18n } from 'ee/workspaces/user/pages/create.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  DEFAULT_DESIRED_STATE,
  ROUTES,
  WORKSPACE_VARIABLE_INPUT_TYPE_ENUM,
  WORKSPACES_LIST_PAGE_SIZE,
} from 'ee/workspaces/user/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import userWorkspacesTabListQuery from 'ee/workspaces/common/graphql/queries/user_workspaces_tab_list.query.graphql';
import workspaceCreateMutation from 'ee/workspaces/user/graphql/mutations/workspace_create.mutation.graphql';
import devfileValidateMutation from 'ee/workspaces/user/graphql/mutations/devfile_validate.mutation.graphql';
import blobContentQuery from '~/ci/pipeline_editor/graphql/queries/blob_content.query.graphql';
import {
  DEVFILE_VALIDATE_MUTATION_RESULT,
  BLOB_CONTENT_QUERY_RESULT,
  GET_PROJECT_DETAILS_QUERY_RESULT,
  USER_WORKSPACES_TAB_LIST_QUERY_RESULT,
  WORKSPACE_CREATE_MUTATION_RESULT,
  WORKSPACE_QUERY_RESULT,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/logger');
jest.mock('~/alert');

describe('workspaces/user/pages/create.vue', () => {
  const selectedProjectFixture = {
    fullPath: 'gitlab-org/gitlab',
    nameWithNamespace: 'GitLab Org / GitLab',
  };

  const selectedClusterAgentOneIDFixture = 'agents/1';
  const selectedClusterAgentTwoIDFixture = 'agents/2';
  const clusterAgentOne = {
    text: 'Agent',
    value: selectedClusterAgentOneIDFixture,
  };
  const clusterAgentTwo = {
    text: 'Agent 2',
    value: selectedClusterAgentTwoIDFixture,
  };
  const clusterAgentsFixture = [clusterAgentOne];
  const twoClusterAgentsFixture = [clusterAgentOne, clusterAgentTwo];
  const rootRefFixture = 'main';
  const GlFormSelectStub = stubComponent(GlFormSelect, {
    props: ['options'],
  });
  const mockRouter = {
    push: jest.fn(),
    currentRoute: {},
  };
  let wrapper;
  let workspaceCreateMutationHandler;
  let devfileValidateMutationHandler;
  let fetchBlobContentQueryHandler;
  let mockApollo;

  const buildMockApollo = () => {
    workspaceCreateMutationHandler = jest.fn().mockResolvedValue(WORKSPACE_CREATE_MUTATION_RESULT);
    devfileValidateMutationHandler = jest.fn().mockResolvedValue(DEVFILE_VALIDATE_MUTATION_RESULT);
    fetchBlobContentQueryHandler = jest.fn().mockResolvedValue(BLOB_CONTENT_QUERY_RESULT);

    mockApollo = createMockApollo([
      [workspaceCreateMutation, workspaceCreateMutationHandler],
      [devfileValidateMutation, devfileValidateMutationHandler],
      [blobContentQuery, fetchBlobContentQueryHandler],
    ]);
  };

  const readCachedWorkspaces = () => {
    const apolloClient = mockApollo.clients.defaultClient;
    const result = apolloClient.readQuery({
      query: userWorkspacesTabListQuery,
      variables: {
        activeBefore: null,
        activeAfter: null,
        terminatedBefore: null,
        terminatedAfter: null,
        first: WORKSPACES_LIST_PAGE_SIZE,
      },
    });

    return result?.currentUser.activeWorkspaces.nodes;
  };

  const writeCachedWorkspaces = (workspaces) => {
    const apolloClient = mockApollo.clients.defaultClient;
    apolloClient.writeQuery({
      query: userWorkspacesTabListQuery,
      variables: {
        activeBefore: null,
        activeAfter: null,
        terminatedBefore: null,
        terminatedAfter: null,
        first: WORKSPACES_LIST_PAGE_SIZE,
      },
      data: {
        currentUser: {
          ...USER_WORKSPACES_TAB_LIST_QUERY_RESULT.data.currentUser,
          activeWorkspaces: {
            nodes: workspaces,
            pageInfo:
              USER_WORKSPACES_TAB_LIST_QUERY_RESULT.data.currentUser.activeWorkspaces.pageInfo,
          },
        },
      },
    });
  };

  const createWrapper = () => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = shallowMountExtended(WorkspaceCreate, {
      apolloProvider: mockApollo,
      stubs: {
        GlFormSelect: GlFormSelectStub,
        GlSprintf,
        GlFormGroup,
      },
      provide: {
        organizationId: '1',
      },
      mocks: {
        $router: mockRouter,
      },
    });
  };

  const projectGid = GET_PROJECT_DETAILS_QUERY_RESULT.data.project.id;
  const projectId = String(getIdFromGraphQLId(projectGid));
  const findSearchProjectsListbox = () => wrapper.findComponent(SearchProjectsListbox);
  const findNoAgentsGlAlert = () => wrapper.findComponentByTestId('no-agents-alert');
  const findCreateWorkspaceErrorGlAlert = () =>
    wrapper.findComponentByTestId('create-workspace-error-alert');
  const findClusterAgentsFormGroup = () =>
    wrapper.findByTestId('workspace-cluster-agent-form-group');
  const findGetProjectDetailsQuery = () => wrapper.findComponent(GetProjectDetailsQuery);
  const findCreateWorkspaceButton = () => wrapper.findComponentByTestId('create-workspace');
  const findClusterAgentsFormSelect = () => wrapper.findComponent(GlFormSelectStub);

  const findDevfileRefField = () => wrapper.findComponentByTestId('devfile-ref');
  const findDevfileRefRefSelector = () => findDevfileRefField().findComponent(RefSelector);
  const findDevfileRefFieldParts = () => {
    const field = findDevfileRefField();
    return {
      label: field.attributes('label'),
      labelDescription: field.props('labelDescription'),
    };
  };

  const findDevfileField = () => wrapper.findByTestId('devfile');
  const findDevfileTitleText = () => findDevfileField().find('#devfile-selector-label').text();
  const findDevfileHelpIcon = () => findDevfileField().findComponent(HelpIcon);
  const findDevfileValidationDocsLink = () => wrapper.findByTestId('validation-docs');
  const findErrorPopover = () => wrapper.findByTestId('gl-error-popover');
  const findDevfileHelpPopover = () => {
    const popover = wrapper.findByTestId('gl-devfile-help-popover');
    const popoverContent = popover.findAll('p');

    return {
      popoverTextParagraph1: popoverContent.at(0).text(),
      popoverTextParagraph2: popoverContent.at(1).text(),
      popoverLinkHref: popover.findComponent(GlLink).attributes('href'),
      popoverLinkText: popover.findComponent(GlLink).text(),
    };
  };
  const findDevfileDropDown = () => findDevfileField().findComponent(DevfileListbox);
  const findDevfileHelpDrawer = () => findDevfileField().findComponent(DevfileHelpDrawer);
  const selectDevfile = (devfilePath = '.devfile.yaml') => {
    findDevfileDropDown().vm.$emit('input', devfilePath);
  };

  const emitGetProjectDetailsQueryResult = ({
    clusterAgents = [],
    groupPath = GET_PROJECT_DETAILS_QUERY_RESULT.data.project.group.fullPath,
    id = projectGid,
    rootRef = rootRefFixture,
    nameWithNamespace,
    fullPath,
  }) =>
    findGetProjectDetailsQuery().vm.$emit('result', {
      clusterAgents,
      groupPath,
      rootRef,
      id,
      nameWithNamespace,
      fullPath,
    });
  const selectProject = (project = selectedProjectFixture) =>
    findSearchProjectsListbox().vm.$emit('input', project);
  const selectClusterAgent = (selectedClusterAgentIDFixture = selectedClusterAgentOneIDFixture) =>
    findClusterAgentsFormSelect().vm.$emit('input', selectedClusterAgentIDFixture);
  const submitCreateWorkspaceForm = () =>
    wrapper.findComponent(GlForm).vm.$emit('submit', { preventDefault: jest.fn() });
  const findWorkspaceVariables = () => wrapper.findComponent(WorkspaceVariables);

  beforeEach(() => {
    buildMockApollo();
  });

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('displays a cancel button that allows navigating to the workspaces list', () => {
      expect(wrapper.findByTestId('cancel-workspace').attributes().to).toBe(ROUTES.index);
    });

    it('disables create workspace button', () => {
      expect(findCreateWorkspaceButton().props().disabled).toBe(true);
    });
  });

  describe('when a project does not have cluster agents', () => {
    beforeEach(async () => {
      createWrapper();

      await selectProject();
      await emitGetProjectDetailsQueryResult({ clusterAgents: [] });
    });

    it('displays danger alert indicating it', () => {
      expect(findNoAgentsGlAlert().props()).toMatchObject({
        title: i18n.invalidProjectAlert.title,
        variant: 'danger',
        dismissible: false,
      });
    });

    it('does not display cluster agents form select group', () => {
      expect(findClusterAgentsFormGroup().exists()).toBe(false);
    });

    it('does not display devfile ref field', () => {
      expect(findDevfileRefField().exists()).toBe(false);
    });

    it('does not display devfile path field', () => {
      expect(findDevfileField().exists()).toBe(false);
    });

    it('shows a link to the troubleshooting page', () => {
      expect(wrapper.findByTestId('workspaces-troubleshooting-doc-link').attributes('href')).toBe(
        '/help/user/workspace/workspaces_troubleshooting.html',
      );
    });
  });

  describe('when a project has cluster agents', () => {
    beforeEach(async () => {
      createWrapper();

      await selectProject();
      await emitGetProjectDetailsQueryResult({ clusterAgents: clusterAgentsFixture });
    });

    it('does not display danger alert', () => {
      expect(findNoAgentsGlAlert().exists()).toBe(false);
    });

    it('displays cluster agents form select group', () => {
      expect(findClusterAgentsFormGroup().exists()).toBe(true);
    });

    it('populates cluster agents form select with cluster agents', () => {
      expect(findClusterAgentsFormSelect().props().options).toBe(clusterAgentsFixture);
    });
  });

  describe('when a project and a cluster agent are selected', () => {
    beforeEach(async () => {
      createWrapper();

      await selectProject();
      await emitGetProjectDetailsQueryResult({
        clusterAgents: twoClusterAgentsFixture,
      });
      await selectClusterAgent();
      wrapper.findComponent(DevfileListbox).vm.$emit('input', 'default_devfile');
    });

    it('enables create workspace button', () => {
      expect(findCreateWorkspaceButton().props().disabled).toBe(false);
    });

    it('populates devfile ref selector with project ID', () => {
      expect(findDevfileRefRefSelector().props().projectId).toBe(projectId);
    });

    describe('devfile ref field', () => {
      it('renders parts', () => {
        expect(findDevfileRefFieldParts()).toEqual({
          label: 'Project reference',
          labelDescription: 'The source branch, tag, or commit hash of your workspace.',
        });
      });

      describe('when gitRef is provided in a route', () => {
        beforeEach(async () => {
          mockRouter.currentRoute.query = { gitRef: 'v1.0.0' };
          createWrapper();

          await selectProject();
          await emitGetProjectDetailsQueryResult({
            clusterAgents: twoClusterAgentsFixture,
          });
          await selectClusterAgent();
        });

        it('obtains initial ref from the router', () => {
          expect(findDevfileRefRefSelector().props().value).toBe('v1.0.0');
        });
      });
    });

    describe('when selecting a different cluster agent', () => {
      beforeEach(async () => {
        await selectClusterAgent(selectedClusterAgentTwoIDFixture);
      });

      it('submits workspaceCreate mutation with correct data', async () => {
        const devfileRef = 'mybranch';
        findDevfileRefRefSelector().vm.$emit('input', devfileRef);

        await nextTick();
        await submitCreateWorkspaceForm();

        expect(workspaceCreateMutationHandler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            clusterAgentId: selectedClusterAgentTwoIDFixture,
          }),
        });
      });
    });

    it('renders correct title text', () => {
      expect(findDevfileTitleText()).toBe('Devfile');
    });

    it('renders help icon', () => {
      expect(findDevfileHelpIcon().exists()).toBe(true);
    });

    it('renders popover', () => {
      expect(findDevfileHelpPopover()).toEqual({
        popoverTextParagraph1:
          'A devfile defines the development environment for a GitLab project. A workspace must have a valid devfile in the Git reference you use.',
        popoverTextParagraph2:
          'If your devfile is not in the root directory of your project, specify a relative path.',
        popoverLinkHref: '/help/user/workspace/_index.md#devfile',
        popoverLinkText: 'Learn more.',
      });
    });

    it('renders devfile dropdown component', () => {
      expect(findDevfileDropDown().props()).toMatchObject({
        projectPath: 'gitlab-org/gitlab',
        devfileRef: 'v1.0.0',
      });
    });

    it('renders devfile help drawer component', () => {
      expect(findDevfileHelpDrawer().exists()).toBe(true);
    });

    it('renders workspace variables component', () => {
      expect(findWorkspaceVariables().props()).toMatchObject({
        variables: [],
        showValidations: false,
      });
    });

    describe('when devfile is null', () => {
      beforeEach(async () => {
        fetchBlobContentQueryHandler.mockResolvedValueOnce({
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              repository: { blobs: { nodes: [{ id: 'blob-1', rawBlob: '' }] } },
            },
          },
        });
        selectDevfile();
        await waitForPromises();
      });

      it('displays error popover', () => {
        expect(findErrorPopover().attributes('title')).toBe('Error processing the Devfile.');
        expect(findErrorPopover().text()).toBe("Devfile can't be empty.");
        expect(findCreateWorkspaceButton().props().loading).toBe(false);
      });

      it("doesn't call the validation mutation", () => {
        expect(devfileValidateMutationHandler).not.toHaveBeenCalled();
      });
    });

    describe('when devfile validation is invalid', () => {
      it('displays error popover with single error in devfile', async () => {
        devfileValidateMutationHandler.mockResolvedValueOnce({
          data: {
            devfileValidate: {
              valid: false,
              errors: ['Some devfile error message'],
            },
          },
        });
        selectDevfile();
        await waitForPromises();

        expect(findErrorPopover().attributes('title')).toBe('Error processing the Devfile.');
        expect(findErrorPopover().text()).toBe('Some devfile error message');
        expect(findCreateWorkspaceButton().props().loading).toBe(false);
      });

      it('displays error popover with multiple errors in devfile', async () => {
        devfileValidateMutationHandler.mockResolvedValueOnce({
          data: {
            devfileValidate: {
              valid: false,
              errors: ['Some devfile error message', 'A different devfile error message'],
            },
          },
        });
        selectDevfile();
        await waitForPromises();

        expect(findErrorPopover().attributes('title')).toBe('2 errors processing the Devfile.');
        expect(findErrorPopover().text()).toContain('Some devfile error message');
        expect(findErrorPopover().text()).toContain('A different devfile error message');
        expect(findCreateWorkspaceButton().props().loading).toBe(false);
      });

      it('displays a link to the validation docs', async () => {
        devfileValidateMutationHandler.mockResolvedValueOnce({
          data: {
            devfileValidate: {
              valid: false,
              errors: ['Some devfile error message'],
            },
          },
        });
        selectDevfile();
        await waitForPromises();
        expect(findDevfileValidationDocsLink().attributes('href')).toBe(
          '/help/user/workspace/_index.md#validation-rules',
        );
      });

      it('alerts indicating system error while attempting to validate a devfile', async () => {
        devfileValidateMutationHandler.mockRejectedValueOnce(new Error());
        selectDevfile();
        await waitForPromises();

        expect(findCreateWorkspaceErrorGlAlert().text()).toContain(
          'Encountered error while attempting to validate the Devfile.',
        );
      });
    });

    describe('when selecting a project again', () => {
      beforeEach(async () => {
        await selectProject({ nameWithNamespace: 'New Project', fullPath: 'new-project' });
      });

      it('cleans the selected cluster agent', () => {
        expect(findClusterAgentsFormGroup().exists()).toBe(false);
      });
    });

    describe('when clicking Create Workspace button', () => {
      it('submits workspaceCreate mutation', async () => {
        const devfileRef = 'mybranch';
        findDevfileRefRefSelector().vm.$emit('input', devfileRef);
        await waitForPromises();
        await nextTick();
        await submitCreateWorkspaceForm();

        expect(workspaceCreateMutationHandler).toHaveBeenCalledWith({
          input: {
            clusterAgentId: selectedClusterAgentOneIDFixture,
            projectId: projectGid,
            desiredState: DEFAULT_DESIRED_STATE,
            devfilePath: null,
            devfileRef,
            variables: findWorkspaceVariables().props().variables,
          },
        });
      });

      it('sets Create Workspace button as loading', async () => {
        await submitCreateWorkspaceForm();

        expect(findCreateWorkspaceButton().props().loading).toBe(true);
      });

      it('displays workspace variables validations', async () => {
        expect(findWorkspaceVariables().props().showValidations).toBe(false);

        await submitCreateWorkspaceForm();

        expect(findWorkspaceVariables().props().showValidations).toBe(true);
      });

      describe('when workspace variables are not valid', () => {
        it('does not submit the Create Workspace mutation', async () => {
          const variables = [
            {
              key: '',
              value: '',
              variableType: WORKSPACE_VARIABLE_INPUT_TYPE_ENUM.env,
              valid: false,
            },
          ];

          await findWorkspaceVariables().vm.$emit('input', variables);

          await submitCreateWorkspaceForm();

          expect(workspaceCreateMutationHandler).not.toHaveBeenCalled();
        });
      });

      describe('when the workspaceCreate mutation succeeds', () => {
        it('when workspaces are not previously cached, does not update cache', async () => {
          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(readCachedWorkspaces()).toBeUndefined();
        });

        it('when workspaces are previously cached, updates cache', async () => {
          const originalWorkspace = WORKSPACE_QUERY_RESULT.data.workspace;

          writeCachedWorkspaces([originalWorkspace]);

          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(readCachedWorkspaces()).toEqual([
            WORKSPACE_CREATE_MUTATION_RESULT.data.workspaceCreate.workspace,
            originalWorkspace,
          ]);
        });

        it('redirects the user to the workspaces list', async () => {
          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(mockRouter.push).toHaveBeenCalledWith(ROUTES.index);
        });
      });

      describe('when the workspaceCreate mutation returns an error response', () => {
        it('displays an alert that contains the error response', async () => {
          const customMutationResponse = cloneDeep(WORKSPACE_CREATE_MUTATION_RESULT);
          const error = 'error response';

          customMutationResponse.data.workspaceCreate.workspace = null;
          customMutationResponse.data.workspaceCreate.errors.push(error);

          workspaceCreateMutationHandler.mockReset();
          workspaceCreateMutationHandler.mockResolvedValueOnce(customMutationResponse);

          await submitCreateWorkspaceForm();
          await waitForPromises();

          expect(findCreateWorkspaceErrorGlAlert().text()).toContain(error);
        });
      });

      describe('when the workspaceCreate mutation fails', () => {
        beforeEach(async () => {
          workspaceCreateMutationHandler.mockReset();
          workspaceCreateMutationHandler.mockRejectedValueOnce(new Error());

          await submitCreateWorkspaceForm();
          await waitForPromises();
        });

        it('logs error', () => {
          expect(logError).toHaveBeenCalled();
        });

        it('sets Create Workspace button as not loading', () => {
          expect(findCreateWorkspaceButton().props().loading).toBe(false);
        });

        it('displays alert indicating that creating a workspace failed', () => {
          expect(findCreateWorkspaceErrorGlAlert().text()).toContain(
            i18n.createWorkspaceFailedMessage,
          );
        });

        describe('when dismissing the create workspace error alert', () => {
          it('hides the workspace error alert', async () => {
            findCreateWorkspaceErrorGlAlert().vm.$emit('dismiss');
            await nextTick();

            expect(findCreateWorkspaceErrorGlAlert().exists()).toBe(false);
          });
        });
      });
    });
  });

  describe('when fetching project details fails', () => {
    beforeEach(() => {
      createWrapper();

      wrapper.findComponent(GetProjectDetailsQuery).vm.$emit('error');
    });

    it('displays alert indicating that fetching project details failed', () => {
      expect(createAlert).toHaveBeenCalledWith({ message: i18n.fetchProjectDetailsFailedMessage });
    });
  });

  describe('when selecting a project via URL', () => {
    const projectQueryParam = 'project';

    beforeEach(() => {
      mockRouter.currentRoute.query = { project: projectQueryParam };
      createWrapper();
    });

    it('fetches project details for the project specified in the URL', () => {
      expect(findGetProjectDetailsQuery().props().projectFullPath).toBe(projectQueryParam);
    });
  });

  describe('when receiving project details without a selected project', () => {
    it('populates the selected project with the data provided by the project details', async () => {
      const nameWithNamespace = 'project - new-project';
      const fullPath = 'project/new-project';

      createWrapper();

      emitGetProjectDetailsQueryResult({ nameWithNamespace, fullPath });

      await nextTick();

      expect(findSearchProjectsListbox().props().value).toEqual({ nameWithNamespace, fullPath });
    });
  });
});
