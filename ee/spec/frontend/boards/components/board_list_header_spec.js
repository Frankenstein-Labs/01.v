import { GlButtonGroup } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import BoardListHeader from 'ee/boards/components/board_list_header.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  boardListQueryResponse,
  epicBoardListQueryResponse,
  mockList,
  mockLabelList,
  mockStatusList,
} from 'jest/boards/mock_data';
import { ListType } from '~/boards/constants';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import listQuery from 'ee/boards/graphql/board_lists_deferred.query.graphql';
import epicListQuery from 'ee/boards/graphql/epic_board_lists_deferred.query.graphql';

Vue.use(VueApollo);

const listMocks = {
  [ListType.assignee]: {
    assignee: {},
  },
  [ListType.label]: {
    ...mockLabelList,
  },
  [ListType.backlog]: {
    ...mockList,
  },
  [ListType.status]: {
    ...mockStatusList,
  },
};

describe('Board List Header Component', () => {
  let wrapper;
  let fakeApollo;

  const mockClientToggleListCollapsedResolver = jest.fn();
  const mockClientToggleEpicListCollapsedResolver = jest.fn();

  afterEach(() => {
    fakeApollo = null;

    localStorage.clear();
  });

  const createComponent = ({
    listType = ListType.backlog,
    collapsed = false,
    withLocalStorage = true,
    isSwimlanesHeader = false,
    weightFeatureAvailable = false,
    canCreateEpic = true,
    listQueryHandler = jest.fn().mockResolvedValue(boardListQueryResponse()),
    epicListQueryHandler = jest.fn().mockResolvedValue(epicBoardListQueryResponse()),
    currentUserId = 1,
    isEpicBoard = false,
    issuableType = 'issue',
    injectedProps = {},
  } = {}) => {
    const boardId = 'gid://gitlab/Board/1';

    const listMock = {
      ...listMocks[listType],
      listType,
      collapsed,
    };

    if (withLocalStorage) {
      localStorage.setItem(
        `boards.${boardId}.${listMock.listType}.${listMock.id}.expanded`,
        (!collapsed).toString(),
      );
    }

    fakeApollo = createMockApollo(
      [
        [listQuery, listQueryHandler],
        [epicListQuery, epicListQueryHandler],
      ],
      {
        Mutation: {
          clientToggleListCollapsed: mockClientToggleListCollapsedResolver,
          clientToggleEpicListCollapsed: mockClientToggleEpicListCollapsedResolver,
        },
      },
    );

    wrapper = mountExtended(BoardListHeader, {
      apolloProvider: fakeApollo,
      propsData: {
        list: listMock,
        filterParams: {},
        isSwimlanesHeader,
        boardId,
      },
      provide: {
        weightFeatureAvailable,
        currentUserId,
        canCreateEpic,
        isEpicBoard,
        disabled: false,
        issuableType,
        ...injectedProps,
      },
      stubs: {
        GlButtonGroup,
      },
    });
  };

  const newEpicText = 'Create new epic';
  const listSettingsText = 'Edit list settings';
  const newEpicBtnTestId = 'new-epic-btn';
  const listSettingsTestId = 'settings-btn';

  const findButtonGroup = () => wrapper.findComponent(GlButtonGroup);
  const findNewEpicButton = () => wrapper.findByTestId(newEpicBtnTestId);
  const findSettingsButton = () => wrapper.findByTestId(listSettingsTestId);
  const findCaret = () => wrapper.findComponentByTestId('board-title-caret');
  const findStatusIcon = () => wrapper.findByTestId('status-icon');

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  afterEach(() => {
    localStorage.clear();
  });

  describe('New epic button', () => {
    beforeEach(() => {
      createComponent({ isEpicBoard: true, issuableType: 'epic' });
    });

    it('renders Create new epic button', () => {
      expect(findButtonGroup().exists()).toBe(true);

      expect(findNewEpicButton().exists()).toBe(true);

      expect(findNewEpicButton().attributes()).toMatchObject({
        'data-testid': newEpicBtnTestId,
        title: newEpicText,
        'aria-label': newEpicText,
      });
    });

    it('does not render button group and New epic button when canCreateEpic is false', () => {
      createComponent({
        canCreateEpic: false,
        isEpicBoard: true,
        issuableType: 'epic',
      });

      expect(findButtonGroup().exists()).toBe(false);
    });

    it('emits `toggle-new-form` event when clicked', () => {
      expect(wrapper.emitted('toggle-new-form')).toBeUndefined();

      findNewEpicButton().trigger('click');

      expect(wrapper.emitted('toggle-new-form')).toHaveLength(1);
    });
  });

  describe('Settings Button', () => {
    const hasSettings = [
      ListType.assignee,
      ListType.milestone,
      ListType.iteration,
      ListType.label,
      ListType.status,
    ];

    it.each(hasSettings)('does render for List Type `%s`', (listType) => {
      createComponent({ listType });

      expect(findSettingsButton().attributes()).toMatchObject({
        'data-testid': listSettingsTestId,
        title: listSettingsText,
        'aria-label': listSettingsText,
      });
    });

    it('does not render for List Type `backlog`', () => {
      const listType = ListType.backlog;

      createComponent({ listType });

      expect(findSettingsButton().exists()).toBe(false);
    });

    it('does not render button group for List Type `closed`', () => {
      const listType = ListType.closed;
      createComponent({ listType });

      expect(findButtonGroup().exists()).toBe(false);
    });
  });

  describe('Swimlanes header', () => {
    it('when collapsed, it displays info icon', () => {
      createComponent({ isSwimlanesHeader: true, collapsed: true });

      expect(wrapper.find('.board-header-collapsed-info-icon').exists()).toBe(true);
    });

    it('does not show `status` icon on swimlanes header when collapsed', () => {
      createComponent({ isSwimlanesHeader: true, collapsed: true, listType: ListType.status });

      expect(findStatusIcon().exists()).toBe(false);
    });
  });

  describe('set-total-issues-count event', () => {
    const listId = boardListQueryResponse().data.boardList.id;
    const count = boardListQueryResponse().data.boardList.issuesCount;

    it('emits set-total-issues-count when isEpicBoard is false', async () => {
      createComponent({ isEpicBoard: false });
      await waitForPromises();

      expect(wrapper.emitted('set-total-issues-count')).toHaveLength(1);
      expect(wrapper.emitted('set-total-issues-count')[0]).toEqual([listId, count]);
    });

    it('does not emit set-total-issues-count when isEpicBoard is true', async () => {
      createComponent({ isEpicBoard: true, issuableType: 'epic' });
      await waitForPromises();

      expect(wrapper.emitted('set-total-issues-count')).toBeUndefined();
    });
  });

  describe('weightFeatureAvailable', () => {
    describe('weightFeatureAvailable is true', () => {
      it.each`
        isEpicBoard | issuableType | totalWeight
        ${true}     | ${'epic'}    | ${epicBoardListQueryResponse().data.epicBoardList.metadata.totalWeight}
        ${false}    | ${'issue'}   | ${boardListQueryResponse().data.boardList.totalIssueWeight}
      `('isEpicBoard is $isEpicBoard', async ({ isEpicBoard, totalWeight, issuableType }) => {
        createComponent({
          weightFeatureAvailable: true,
          isEpicBoard,
          issuableType,
        });

        await waitForPromises();

        const weightTooltip = wrapper.findComponent({ ref: 'weightTooltip' });

        expect(weightTooltip.exists()).toBe(true);
        expect(weightTooltip.text()).toContain(totalWeight.toString());
      });
    });

    it('weightFeatureAvailable is false', () => {
      createComponent();

      expect(wrapper.findComponent({ ref: 'weightTooltip' }).exists()).toBe(false);
    });
  });

  it('status list header has icon', () => {
    createComponent({ listType: ListType.status });

    expect(findStatusIcon().exists()).toBe(true);
  });

  it.each`
    issuableType | isEpicBoard | queryHandler                                 | notCalledHandler
    ${'epic'}    | ${true}     | ${mockClientToggleEpicListCollapsedResolver} | ${mockClientToggleListCollapsedResolver}
    ${'issue'}   | ${false}    | ${mockClientToggleListCollapsedResolver}     | ${mockClientToggleEpicListCollapsedResolver}
  `(
    'sets $issuableType list collapsed state',
    async ({ issuableType, isEpicBoard, queryHandler, notCalledHandler }) => {
      createComponent({
        injectedProps: { issuableType, isEpicBoard },
      });

      await nextTick();
      findCaret().vm.$emit('click');
      await nextTick();

      expect(queryHandler).toHaveBeenCalledWith(
        {},
        {
          list: mockList,
          collapsed: true,
        },
        expect.anything(),
        expect.anything(),
      );
      expect(notCalledHandler).not.toHaveBeenCalled();
    },
  );

  describe('when fetch list query fails', () => {
    const errorMessage = 'Failed to fetch list';
    const listQueryHandlerFailure = jest.fn().mockRejectedValue(new Error(errorMessage));

    beforeEach(() => {
      createComponent({
        listQueryHandler: listQueryHandlerFailure,
      });
    });

    it.each`
      issuableType | isEpicBoard
      ${'epic'}    | ${true}
      ${'issue'}   | ${false}
    `('sets error for $issuableType', async ({ issuableType, isEpicBoard }) => {
      createComponent({
        listQueryHandler: listQueryHandlerFailure,
        epicListQueryHandler: listQueryHandlerFailure,
        injectedProps: { issuableType, isEpicBoard },
      });

      await waitForPromises();

      expect(cacheUpdates.setError).toHaveBeenCalled();
    });
  });
});
