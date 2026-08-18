import { GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import setWindowLocation from 'helpers/set_window_location_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import BoardView from '~/work_items/board/board_view.vue';
import ColumnGroup from '~/work_items/board/components/column_group.vue';
import DraggableCompat from '~/lib/utils/vue3compat/draggable_compat.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import { updateDraft } from '~/lib/utils/autosave';
import getBoardNamespaceStatusesQuery from 'ee_else_ce/work_items/board/graphql/get_namespace_statuses.query.graphql';
import getBoardWorkItemsQuery from 'ee_else_ce/work_items/board/graphql/get_board_work_items.query.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import updateBoardWorkItemMutation from '~/work_items/board/graphql/update_board_work_item.mutation.graphql';
import { resolveInheritedWidgetsDraft } from '~/work_items/board/filter_inheritance';
import { statusStrategy } from 'ee/work_items/board/grouping/status_strategy';
import { boardColumnQueryVariables, boardColumnCountVariables } from '~/work_items/board/utils';
import workItemsGroupByVisibleGroupsQuery from '~/work_items/board/grouping/graphql/client/visible_groups.query.graphql';
import { RELATIVE_POSITION_ASC } from '~/work_items/list/constants';
import { MOVE_IN_PROGRESS_INDICATOR_DELAY } from '~/work_items/board/constants';
import {
  addWorkItemToColumn,
  adjustWorkItemCountInColumn,
  readWorkItemFromColumn,
  readWorkItemsFromColumn,
  removeWorkItemFromColumn,
} from '~/work_items/board/graphql/cache_updates';
import {
  buildStatus,
  buildStatusWidget,
  buildNamespaceStatusesResponse,
  buildBoardWorkItemsResponse,
  buildWorkItemNode,
  buildWorkItemTypesResponse,
} from 'jest/work_items/board/mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/work_items/board/graphql/cache_updates');
jest.mock('~/lib/utils/autosave');
jest.mock('~/work_items/board/filter_inheritance');

Vue.use(VueApollo);

