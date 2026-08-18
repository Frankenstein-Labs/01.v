import { mount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { useFakeDate } from 'helpers/fake_date';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { getSlotFunction } from '~/lib/utils/vue3compat/normalize_render';
import WorkspacesTable from 'ee/workspaces/common/components/workspaces_list/workspaces_table.vue';
import WorkspaceActions from 'ee/workspaces/common/components/workspace_actions.vue';
import OpenWorkspaceButton from 'ee/workspaces/common/components/open_workspace_button.vue';
import WorkspaceStateIndicator from 'ee/workspaces/common/components/workspace_state_indicator.vue';
import { calculateDisplayState } from 'ee/workspaces/common/services/calculate_display_state';
import { populateWorkspacesWithProjectDetails } from 'ee/workspaces/common/services/utils';
import { WORKSPACE_DESIRED_STATES } from 'ee/workspaces/common/constants';
import {
  USER_WORKSPACES_LIST_QUERY_RESULT,
  GET_PROJECTS_DETAILS_QUERY_RESULT,
} from '../../../mock_data';

jest.mock('~/lib/logger');

Vue.use(VueApollo);

const SVG_PATH = '/assets/illustrations/empty_states/empty_workspaces.svg';

const findTable = (wrapper) => wrapper.find('[data-testid="workspaces-list"]');
const findTableRows = (wrapper) => wrapper.findAll('[data-testid="workspaces-list"] > li');
const findTableRowsAsData = (wrapper) =>
  findTableRows(wrapper).wrappers.map((x) => {
    const rowData = {
      stateIndicatorProps: {
        ...x.findComponent(WorkspaceStateIndicator).props(),
      },
      openWorkspaceButtonProps: {
        ...x.findComponent(OpenWorkspaceButton).props(),
      },
      workspaceActionsProps: {
        ...x.findComponent(WorkspaceActions).props(),
      },
      nameText: x.find('[data-testid="workspace-name"]').text(),
      createdAt: x.findComponent(TimeAgoTooltip).props().time,
    };

    return rowData;
  });
const findWorkspaceActions = (tableRow) => tableRow.findComponent(WorkspaceActions);

describe('workspaces/common/components/workspaces_list/workspaces_table.vue', () => {
  useFakeDate(2023, 4, 4, 17, 30);

  let wrapper;
  let updateWorkspaceMutationMock;
  const UpdateWorkspaceMutationStub = {
    // Vue 3-style zero-arg render; opt out of @vue/compat's legacy
    // render-function emulation, which misclassifies it.
    compatConfig: { RENDER_FUNCTION: false },
    render() {
      return getSlotFunction(this)({ update: updateWorkspaceMutationMock });
    },
  };

  const createWrapper = ({
    workspaces = populateWorkspacesWithProjectDetails(
      USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes,
      GET_PROJECTS_DETAILS_QUERY_RESULT.data.projects.nodes,
    ),
  } = {}) => {
    updateWorkspaceMutationMock = jest.fn();
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = mount(WorkspacesTable, {
      provide: {
        emptyStateSvgPath: SVG_PATH,
      },
      propsData: {
        workspaces,
      },
      stubs: {
        UpdateWorkspaceMutation: UpdateWorkspaceMutationStub,
      },
    });
  };

  const findUpdateWorkspaceMutation = () => wrapper.findComponent(UpdateWorkspaceMutationStub);

  describe('default (with nodes)', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows table when workspaces are available', () => {
      expect(findTable(wrapper).exists()).toBe(true);
    });

    it('displays user workspaces correctly', () => {
      expect(findTableRowsAsData(wrapper)).toEqual(
        populateWorkspacesWithProjectDetails(
          USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes,
          GET_PROJECTS_DETAILS_QUERY_RESULT.data.projects.nodes,
        ).map((workspace) => {
          const workspaceDisplayState = calculateDisplayState(
            workspace.actualState,
            workspace.desiredState,
          );
          return {
            nameText: workspace.name,
            createdAt: workspace.createdAt,
            workspaceActionsProps: {
              workspaceDisplayState,
            },
            openWorkspaceButtonProps: {
              workspaceDisplayState,
              workspaceUrl: workspace.url,
            },
            stateIndicatorProps: {
              workspaceDisplayState,
            },
          };
        }),
      );
    });
  });

  describe.each`
    event               | payload
    ${'update-failed'}  | ${['error message']}
    ${'update-succeed'} | ${[]}
  `('when updateWorspaceMutation triggers $event event', ({ event, payload }) => {
    it('bubbles up event', () => {
      createWrapper();

      expect(wrapper.emitted(event)).toBe(undefined);

      findUpdateWorkspaceMutation().vm.$emit(event, payload[0]);

      expect(wrapper.emitted(event)).toEqual([payload]);
    });
  });

  describe('workspace actions is clicked', () => {
    const TEST_WORKSPACE_IDX = 1;
    const TEST_DESIRED_STATE = WORKSPACE_DESIRED_STATES.terminated;
    let workspace;
    let workspaceActions;
    beforeEach(() => {
      createWrapper();
      const row = findTableRows(wrapper).at(TEST_WORKSPACE_IDX);
      workspace =
        USER_WORKSPACES_LIST_QUERY_RESULT.data.currentUser.workspaces.nodes[TEST_WORKSPACE_IDX];
      workspaceActions = findWorkspaceActions(row);

      workspaceActions.vm.$emit('click', TEST_DESIRED_STATE);
    });

    it('calls the update method provided by the WorkspaceUpdateMutation component', () => {
      expect(updateWorkspaceMutationMock).toHaveBeenCalledWith(workspace.id, {
        desiredState: TEST_DESIRED_STATE,
      });
    });
  });
});
