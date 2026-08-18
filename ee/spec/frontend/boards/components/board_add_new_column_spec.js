import {
  GlAvatarLabeled,
  GlFormRadio,
  GlFormRadioGroup,
  GlCollapsibleListbox,
  GlButton,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import { unionBy } from 'lodash-es';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BoardAddNewColumn, { listTypeInfo } from 'ee/boards/components/board_add_new_column.vue';
import projectBoardMilestonesQuery from '~/boards/graphql/project_board_milestones.query.graphql';
import searchIterationQuery from 'ee/work_items/list/graphql/search_iterations.query.graphql';
import createBoardListMutation from 'ee_else_ce/boards/graphql/board_list_create.mutation.graphql';
import boardLabelsQuery from '~/boards/graphql/board_labels.query.graphql';
import usersAutocompleteQuery from '~/graphql_shared/queries/users_autocomplete.query.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BoardAddNewColumnForm from '~/boards/components/board_add_new_column_form.vue';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import { ListType } from '~/boards/constants';
import { WIDGET_TYPE_STATUS } from '~/work_items/constants';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { getIterationPeriod } from 'ee/iterations/utils';
import { createBoardListResponse, labelsQueryResponse } from 'jest/boards/mock_data';
import {
  mockWorkItemStatus,
  namespaceWorkItemTypesQueryResponse,
} from 'ee_else_ce_jest/work_items/mock_data';
import {
  mockAssignees,
  mockIterations,
  assigneesQueryResponse,
  milestonesQueryResponse,
  iterationsQueryResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('BoardAddNewColumn', () => {
  let wrapper;
  let mockApollo;

  const createBoardListQueryHandler = jest.fn().mockResolvedValue(createBoardListResponse);
  const labelsQueryHandler = jest.fn().mockResolvedValue(labelsQueryResponse);
  const milestonesQueryHandler = jest.fn().mockResolvedValue(milestonesQueryResponse);
  const assigneesQueryHandler = jest.fn().mockResolvedValue(assigneesQueryResponse);
  const iterationQueryHandler = jest.fn().mockResolvedValue(iterationsQueryResponse);
  const namespaceQueryHandler = jest.fn().mockResolvedValue(namespaceWorkItemTypesQueryResponse);
  const errorMessageMilestones = 'Failed to fetch milestones';
  const milestonesQueryHandlerFailure = jest
    .fn()
    .mockRejectedValue(new Error(errorMessageMilestones));
  const errorMessageAssignees = 'Failed to fetch assignees';
  const assigneesQueryHandlerFailure = jest
    .fn()
    .mockRejectedValue(new Error(errorMessageAssignees));
  const errorMessageIterations = 'Failed to fetch iterations';
  const iterationsQueryHandlerFailure = jest
    .fn()
    .mockRejectedValue(new Error(errorMessageIterations));
  const namespaceQueryHandlerFailure = jest.fn().mockRejectedValue(new Error('Oops, error'));

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownButton = () => wrapper.findComponent(GlButton);
  const selectItem = (id) => {
    findDropdown().vm.$emit('select', id);
  };

  const search = (searchString) => findDropdown().vm.$emit('search', searchString);

  let allowedStatus = [];

  namespaceWorkItemTypesQueryResponse.data.namespace?.workItemTypes?.nodes?.forEach((type) => {
    const statusWidget = type.widgetDefinitions.find(
      (widget) => widget.type === WIDGET_TYPE_STATUS,
    );
    if (statusWidget) {
      allowedStatus = unionBy(allowedStatus, statusWidget.allowedStatuses, 'id');
    }
  });

  const createMockApolloClient = (handlers = {}) => {
    return createMockApollo([
      [boardLabelsQuery, handlers.labelsHandler || labelsQueryHandler],
      [usersAutocompleteQuery, handlers.assigneesHandler || assigneesQueryHandler],
      [projectBoardMilestonesQuery, handlers.milestonesHandler || milestonesQueryHandler],
      [searchIterationQuery, handlers.iterationHandler || iterationQueryHandler],
      [namespaceWorkItemTypesQuery, handlers.namespaceHandler || namespaceQueryHandler],
      [createBoardListMutation, handlers.createHandler || createBoardListQueryHandler],
    ]);
  };

  const mountComponent = ({
    selectedId,
    provide = {},
    labelsHandler = labelsQueryHandler,
    milestonesHandler = milestonesQueryHandler,
    assigneesHandler = assigneesQueryHandler,
    iterationHandler = iterationQueryHandler,
    namespaceHandler = namespaceQueryHandler,
  } = {}) => {
    mockApollo = createMockApolloClient({
      labelsHandler,
      milestonesHandler,
      assigneesHandler,
      iterationHandler,
      namespaceHandler,
    });

    wrapper = shallowMountExtended(BoardAddNewColumn, {
      apolloProvider: mockApollo,
      propsData: {
        listQueryVariables: {},
        boardId: 'gid://gitlab/Board/1',
        lists: {},
      },
      stubs: {
        BoardAddNewColumnForm,
        GlFormRadio,
        GlFormRadioGroup,
        IterationTitle,
        GlCollapsibleListbox,
        GlButton,
      },
      data() {
        return {
          selectedId,
        };
      },
      provide: {
        scopedLabelsAvailable: true,
        milestoneListsAvailable: true,
        assigneeListsAvailable: true,
        iterationListsAvailable: true,
        statusListsAvailable: true,
        isEpicBoard: false,
        issuableType: 'issue',
        fullPath: 'gitlab-org/gitlab',
        boardType: 'project',
        ...provide,
      },
    });

    // trigger change event
    if (selectedId) {
      selectItem(selectedId);
    }

    // Necessary for cache update
    mockApollo.clients.defaultClient.cache.writeQuery = jest.fn();
  };

  const findForm = () => wrapper.findComponent(BoardAddNewColumnForm);
  const cancelButton = () => wrapper.findComponentByTestId('cancelAddNewColumn');
  const submitButton = () => wrapper.findComponentByTestId('addNewColumnButton');
  const findIterationItemAt = (i) => wrapper.findAllByTestId('new-column-iteration-item').at(i);
  const findAllListTypes = () => wrapper.findAllComponents(GlFormRadio);
  const listTypeSelect = (type) => {
    const radio = wrapper
      .findAllComponents(GlFormRadio)
      .filter((r) => r.props('value') === type)
      .at(0);
    radio.element.value = type;
    radio.vm.$emit('change', type);
  };
  const selectIteration = async () => {
    listTypeSelect(ListType.iteration);

    await nextTick();
  };

  const expectIterationWithTitle = () => {
    expect(findIterationItemAt(1).text()).toContain(getIterationPeriod(mockIterations[1]));
    expect(findIterationItemAt(1).text()).toContain(mockIterations[1].title);
  };

  const expectIterationWithoutTitle = () => {
    expect(findIterationItemAt(0).text()).toContain(getIterationPeriod(mockIterations[0]));
    expect(findIterationItemAt(0).findComponent(IterationTitle).exists()).toBe(false);
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  it('clicking cancel hides the form', () => {
    mountComponent();

    cancelButton().vm.$emit('click');

    expect(wrapper.emitted('set-add-column-form-visibility')).toEqual([[false]]);
  });

  it('renders GlCollapsibleListbox with search field', () => {
    mountComponent();

    expect(findDropdown().exists()).toBe(true);
    expect(findDropdown().props('searchable')).toBe(true);
  });

  describe('Add list button', () => {
    it('is enabled if no item is selected', () => {
      mountComponent();

      expect(submitButton().props('disabled')).toBe(false);
    });
  });

  describe('List types', () => {
    describe('assignee list', () => {
      beforeEach(async () => {
        mountComponent();
        listTypeSelect(ListType.assignee);

        await nextTick();
      });

      it('sets assignee placeholder text in form', () => {
        expect(findForm().props('searchLabel')).toBe(BoardAddNewColumn.i18n.value);
        expect(findDropdown().props('searchPlaceholder')).toBe(
          listTypeInfo.assignee.searchPlaceholder,
        );
      });

      it('shows list of assignees', () => {
        const userList = wrapper.findAllComponents(GlAvatarLabeled);

        const [firstUser] = mockAssignees;

        expect(userList).toHaveLength(mockAssignees.length);
        expect(userList.at(0).props()).toMatchObject({
          label: firstUser.name,
          subLabel: `@${firstUser.username}`,
        });
      });
    });

    describe('iteration list', () => {
      beforeEach(async () => {
        mountComponent();
        await selectIteration();
      });

      it('sets iteration placeholder text in form', () => {
        expect(findForm().props('searchLabel')).toBe(BoardAddNewColumn.i18n.value);
        expect(findDropdown().props('searchPlaceholder')).toBe(
          listTypeInfo.iteration.searchPlaceholder,
        );
      });

      it('shows list of iterations', () => {
        const itemList = findDropdown().props('items');

        expect(itemList).toHaveLength(mockIterations.length);
        expectIterationWithoutTitle();
        expectIterationWithTitle();
      });
    });

    describe('status list', () => {
      beforeEach(async () => {
        mountComponent();
        listTypeSelect(ListType.status);

        await nextTick();
      });

      it('shows the `status` as one of the radio buttons', () => {
        expect(findAllListTypes()).toHaveLength(5);

        expect(findAllListTypes().at(4).text()).toBe('Status');
      });

      it('sets status placeholder text in form', () => {
        expect(findForm().props('searchLabel')).toBe(BoardAddNewColumn.i18n.value);
        expect(findDropdown().props('searchPlaceholder')).toBe('Search status');
      });

      it('shows list of status', () => {
        const statusList = wrapper.findAllByTestId('status-list-item');

        expect(statusList).toHaveLength(allowedStatus.length);
        expect(statusList.at(0).text()).toContain(allowedStatus[0].name);
      });

      it('uses fuzzaldrin logic to search on frontend', async () => {
        search('TO DO');

        await nextTick();

        const statusList = wrapper.findAllByTestId('status-list-item');

        expect(statusList).toHaveLength(1);
        expect(statusList.at(0).text()).toContain('To do');
      });

      it('adds status list', async () => {
        await waitForPromises();

        selectItem(mockWorkItemStatus.id);

        findForm().vm.$emit('add-list');

        await nextTick();

        expect(wrapper.emitted('highlight-list')).toBeUndefined();
        expect(createBoardListQueryHandler).toHaveBeenCalledWith({
          statusId: mockWorkItemStatus.id,
          position: null,
          boardId: 'gid://gitlab/Board/1',
        });
      });
    });

    describe('when fetch milestones query fails', () => {
      beforeEach(async () => {
        mountComponent({
          milestonesHandler: milestonesQueryHandlerFailure,
        });
        listTypeSelect(ListType.milestone);

        await nextTick();
      });

      it('sets error', async () => {
        findDropdown().vm.$emit('show');

        await waitForPromises();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });
    });

    describe('when fetch assignees query fails', () => {
      beforeEach(async () => {
        mountComponent({
          assigneesHandler: assigneesQueryHandlerFailure,
        });
        listTypeSelect(ListType.assignee);

        await nextTick();
      });

      it('sets error', async () => {
        findDropdown().vm.$emit('show');

        await waitForPromises();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });
    });

    describe('when fetch iterations query fails', () => {
      beforeEach(async () => {
        mountComponent({
          iterationHandler: iterationsQueryHandlerFailure,
        });
        await selectIteration();
      });

      it('sets error', async () => {
        findDropdown().vm.$emit('show');

        await waitForPromises();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });
    });

    describe('when fetch namespaceQuery query fails', () => {
      beforeEach(async () => {
        mountComponent({
          namespaceHandler: namespaceQueryHandlerFailure,
        });
        listTypeSelect(ListType.status);

        await nextTick();
      });

      it('sets error', async () => {
        findDropdown().vm.$emit('show');

        await waitForPromises();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });
    });
  });

  describe('Accessibility features', () => {
    beforeEach(() => {
      mockApollo = createMockApolloClient();

      wrapper = mountExtended(BoardAddNewColumn, {
        apolloProvider: mockApollo,
        propsData: {
          listQueryVariables: {},
          boardId: 'gid://gitlab/Board/1',
          lists: {},
        },
        data() {
          return {
            selectedId: null,
          };
        },
        provide: {
          scopedLabelsAvailable: true,
          milestoneListsAvailable: true,
          assigneeListsAvailable: true,
          iterationListsAvailable: true,
          statusListsAvailable: true,
          isEpicBoard: false,
          issuableType: 'issue',
          fullPath: 'gitlab-org/gitlab',
          boardType: 'project',
        },
      });

      mockApollo.clients.defaultClient.cache.writeQuery = jest.fn();
    });

    it('has the dropdown button with correct ID attribute', () => {
      expect(findDropdownButton().attributes('id')).toBe('board-value-dropdown');
    });

    it('should show dropdown button in a valid state', () => {
      expect(findDropdownButton().classes()).not.toContain('!gl-shadow-inner-1-red-400');
    });

    it('adds proper error styling when field is invalid', async () => {
      selectItem('');
      findForm().vm.$emit('add-list');

      await nextTick();

      expect(findDropdownButton().classes()).toContain('!gl-shadow-inner-1-red-400');
    });
  });
});