describe('BoardView', () => {
  let wrapper;
  let toast;
  let apolloProvider;

  const statusesQueryHandler = jest.fn();
  const workItemTypesQueryHandler = jest.fn();
  const updateMutationHandler = jest.fn();
  const boardWorkItemsQueryHandler = jest.fn();

  const defaultStatuses = [
    buildStatus(1, 'To do', 'to_do'),
    buildStatus(2, 'In progress', 'in_progress'),
    buildStatus(3, 'Done', 'done'),
  ];
  // The board always enforces Manual sort, so position persistence is active.
  const queryVariables = { state: 'opened', sort: RELATIVE_POSITION_ASC };

  const columnVariables = (value) =>
    boardColumnQueryVariables({
      rootPageFullPath: 'full/path',
      baseQueryVariables: queryVariables,
      columnFilter: { status: { name: value.name } },
    });

  const columnCountVariables = (value) =>
    boardColumnCountVariables({
      rootPageFullPath: 'full/path',
      baseQueryVariables: queryVariables,
      columnFilter: { status: { name: value.name } },
    });

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findColumnGroups = () => wrapper.findAllComponents(ColumnGroup);
  const findColumnDraggable = () => wrapper.findComponent(DraggableCompat);
  const columnNames = () => findColumnGroups().wrappers.map((group) => group.props('value').name);
  const findCreateModal = () => wrapper.findComponent(CreateWorkItemModal);

  const createComponent = ({ props = {}, visibleGroups = null } = {}) => {
    toast = { show: jest.fn() };
    apolloProvider = createMockApollo([
      [getBoardNamespaceStatusesQuery, statusesQueryHandler],
      [getBoardWorkItemsQuery, boardWorkItemsQueryHandler],
      [namespaceWorkItemTypesQuery, workItemTypesQueryHandler],
      [updateBoardWorkItemMutation, updateMutationHandler],
    ]);
    apolloProvider.clients.defaultClient.writeQuery({
      query: workItemsGroupByVisibleGroupsQuery,
      // `hydrated: true` by default so the query fires immediately, matching
      // the common case in tests below that aren't specifically about hydration.
      data: {
        workItemsGroupByVisibleGroups: visibleGroups,
        workItemsGroupByVisibleGroupsHydrated: true,
      },
    });

    wrapper = shallowMountExtended(BoardView, {
      apolloProvider,
      mocks: { $toast: toast },
      propsData: {
        rootPageFullPath: 'full/path',
        queryVariables,
        ...props,
      },
    });
  };

  beforeEach(() => {
    // Mirrors the backend's `ids` filter (see StatusesResolver) so tests that
    // scope visibleGroups get realistic, filtered responses back.
    statusesQueryHandler.mockImplementation(({ ids } = {}) =>
      Promise.resolve(
        buildNamespaceStatusesResponse(
          ids ? defaultStatuses.filter((status) => ids.includes(status.id)) : defaultStatuses,
        ),
      ),
    );
    workItemTypesQueryHandler.mockResolvedValue(buildWorkItemTypesResponse());
    boardWorkItemsQueryHandler.mockResolvedValue(
      buildBoardWorkItemsResponse([buildWorkItemNode(9)]),
    );
    resolveInheritedWidgetsDraft.mockResolvedValue({});
    readWorkItemsFromColumn.mockReturnValue([]);
    updateMutationHandler.mockResolvedValue({
      data: { workItemUpdate: { workItem: buildWorkItemNode(1), errors: [] } },
    });
  });

  describe('loading state', () => {
    it('renders the loading icon while the query is loading and no values are present', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findColumnGroups()).toHaveLength(0);
    });

    it('hides the loading icon once the query resolves', async () => {
      createComponent();
      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });
  });

  describe('column groups', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders one ColumnGroup per status node', () => {
      expect(findColumnGroups()).toHaveLength(defaultStatuses.length);
    });

    it('passes value, strategy, rootPageFullPath, and baseQueryVariables to each ColumnGroup', () => {
      findColumnGroups().wrappers.forEach((columnGroup, index) => {
        expect(columnGroup.props()).toMatchObject({
          value: defaultStatuses[index],
          rootPageFullPath: 'full/path',
          baseQueryVariables: queryVariables,
        });
        expect(columnGroup.props('strategy').property).toBe('status');
      });
    });

    it('renders no ColumnGroups when the query returns no statuses', async () => {
      statusesQueryHandler.mockResolvedValue(buildNamespaceStatusesResponse([]));
      createComponent();
      await waitForPromises();

      expect(findColumnGroups()).toHaveLength(0);
    });

    it('orders the columns by status category', async () => {
      statusesQueryHandler.mockResolvedValue(
        buildNamespaceStatusesResponse([
          buildStatus(1, 'Cancelled', 'canceled'),
          buildStatus(2, 'Done', 'done'),
          buildStatus(3, 'Triage', 'triage'),
          buildStatus(4, 'In progress', 'in_progress'),
          buildStatus(5, 'To do', 'to_do'),
        ]),
      );
      createComponent();
      await waitForPromises();

      expect(findColumnGroups().wrappers.map((group) => group.props('value').name)).toEqual([
        'Triage',
        'To do',
        'In progress',
        'Done',
        'Cancelled',
      ]);
    });
  });

  describe('creating a work item in a column', () => {
    const toDo = defaultStatuses[0];
    const createdWorkItem = buildWorkItemNode(9);

    const requestCreate = async (status = toDo) => {
      findColumnGroups().at(defaultStatuses.indexOf(status)).vm.$emit('create-item', status);
      await waitForPromises();
    };

    beforeEach(async () => {
      createComponent({ props: { canCreateWorkItem: true, preselectedWorkItemType: 'Issue' } });
      await waitForPromises();
    });

    it('resolves the board filters and merges the inherited widgets into the draft', async () => {
      const bug = { __typename: 'Label', id: 'gid://gitlab/Label/1', title: 'bug' };
      resolveInheritedWidgetsDraft.mockResolvedValue({ LABELS: { labels: { nodes: [bug] } } });
      createComponent({
        props: {
          canCreateWorkItem: true,
          preselectedWorkItemType: 'Issue',
          queryVariables: { ...queryVariables, labelName: ['bug'], isGroup: false },
        },
      });
      await waitForPromises();

      await requestCreate();

      expect(resolveInheritedWidgetsDraft).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: 'full/path',
          isGroup: false,
          filters: expect.objectContaining({ labelName: ['bug'] }),
        }),
      );
      const [, draftJson] = updateDraft.mock.calls[0];
      expect(JSON.parse(draftJson)).toMatchObject({
        STATUS: { status: { name: toDo.name } },
        LABELS: { labels: { nodes: [bug] } },
      });
    });

    it('pre-populates the new item widgets draft with the column grouping', async () => {
      await requestCreate();

      expect(updateDraft).toHaveBeenCalledTimes(1);
      const [, draftJson] = updateDraft.mock.calls[0];
      expect(JSON.parse(draftJson)).toEqual({ STATUS: { status: toDo } });
    });

    it('opens the create modal preselected for the board type and board context', async () => {
      await requestCreate();

      expect(findCreateModal().props()).toMatchObject({
        preselectedWorkItemType: 'Issue',
        creationContext: 'board',
        createSource: 'work_item_board',
        alwaysShowWorkItemTypeSelect: true,
        suppressCreatedToast: true,
      });
    });

    it('inserts the created item at the top of its column and updates the count', async () => {
      await requestCreate();

      findCreateModal().vm.$emit('work-item-created', createdWorkItem);
      await waitForPromises();

      expect(addWorkItemToColumn).toHaveBeenCalledWith(
        expect.objectContaining({ variables: columnVariables(toDo), index: 0 }),
      );
      expect(addWorkItemToColumn.mock.calls[0][0].workItem.id).toBe(createdWorkItem.id);
      expect(adjustWorkItemCountInColumn).toHaveBeenCalledWith(
        expect.objectContaining({ variables: columnCountVariables(toDo), delta: 1 }),
      );
      expect(wrapper.emitted('work-item-created')).toEqual([[createdWorkItem]]);
    });

    it('shows the created toast when the item is on the board view', async () => {
      await requestCreate();

      findCreateModal().vm.$emit('work-item-created', createdWorkItem);
      await waitForPromises();

      expect(toast.show).toHaveBeenCalledWith('Issue created.', expect.any(Object));
    });

    it('shows a not-shown toast and does not insert when the board filters exclude the item', async () => {
      // The board view fetch finds no matching item, so it is filtered out of this view.
      boardWorkItemsQueryHandler.mockResolvedValue(buildBoardWorkItemsResponse([]));
      await requestCreate();

      findCreateModal().vm.$emit('work-item-created', createdWorkItem);
      await waitForPromises();

      expect(toast.show).toHaveBeenCalledWith(
        'Issue created, but it is not shown on the current view.',
        expect.any(Object),
      );
      expect(addWorkItemToColumn).not.toHaveBeenCalled();
    });

    it('closes the modal after the item is created', async () => {
      await requestCreate();
      expect(findCreateModal().exists()).toBe(true);

      findCreateModal().vm.$emit('work-item-created', createdWorkItem);
      await waitForPromises();

      expect(findCreateModal().exists()).toBe(false);
    });

    it('closes the modal without creating anything when it is dismissed', async () => {
      await requestCreate();

      findCreateModal().vm.$emit('hide-modal');
      await nextTick();

      expect(findCreateModal().exists()).toBe(false);
      expect(addWorkItemToColumn).not.toHaveBeenCalled();
      expect(wrapper.emitted('work-item-created')).toBeUndefined();
    });

    it('does not offer creation when canCreateWorkItem is false', async () => {
      createComponent({ props: { canCreateWorkItem: false } });
      await waitForPromises();

      expect(
        findColumnGroups().wrappers.every((group) => group.props('canCreateWorkItem') === false),
      ).toBe(true);
    });
  });

  describe('persisting the created item position', () => {
    const toDo = defaultStatuses[0];
    const createdWorkItem = buildWorkItemNode(9);
    const topCard = buildWorkItemNode(5);

    const createItem = async ({ nodes = [topCard], props = {} } = {}) => {
      readWorkItemsFromColumn.mockReturnValue(nodes);
      createComponent({
        props: { canCreateWorkItem: true, preselectedWorkItemType: 'Issue', ...props },
      });
      await waitForPromises();

      findColumnGroups().at(defaultStatuses.indexOf(toDo)).vm.$emit('create-item', toDo);
      await waitForPromises();

      findCreateModal().vm.$emit('work-item-created', createdWorkItem);
      await waitForPromises();
    };

    it('persists the new item above the current top card under manual sort', async () => {
      await createItem();

      expect(updateMutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: { id: createdWorkItem.id, moveAfterId: topCard.id },
        }),
      );
    });

    it('does not persist a position when the board is not sorted manually', async () => {
      await createItem({ props: { queryVariables: { ...queryVariables, sort: 'CREATED_DESC' } } });

      expect(updateMutationHandler).not.toHaveBeenCalled();
    });
  });

  describe('collapsed groups', () => {
    const groupId = (status) => `status:${status.id}`;

    it('marks only columns whose group id is in collapsedGroups as collapsed', async () => {
      createComponent({ props: { collapsedGroups: [groupId(defaultStatuses[1])] } });
      await waitForPromises();

      expect(findColumnGroups().wrappers.map((group) => group.props('collapsed'))).toEqual([
        false,
        true,
        false,
      ]);
    });

    it('defaults every column to expanded when collapsedGroups is empty', async () => {
      createComponent();
      await waitForPromises();

      expect(findColumnGroups().wrappers.map((group) => group.props('collapsed'))).toEqual([
        false,
        false,
        false,
      ]);
    });

    it('emits toggle-collapse with the group id when a column requests it', async () => {
      createComponent();
      await waitForPromises();

      findColumnGroups().at(2).vm.$emit('toggle-collapse');

      expect(wrapper.emitted('toggle-collapse')).toEqual([[groupId(defaultStatuses[2])]]);
    });
  });

  describe('column reordering', () => {
    const groupId = (status) => `status:${status.id}`;
    const createReorderable = ({ props = {}, visibleGroups } = {}) =>
      createComponent({ props: { canReorder: true, ...props }, visibleGroups });

    it('renders columns in the persisted groupOrder, appending unlisted ones in default order', async () => {
      createReorderable({
        props: { groupOrder: [groupId(defaultStatuses[1]), groupId(defaultStatuses[0])] },
      });
      await waitForPromises();

      expect(columnNames()).toEqual(['In progress', 'To do', 'Done']);
    });

    it('emits reorder-groups with the new group id order when a column is dragged', async () => {
      createReorderable();
      await waitForPromises();

      findColumnDraggable().vm.$emit('end', { oldIndex: 0, newIndex: 2 });

      expect(wrapper.emitted('reorder-groups')).toEqual([
        [[groupId(defaultStatuses[1]), groupId(defaultStatuses[2]), groupId(defaultStatuses[0])]],
      ]);
    });

    it('reflects the new order immediately, without waiting for the persisted groupOrder', async () => {
      createReorderable();
      await waitForPromises();

      findColumnDraggable().vm.$emit('end', { oldIndex: 0, newIndex: 2 });
      await nextTick();

      expect(columnNames()).toEqual(['In progress', 'Done', 'To do']);
    });

    it('does not emit reorder-groups when a column is dropped in place', async () => {
      createReorderable();
      await waitForPromises();

      findColumnDraggable().vm.$emit('end', { oldIndex: 1, newIndex: 1 });

      expect(wrapper.emitted('reorder-groups')).toBeUndefined();
    });

    it('keeps a hidden column at its stored position when reordering the visible ones', async () => {
      // Stored order: Done, In progress, To do — with Done hidden. Hidden groups
      // aren't fetched at all (scoped fetch), so `groupByValues` only ever contains
      // the visible ones. Done's stored slot still has to survive the reorder,
      // since it's still a real column, just not part of this fetch.
      createReorderable({
        props: {
          groupOrder: [
            groupId(defaultStatuses[2]),
            groupId(defaultStatuses[1]),
            groupId(defaultStatuses[0]),
          ],
        },
        visibleGroups: [groupId(defaultStatuses[1]), groupId(defaultStatuses[0])],
      });
      await waitForPromises();

      expect(columnNames()).toEqual(['In progress', 'To do']);

      findColumnDraggable().vm.$emit('end', { oldIndex: 0, newIndex: 1 });

      expect(wrapper.emitted('reorder-groups')).toEqual([
        [[groupId(defaultStatuses[2]), groupId(defaultStatuses[0]), groupId(defaultStatuses[1])]],
      ]);
    });

    it('tells each column whether it can move left/right based on its position', async () => {
      createReorderable();
      await waitForPromises();

      const columns = findColumnGroups();
      expect(columns.at(0).props()).toMatchObject({ canMoveLeft: false, canMoveRight: true });
      expect(columns.at(1).props()).toMatchObject({ canMoveLeft: true, canMoveRight: true });
      expect(columns.at(2).props()).toMatchObject({ canMoveLeft: true, canMoveRight: false });
    });

    it('moves a column right via the header menu, reflecting and persisting the new order', async () => {
      createReorderable();
      await waitForPromises();

      findColumnGroups().at(0).vm.$emit('move-column', 1);
      await nextTick();

      expect(columnNames()).toEqual(['In progress', 'To do', 'Done']);
      expect(wrapper.emitted('reorder-groups')).toEqual([
        [[groupId(defaultStatuses[1]), groupId(defaultStatuses[0]), groupId(defaultStatuses[2])]],
      ]);
    });

    it('moves a column left via the header menu', async () => {
      createReorderable();
      await waitForPromises();

      findColumnGroups().at(2).vm.$emit('move-column', -1);
      await nextTick();

      expect(columnNames()).toEqual(['To do', 'Done', 'In progress']);
    });

    it('ignores a move past the first or last position', async () => {
      createReorderable();
      await waitForPromises();

      findColumnGroups().at(0).vm.$emit('move-column', -1);
      findColumnGroups().at(2).vm.$emit('move-column', 1);

      expect(wrapper.emitted('reorder-groups')).toBeUndefined();
      expect(columnNames()).toEqual(['To do', 'In progress', 'Done']);
    });

    it('disables column dragging when there is only one column', async () => {
      statusesQueryHandler.mockResolvedValue(
        buildNamespaceStatusesResponse([buildStatus(1, 'To do', 'to_do')]),
      );
      createReorderable();
      await waitForPromises();

      expect(findColumnDraggable().attributes('disabled')).toBeDefined();
      expect(findColumnGroups().at(0).props('reorderable')).toBe(false);
    });

    it('enables column dragging when there is more than one column', async () => {
      createReorderable();
      await waitForPromises();

      expect(findColumnDraggable().attributes('disabled')).toBeUndefined();
      expect(findColumnGroups().at(0).props('reorderable')).toBe(true);
    });

    it('does not allow reordering when the user cannot persist it', async () => {
      createComponent({ props: { canReorder: false } });
      await waitForPromises();

      expect(findColumnDraggable().attributes('disabled')).toBeDefined();
      expect(findColumnGroups().at(0).props('reorderable')).toBe(false);
    });
  });

  describe('when selecting a card', () => {
    const workItem = buildWorkItemNode(1);
    const showParam = (id) => btoa(JSON.stringify({ iid: '1', full_path: 'group/project', id }));

    afterEach(() => {
      setWindowLocation('http://test.host/');
    });

    it('opens the detail work item panel', async () => {
      createComponent();
      await waitForPromises();

      findColumnGroups().at(0).vm.$emit('set-active-item', workItem);

      expect(wrapper.emitted('set-active-item')).toEqual([[workItem]]);
    });

    it('opens the detail panel for the item on reload', async () => {
      setWindowLocation(`?show=${showParam(1)}`);
      createComponent();
      await waitForPromises();

      findColumnGroups().at(0).vm.$emit('check-board-params', [workItem]);

      expect(wrapper.emitted('set-active-item')).toEqual([
        [{ ...workItem, fullPath: 'group/project' }],
      ]);
    });

    it('does not open the panel when the "show" item is not in the loaded column', async () => {
      setWindowLocation(`?show=${showParam(999)}`);
      createComponent();
      await waitForPromises();

      findColumnGroups().at(0).vm.$emit('check-board-params', [workItem]);

      expect(wrapper.emitted('set-active-item')).toBeUndefined();
    });
  });

  describe('fetch scoping', () => {
    const groupId = (status) => `status:${status.id}`;

    describe('when the store has not hydrated', () => {
      beforeEach(() => {
        const scopedApolloProvider = createMockApollo([
          [getBoardNamespaceStatusesQuery, statusesQueryHandler],
        ]);
        scopedApolloProvider.clients.defaultClient.writeQuery({
          query: workItemsGroupByVisibleGroupsQuery,
          data: {
            workItemsGroupByVisibleGroups: null,
            workItemsGroupByVisibleGroupsHydrated: false,
          },
        });

        wrapper = shallowMountExtended(BoardView, {
          apolloProvider: scopedApolloProvider,
          propsData: { rootPageFullPath: 'full/path', queryVariables },
        });
      });

      it('does not fetch the statuses', () => {
        expect(statusesQueryHandler).not.toHaveBeenCalled();
      });
    });

    describe('when no visible groups are set', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('fetches without an ids filter', () => {
        expect(statusesQueryHandler).toHaveBeenCalledWith({
          fullPath: 'full/path',
          ids: undefined,
        });
      });

      it('renders every column', () => {
        expect(findColumnGroups()).toHaveLength(defaultStatuses.length);
      });
    });

    describe('when only some group ids are visible', () => {
      beforeEach(async () => {
        createComponent({
          visibleGroups: [groupId(defaultStatuses[0]), groupId(defaultStatuses[2])],
        });
        await waitForPromises();
      });

      it('fetches only those ids', () => {
        expect(statusesQueryHandler).toHaveBeenCalledWith({
          fullPath: 'full/path',
          ids: [defaultStatuses[0].id, defaultStatuses[2].id],
        });
      });

      it('renders only the columns whose group id is listed', () => {
        expect(findColumnGroups().wrappers.map((group) => group.props('value').name)).toEqual([
          'To do',
          'Done',
        ]);
      });
    });

    describe('when the visible groups list is empty (hide all)', () => {
      beforeEach(async () => {
        // Set up independently of the shared handler's `ids ? filter : defaultStatuses`
        // mock, so this doesn't just prove the mock's own assumption about `ids: []`
        // matches itself — it asserts the backend is actually asked for zero groups.
        statusesQueryHandler.mockResolvedValue(buildNamespaceStatusesResponse([]));
        createComponent({ visibleGroups: [] });
        await waitForPromises();
      });

      it('fetches with an explicit empty ids filter, not an unfiltered request', () => {
        expect(statusesQueryHandler).toHaveBeenCalledWith({
          fullPath: 'full/path',
          ids: [],
        });
      });

      it('renders no columns', () => {
        expect(findColumnGroups()).toHaveLength(0);
      });
    });

    describe('when the visible groups change', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();

        apolloProvider.clients.defaultClient.writeQuery({
          query: workItemsGroupByVisibleGroupsQuery,
          data: {
            workItemsGroupByVisibleGroups: [groupId(defaultStatuses[1])],
            workItemsGroupByVisibleGroupsHydrated: true,
          },
        });
        await waitForPromises();
      });

      it('refetches and updates the rendered columns', () => {
        expect(findColumnGroups().wrappers.map((group) => group.props('value').name)).toEqual([
          'In progress',
        ]);
      });
    });
  });

  describe('drag and drop', () => {
    const fromStatus = defaultStatuses[0];
    const toStatus = defaultStatuses[1];
    const movedNode = buildWorkItemNode(1);

    const dragEvent = ({ from = fromStatus, to = toStatus, oldIndex = 0, newIndex = 0 } = {}) => ({
      from: { dataset: { groupValueId: from.id } },
      to: { dataset: { groupValueId: to.id } },
      item: { dataset: { workItemId: movedNode.id } },
      oldIndex,
      newIndex,
    });

    const emitCardMove = (event) => findColumnGroups().at(0).vm.$emit('card-move', event);

    beforeEach(async () => {
      readWorkItemFromColumn.mockReturnValue(movedNode);
      createComponent();
      await waitForPromises();
    });

    it('persists the move with the target status', async () => {
      emitCardMove(dragEvent());
      await waitForPromises();

      expect(updateMutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: { id: movedNode.id, statusWidget: { status: toStatus.id } },
        }),
      );
    });

    it('optimistically moves the card from the source column to the target column', async () => {
      emitCardMove(dragEvent());
      await waitForPromises();

      expect(removeWorkItemFromColumn).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: columnVariables(fromStatus),
          workItemId: movedNode.id,
        }),
      );
      expect(addWorkItemToColumn).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: columnVariables(toStatus),
          workItem: movedNode,
          index: 0,
          patchCard: expect.any(Function),
        }),
      );
    });

    it('decrements the source column count and increments the target column count', async () => {
      emitCardMove(dragEvent());
      await waitForPromises();

      expect(adjustWorkItemCountInColumn).toHaveBeenCalledWith(
        expect.objectContaining({ variables: columnCountVariables(fromStatus), delta: -1 }),
      );
      expect(adjustWorkItemCountInColumn).toHaveBeenCalledWith(
        expect.objectContaining({ variables: columnCountVariables(toStatus), delta: 1 }),
      );
    });

    it('does nothing when the card is dropped in its original column', () => {
      emitCardMove(dragEvent({ to: fromStatus }));

      expect(updateMutationHandler).not.toHaveBeenCalled();
      expect(removeWorkItemFromColumn).not.toHaveBeenCalled();
      expect(addWorkItemToColumn).not.toHaveBeenCalled();
      expect(adjustWorkItemCountInColumn).not.toHaveBeenCalled();
    });

    it('does nothing when the moved card is not in the cache', () => {
      readWorkItemFromColumn.mockReturnValue(null);

      emitCardMove(dragEvent());

      expect(updateMutationHandler).not.toHaveBeenCalled();
    });

    it('persists a same-column reorder with relative position and no status change', async () => {
      const columnNodes = [buildWorkItemNode(1), buildWorkItemNode(2), buildWorkItemNode(3)];
      readWorkItemsFromColumn.mockReturnValue(columnNodes);

      emitCardMove(dragEvent({ to: fromStatus, oldIndex: 0, newIndex: 2 }));
      await waitForPromises();

      expect(updateMutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: { id: movedNode.id, moveBeforeId: columnNodes[2].id },
        }),
      );
      expect(addWorkItemToColumn).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: columnVariables(fromStatus),
          index: 2,
          patchCard: null,
        }),
      );
    });

    it('includes relative position alongside the status change on a cross-column move', async () => {
      const columnNodes = [buildWorkItemNode(10), buildWorkItemNode(11)];
      readWorkItemsFromColumn.mockReturnValue(columnNodes);

      emitCardMove(dragEvent({ newIndex: 1 }));
      await waitForPromises();

      expect(updateMutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: {
            id: movedNode.id,
            statusWidget: { status: toStatus.id },
            moveBeforeId: columnNodes[0].id,
            moveAfterId: columnNodes[1].id,
          },
        }),
      );
    });

    it('disables dragging until the move mutation resolves', async () => {
      let resolveMutation;
      updateMutationHandler.mockReturnValue(
        new Promise((resolve) => {
          resolveMutation = resolve;
        }),
      );

      expect(findColumnGroups().at(0).props('dragDisabled')).toBe(false);

      emitCardMove(dragEvent());
      await nextTick();

      expect(findColumnGroups().at(0).props('dragDisabled')).toBe(true);

      resolveMutation({
        data: { workItemUpdate: { workItem: buildWorkItemNode(1), errors: [] } },
      });
      await waitForPromises();

      expect(findColumnGroups().at(0).props('dragDisabled')).toBe(false);
    });

    describe('busy indicator', () => {
      beforeEach(() => {
        jest.useFakeTimers({ legacyFakeTimers: false });
      });

      afterEach(() => {
        jest.useRealTimers();
      });

      it('does not show the busy indicator when the mutation resolves before the delay elapses', async () => {
        emitCardMove(dragEvent());
        await waitForPromises();

        jest.advanceTimersByTime(MOVE_IN_PROGRESS_INDICATOR_DELAY);
        await nextTick();

        expect(findColumnGroups().at(0).props('showBusyIndicator')).toBe(false);
      });

      it('shows the busy indicator only once the mutation has been in flight for the configured delay', async () => {
        let resolveMutation;
        updateMutationHandler.mockReturnValue(
          new Promise((resolve) => {
            resolveMutation = resolve;
          }),
        );

        emitCardMove(dragEvent());
        await nextTick();

        expect(findColumnGroups().at(0).props('showBusyIndicator')).toBe(false);

        jest.advanceTimersByTime(MOVE_IN_PROGRESS_INDICATOR_DELAY);
        await nextTick();

        expect(findColumnGroups().at(0).props('showBusyIndicator')).toBe(true);

        resolveMutation({
          data: { workItemUpdate: { workItem: buildWorkItemNode(1), errors: [] } },
        });
        await waitForPromises();

        expect(findColumnGroups().at(0).props('showBusyIndicator')).toBe(false);
      });
    });

    describe('when the board is not sorted manually', () => {
      const columnNodes = [buildWorkItemNode(1), buildWorkItemNode(2), buildWorkItemNode(3)];

      beforeEach(async () => {
        readWorkItemsFromColumn.mockReturnValue(columnNodes);
        createComponent({ props: { queryVariables: { ...queryVariables, sort: 'CREATED_DESC' } } });
        await waitForPromises();
      });

      it('does not persist a same-column reorder', () => {
        emitCardMove(dragEvent({ to: fromStatus, oldIndex: 0, newIndex: 2 }));

        expect(updateMutationHandler).not.toHaveBeenCalled();
      });

      it('persists the status change without relative position on a cross-column move', async () => {
        emitCardMove(dragEvent({ newIndex: 1 }));
        await waitForPromises();

        expect(updateMutationHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            input: { id: movedNode.id, statusWidget: { status: toStatus.id } },
          }),
        );
      });
    });

    it('shows a toast and captures the error when the mutation returns errors', async () => {
      updateMutationHandler.mockResolvedValue({
        data: { workItemUpdate: { workItem: null, errors: ['nope'] } },
      });

      emitCardMove(dragEvent());
      await waitForPromises();

      expect(toast.show).toHaveBeenCalledWith(
        'Something went wrong while updating the work item. Please try again.',
      );
      expect(Sentry.captureException).toHaveBeenCalled();
    });

    it('shows a toast and captures the error when the mutation rejects', async () => {
      updateMutationHandler.mockRejectedValue(new Error('network'));

      emitCardMove(dragEvent());
      await waitForPromises();

      expect(toast.show).toHaveBeenCalledWith(
        'Something went wrong while updating the work item. Please try again.',
      );
      expect(Sentry.captureException).toHaveBeenCalled();
    });
  });

  describe('when updating the column if a work item is updated via side panel', () => {
    const fromStatus = defaultStatuses[0];
    const toStatus = defaultStatuses[1];
    const updatedNode = buildWorkItemNode(1, { widgets: [buildStatusWidget(toStatus)] });

    const mockCurrentColumn = (columnStatus) => {
      readWorkItemFromColumn.mockImplementation(({ variables }) =>
        variables.status?.name === columnStatus.name ? updatedNode : null,
      );
    };

    const updateItem = async (workItem) => {
      wrapper.setProps({ updatedWorkItem: workItem });
      await nextTick();
    };

    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('moves the card from its current column to the one matching its new status', async () => {
      mockCurrentColumn(fromStatus);
      await updateItem(updatedNode);

      expect(removeWorkItemFromColumn).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: columnVariables(fromStatus),
          workItemId: updatedNode.id,
        }),
      );
      expect(addWorkItemToColumn).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: columnVariables(toStatus),
          workItem: updatedNode,
          index: 0,
          patchCard: expect.any(Function),
        }),
      );
    });

    it('updates the source column and the target column counts', async () => {
      mockCurrentColumn(fromStatus);
      await updateItem(updatedNode);

      expect(adjustWorkItemCountInColumn).toHaveBeenCalledWith(
        expect.objectContaining({ variables: columnCountVariables(fromStatus), delta: -1 }),
      );
      expect(adjustWorkItemCountInColumn).toHaveBeenCalledWith(
        expect.objectContaining({ variables: columnCountVariables(toStatus), delta: 1 }),
      );
    });

    it('does nothing when the card is already in the column matching its status', async () => {
      mockCurrentColumn(toStatus);
      await updateItem(updatedNode);

      expect(removeWorkItemFromColumn).not.toHaveBeenCalled();
      expect(addWorkItemToColumn).not.toHaveBeenCalled();
      expect(adjustWorkItemCountInColumn).not.toHaveBeenCalled();
    });
  });

  describe('drag eligibility gate', () => {
    const workItem = {
      id: 'gid://gitlab/WorkItem/1',
      workItemType: { id: 'gid://gitlab/WorkItems::Type/1' },
    };

    const startDrag = (item = workItem) => findColumnGroups().at(0).vm.$emit('drag-start', item);

    it('fetches gate data via the strategy gate query', async () => {
      createComponent({ props: { rootPageFullPath: 'group/subgroup' } });
      await waitForPromises();

      expect(workItemTypesQueryHandler).toHaveBeenCalledWith({ fullPath: 'group/subgroup' });
    });

    it('disables only the columns the strategy reports the dragged item cannot enter', async () => {
      // Gate the drop deterministically; the status-specific data logic lives in
      // status_strategy_spec (isDropAllowed / extractGateData).
      jest
        .spyOn(statusStrategy, 'isDropAllowed')
        .mockImplementation(({ value }) => value.id === defaultStatuses[0].id);
      createComponent();
      await waitForPromises();

      startDrag();
      await nextTick();

      expect(findColumnGroups().at(0).props('dropDisabled')).toBe(false);
      expect(findColumnGroups().at(1).props('dropDisabled')).toBe(true);
    });

    it('clears the disabled columns once a card move ends', async () => {
      jest
        .spyOn(statusStrategy, 'isDropAllowed')
        .mockImplementation(({ value }) => value.id === defaultStatuses[0].id);
      createComponent();
      await waitForPromises();

      startDrag();
      await nextTick();
      findColumnGroups().at(0).vm.$emit('card-move', { oldIndex: 0, newIndex: 0 });
      await nextTick();

      expect(findColumnGroups().wrappers.every((c) => c.props('dropDisabled') === false)).toBe(
        true,
      );
    });

    it('disables no columns when the type has no recorded status constraint', async () => {
      createComponent();
      await waitForPromises();

      startDrag();
      await nextTick();

      expect(findColumnGroups().wrappers.every((c) => c.props('dropDisabled') === false)).toBe(
        true,
      );
    });
  });

  describe('statuses query', () => {
    it('calls the statuses query with rootPageFullPath', async () => {
      createComponent({ props: { rootPageFullPath: 'group/subgroup' } });
      await nextTick();

      expect(statusesQueryHandler).toHaveBeenCalledWith({ fullPath: 'group/subgroup' });
    });
  });

  describe('when the statuses query errors', () => {
    const queryError = new Error('GraphQL failure');

    beforeEach(async () => {
      statusesQueryHandler.mockRejectedValue(queryError);
      createComponent();
      await waitForPromises();
    });

    it('captures the error in Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(queryError);
    });

    it('emits set-error with a user-facing message', () => {
      expect(wrapper.emitted('set-error')).toEqual([
        ['Something went wrong when fetching the board columns. Please try again.'],
      ]);
    });

    it('renders no ColumnGroups', () => {
      expect(findColumnGroups()).toHaveLength(0);
    });

    it('hides the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });
  });
});
