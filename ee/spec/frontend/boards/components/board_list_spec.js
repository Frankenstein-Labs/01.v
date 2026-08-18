import { nextTick } from 'vue';
import BoardNewEpic from 'ee/boards/components/board_new_epic.vue';
import waitForPromises from 'helpers/wait_for_promises';

import { DraggableItemTypes, WIP_WEIGHT, ListType } from 'ee_else_ce/boards/constants';
import BoardCard from '~/boards/components/board_card.vue';
import BoardCardInner from '~/boards/components/board_card_inner.vue';
import BoardCardMoveToPosition from '~/boards/components/board_card_move_to_position.vue';
import BoardNewIssue from '~/boards/components/board_new_issue.vue';
import BoardCutLine from '~/boards/components/board_cut_line.vue';
import listIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import issueCreateMutation from '~/boards/graphql/issue_create.mutation.graphql';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { TYPE_EPIC, TYPE_ISSUE, NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import issueMoveListMutation from 'ee/boards/graphql/issue_move_list.mutation.graphql';
import epicMoveListMutation from 'ee/boards/graphql/epic_move_list.mutation.graphql';
import epicCreateMutation from 'ee/boards/graphql/epic_create.mutation.graphql';
import listEpicsQuery from 'ee/boards/graphql/lists_epics_with_color.query.graphql';
import { mockList } from 'jest/boards/mock_data';
import { namespaceWorkItemTypesQueryResponse } from 'ee_else_ce_jest/work_items/mock_data';
import createComponent from '../board_list_helper';
import {
  mockGroupIssuesResponse,
  mockProjectIssuesResponse,
  mockGroupEpicsResponse,
  moveIssueMutationResponse,
  moveEpicMutationResponse,
  mockIssues,
  mockEpics,
  createIssueMutationResponse,
  createEpicMutationResponse,
} from '../mock_data';

jest.mock('~/alert');

const maxIssueWeightOrCountWarningClass = '.gl-bg-red-50';

const actions = {
  addListNewEpic: jest.fn().mockResolvedValue(),
};

const componentConfig = {
  actions,
  stubs: {
    BoardCard,
    BoardCardInner,
    BoardNewEpic,
    BoardCardMoveToPosition,
  },
  provide: {
    allowSubEpics: false,
    scopedLabelsAvailable: true,
    isEpicBoard: false,
    issuableType: TYPE_ISSUE,
    isGroupBoard: true,
    isProjectBoard: false,
  },
};

beforeEach(() => {
  cacheUpdates.setError = jest.fn();
});

describe('BoardList Component', () => {
  let wrapper;

  const startDrag = (
    params = {
      item: {
        dataset: {
          draggableItemType: DraggableItemTypes.card,
          itemId: mockIssues[0].id,
        },
      },
    },
  ) => {
    wrapper.findComponentByTestId('tree-root-wrapper').vm.$emit('start', params);
  };

  const endDrag = (params) => {
    wrapper.findComponentByTestId('tree-root-wrapper').vm.$emit('end', params);
  };
  const findNewIssueForm = () => wrapper.findComponent(BoardNewIssue);
  const findNewEpicForm = () => wrapper.findComponent(BoardNewEpic);

  beforeEach(() => {
    wrapper = createComponent(componentConfig);
  });

  it('renders link properly in issue', () => {
    expect(wrapper.find('.board-card .board-card-title a').attributes('href')).not.toContain(
      ':project_path',
    );
  });

  it('renders the move to position icon', () => {
    expect(wrapper.findComponent(BoardCardMoveToPosition).exists()).toBe(true);
  });

  it('does not render new item form by default', () => {
    expect(findNewIssueForm().exists()).toBe(false);
    expect(findNewEpicForm().exists()).toBe(false);
  });

  it.each`
    issuableType  | isEpicBoard | formComponent    | notRenderedFormComponent
    ${TYPE_EPIC}  | ${true}     | ${BoardNewEpic}  | ${BoardNewIssue}
    ${TYPE_ISSUE} | ${false}    | ${BoardNewIssue} | ${BoardNewEpic}
  `(
    'renders $issuableType form on adding new item',
    async ({ issuableType, isEpicBoard, formComponent, notRenderedFormComponent }) => {
      wrapper = createComponent({
        provide: {
          issuableType,
          isProjectBoard: false,
          isGroupBoard: true,
          isEpicBoard,
        },
        componentProps: { showNewForm: true },
        stubs: {
          BoardNewIssue,
          BoardNewEpic,
        },
      });

      await waitForPromises();

      expect(wrapper.findComponent(formComponent).exists()).toBe(true);
      expect(wrapper.findComponent(notRenderedFormComponent).exists()).toBe(false);
    },
  );
  describe('max issue weight warning', () => {
    describe('when issue weight exceeds max issue weight', () => {
      beforeEach(async () => {
        wrapper = createComponent({
          listProps: { totalIssueWeight: 4, maxIssueWeight: 2, limitMetric: WIP_WEIGHT },
        });
        await waitForPromises();
      });
      it('sets background to warning color', () => {
        const block = wrapper.find(maxIssueWeightOrCountWarningClass);

        expect(block.exists()).toBe(true);
        expect(block.attributes('class').split(' ')).toEqual(
          expect.arrayContaining(['gl-rounded-bl-lg', 'gl-rounded-br-lg']),
        );
      });
      it('shows cut line', () => {
        const cutline = wrapper.findComponent(BoardCutLine);
        expect(cutline.exists()).toBe(true);
        expect(cutline.props('cutLineText')).toEqual('Work in progress limit: 2 weight');
      });
    });

    describe('when list issue weight does NOT exceed list max issue weight', () => {
      beforeEach(async () => {
        wrapper = createComponent({
          list: { totalIssueWeight: 2, maxIssueWeight: 3, limitMetric: WIP_WEIGHT },
        });
        await waitForPromises();
      });
      it('does not sets background to warning color', () => {
        expect(wrapper.find(maxIssueWeightOrCountWarningClass).exists()).toBe(false);
      });
      it('does not show cut line', () => {
        expect(wrapper.findComponent(BoardCutLine).exists()).toBe(false);
      });
    });
    describe('when list max issue weight is 0', () => {
      beforeEach(async () => {
        wrapper = createComponent({ list: { totalIssueWeight: 0, limitMetric: WIP_WEIGHT } });
        await waitForPromises();
      });
      it('does not sets background to warning color', () => {
        expect(wrapper.find(maxIssueWeightOrCountWarningClass).exists()).toBe(false);
      });
      it('does not show cut line', () => {
        expect(wrapper.findComponent(BoardCutLine).exists()).toBe(false);
      });
    });
    describe('when boardList is either undefined or defined', () => {
      it('returns totalIssueWeight when boardList is defined', async () => {
        wrapper = createComponent({
          provide: {
            isEpicBoard: false,
          },
          listProps: {
            totalIssueWeight: 10,
          },
          propsData: {
            columnIndex: 1,
          },
        });

        await waitForPromises();
        await wrapper.vm.$forceUpdate();

        expect(wrapper.vm.listItemsWeight).toBe(5);
      });
    });
  });
  describe('Apollo boards', () => {
    const projectIssuesQueryHandlerSuccess = jest.fn().mockResolvedValue(mockProjectIssuesResponse);
    const groupIssuesQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupIssuesResponse());
    const groupEpicsQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupEpicsResponse);
    const moveIssueMutationHandlerSuccess = jest.fn().mockResolvedValue(moveIssueMutationResponse);
    const moveEpicMutationHandlerSuccess = jest.fn().mockResolvedValue(moveEpicMutationResponse);
    const createIssueMutationHandlerSuccess = jest
      .fn()
      .mockResolvedValue(createIssueMutationResponse);
    const createEpicMutationHandlerSuccess = jest
      .fn()
      .mockResolvedValue(createEpicMutationResponse);
    const queryHandlerFailure = jest.fn().mockRejectedValue(new Error('error'));
    const namespaceWorkItemTypesQueryHandler = jest
      .fn()
      .mockResolvedValue(namespaceWorkItemTypesQueryResponse);

    const apolloQueryHandlers = [
      [listIssuesQuery, groupIssuesQueryHandlerSuccess],
      [listEpicsQuery, groupEpicsQueryHandlerSuccess],
      [issueMoveListMutation, moveIssueMutationHandlerSuccess],
      [epicMoveListMutation, moveEpicMutationHandlerSuccess],
      [issueCreateMutation, createIssueMutationHandlerSuccess],
      [epicCreateMutation, createEpicMutationHandlerSuccess],
      [namespaceWorkItemTypesQuery, namespaceWorkItemTypesQueryHandler],
    ];

    const endDragIssueVariables = {
      oldIndex: 1,
      newIndex: 0,
      item: {
        dataset: {
          draggableItemType: DraggableItemTypes.card,
          itemId: mockIssues[1].id,
          itemIid: mockIssues[1].iid,
          itemPath: mockIssues[1].referencePath,
        },
      },
      to: { children: [], dataset: { listId: 'gid://gitlab/List/2' } },
      from: { dataset: { listId: 'gid://gitlab/List/1' } },
    };
    const endDragEpicVariables = {
      oldIndex: 1,
      newIndex: 0,
      item: {
        dataset: {
          draggableItemType: DraggableItemTypes.card,
          itemId: mockEpics[0].id,
          itemIid: mockEpics[0].iid,
          itemPath: mockEpics[0].referencePath,
        },
      },
      to: { children: [], dataset: { listId: 'gid://gitlab/Boards::EpicList/5' } },
      from: { dataset: { listId: 'gid://gitlab/Boards::EpicList/4' } },
    };

    it.each`
      boardType            | isEpicBoard | queryHandler                        | notCalledHandler
      ${NAMESPACE_GROUP}   | ${false}    | ${groupIssuesQueryHandlerSuccess}   | ${projectIssuesQueryHandlerSuccess}
      ${NAMESPACE_PROJECT} | ${false}    | ${projectIssuesQueryHandlerSuccess} | ${groupIssuesQueryHandlerSuccess}
      ${NAMESPACE_GROUP}   | ${true}     | ${groupEpicsQueryHandlerSuccess}    | ${groupIssuesQueryHandlerSuccess}
    `(
      'fetches $boardType items when isEpicBoard is $isEpicBoard',
      async ({ boardType, isEpicBoard, queryHandler, notCalledHandler }) => {
        createComponent({
          listProps: {
            id: 'gid://gitlab/List/3',
          },
          provide: {
            boardType,
            issuableType: isEpicBoard ? 'epic' : 'issue',
            isProjectBoard: boardType === NAMESPACE_PROJECT,
            isGroupBoard: boardType === NAMESPACE_GROUP,
            isEpicBoard,
          },
          apolloQueryHandlers: [
            [listIssuesQuery, queryHandler],
            [listEpicsQuery, groupEpicsQueryHandlerSuccess],
          ],
          stubs: {
            BoardCardMoveToPosition,
          },
        });

        await nextTick();

        expect(queryHandler).toHaveBeenCalled();
        expect(notCalledHandler).not.toHaveBeenCalled();
      },
    );

    it.each`
      boardType            | isEpicBoard
      ${NAMESPACE_GROUP}   | ${false}
      ${NAMESPACE_PROJECT} | ${false}
      ${NAMESPACE_GROUP}   | ${true}
    `(
      'set error when fetch $boardType items fails when isEpicBoard is $isEpicBoard',
      async ({ boardType, isEpicBoard }) => {
        createComponent({
          listProps: {
            id: 'gid://gitlab/List/3',
          },
          provide: {
            boardType,
            issuableType: isEpicBoard ? 'epic' : 'issue',
            isProjectBoard: boardType === NAMESPACE_PROJECT,
            isGroupBoard: boardType === NAMESPACE_GROUP,
            isEpicBoard,
          },
          apolloQueryHandlers: [
            [listIssuesQuery, queryHandlerFailure],
            [listEpicsQuery, queryHandlerFailure],
          ],
        });

        await waitForPromises();

        expect(cacheUpdates.setError).toHaveBeenCalled();
      },
    );

    it.each`
      issuableType  | isEpicBoard | endDragVariables         | queryHandler                       | notCalledHandler
      ${TYPE_ISSUE} | ${false}    | ${endDragIssueVariables} | ${moveIssueMutationHandlerSuccess} | ${moveEpicMutationHandlerSuccess}
      ${TYPE_EPIC}  | ${true}     | ${endDragEpicVariables}  | ${moveEpicMutationHandlerSuccess}  | ${moveIssueMutationHandlerSuccess}
    `(
      'moves $issuableType between lists',
      async ({ issuableType, isEpicBoard, queryHandler, notCalledHandler, endDragVariables }) => {
        wrapper = createComponent({
          provide: {
            boardType: NAMESPACE_GROUP,
            issuableType,
            isProjectBoard: false,
            isGroupBoard: true,
            isEpicBoard,
          },
          apolloQueryHandlers,
          stubs: {
            BoardCardMoveToPosition,
          },
        });

        await waitForPromises();

        endDrag(endDragVariables);

        await waitForPromises();

        expect(queryHandler).toHaveBeenCalledWith(
          expect.objectContaining({
            ...(isEpicBoard
              ? {
                  epicId: endDragVariables.item.dataset.itemId,
                }
              : {
                  iid: endDragVariables.item.dataset.itemIid,
                  projectPath: endDragVariables.item.dataset.itemPath.split(/[#]/)[0],
                }),
          }),
        );
        expect(notCalledHandler).not.toHaveBeenCalled();
      },
    );

    it.each`
      issuableType  | isEpicBoard | endDragVariables
      ${TYPE_ISSUE} | ${false}    | ${endDragIssueVariables}
      ${TYPE_EPIC}  | ${true}     | ${endDragEpicVariables}
    `(
      'sets error when moving $issuableType between lists fails',
      async ({ issuableType, isEpicBoard, endDragVariables }) => {
        wrapper = createComponent({
          provide: {
            boardType: NAMESPACE_GROUP,
            issuableType,
            isProjectBoard: false,
            isGroupBoard: true,
            isEpicBoard,
          },
          apolloQueryHandlers: [
            [listIssuesQuery, groupIssuesQueryHandlerSuccess],
            [listEpicsQuery, groupEpicsQueryHandlerSuccess],
            [issueMoveListMutation, queryHandlerFailure],
            [epicMoveListMutation, queryHandlerFailure],
          ],
        });

        await waitForPromises();

        endDrag(endDragVariables);

        await waitForPromises();

        expect(cacheUpdates.setError).toHaveBeenCalled();
      },
    );

    it.each`
      issuableType  | isEpicBoard | positionInList | queryHandler                       | notCalledHandler
      ${TYPE_ISSUE} | ${false}    | ${-1}          | ${moveIssueMutationHandlerSuccess} | ${moveEpicMutationHandlerSuccess}
      ${TYPE_EPIC}  | ${true}     | ${-1}          | ${moveEpicMutationHandlerSuccess}  | ${moveIssueMutationHandlerSuccess}
    `(
      'moves $issuableType at bottom of list',
      async ({ issuableType, isEpicBoard, queryHandler, notCalledHandler, positionInList }) => {
        wrapper = createComponent({
          provide: {
            boardType: NAMESPACE_GROUP,
            issuableType,
            isProjectBoard: false,
            isGroupBoard: true,
            isEpicBoard,
          },
          apolloQueryHandlers,
        });

        await waitForPromises();

        wrapper.findComponent(BoardCardMoveToPosition).vm.$emit('move-to-position', positionInList);

        await waitForPromises();

        expect(queryHandler).toHaveBeenCalled();
        expect(notCalledHandler).not.toHaveBeenCalled();
      },
    );

    it.each`
      issuableType  | isEpicBoard | positionInList
      ${TYPE_ISSUE} | ${false}    | ${-1}
      ${TYPE_EPIC}  | ${true}     | ${-1}
    `(
      'sets error when moving $issuableType at bottom of list fails',
      async ({ issuableType, isEpicBoard, positionInList }) => {
        wrapper = createComponent({
          provide: {
            boardType: NAMESPACE_GROUP,
            issuableType,
            isProjectBoard: false,
            isGroupBoard: true,
            isEpicBoard,
          },
          apolloQueryHandlers: [
            [listIssuesQuery, groupIssuesQueryHandlerSuccess],
            [listEpicsQuery, groupEpicsQueryHandlerSuccess],
            [issueMoveListMutation, queryHandlerFailure],
            [epicMoveListMutation, queryHandlerFailure],
          ],
        });

        await waitForPromises();

        wrapper.findComponent(BoardCardMoveToPosition).vm.$emit('move-to-position', positionInList);

        await waitForPromises();

        expect(cacheUpdates.setError).toHaveBeenCalled();
      },
    );

    it.each`
      issuableType  | isEpicBoard | queryHandler                         | notCalledHandler                     | component        | event              | listId
      ${TYPE_ISSUE} | ${false}    | ${createIssueMutationHandlerSuccess} | ${createEpicMutationHandlerSuccess}  | ${BoardNewIssue} | ${'add-new-issue'} | ${mockList.id}
      ${TYPE_EPIC}  | ${true}     | ${createEpicMutationHandlerSuccess}  | ${createIssueMutationHandlerSuccess} | ${BoardNewEpic}  | ${'add-new-epic'}  | ${'gid://gitlab/Boards::EpicList/5'}
    `(
      'creates $issuableType',
      async ({
        issuableType,
        isEpicBoard,
        queryHandler,
        notCalledHandler,
        component,
        event,
        listId,
      }) => {
        wrapper = createComponent({
          listProps: {
            id: listId,
          },
          componentProps: { showNewForm: true },
          provide: {
            boardType: NAMESPACE_GROUP,
            issuableType,
            isProjectBoard: false,
            isGroupBoard: true,
            isEpicBoard,
          },
          apolloQueryHandlers,
          stubs: {
            BoardNewIssue,
            BoardNewEpic,
          },
        });

        await waitForPromises();

        expect(wrapper.findComponent(component).exists()).toBe(true);
        wrapper.findComponent(component).vm.$emit(event, { title: 'Foo' });

        await nextTick();

        expect(queryHandler).toHaveBeenCalled();
        expect(notCalledHandler).not.toHaveBeenCalled();
      },
    );

    it.each`
      issuableType  | isEpicBoard | component        | event              | listId
      ${TYPE_ISSUE} | ${false}    | ${BoardNewIssue} | ${'add-new-issue'} | ${mockList.id}
      ${TYPE_EPIC}  | ${true}     | ${BoardNewEpic}  | ${'add-new-epic'}  | ${'gid://gitlab/Boards::EpicList/5'}
    `(
      'sets error when creating $issuableType fails',
      async ({ issuableType, isEpicBoard, component, event, listId }) => {
        wrapper = createComponent({
          listProps: {
            id: listId,
          },
          componentProps: { showNewForm: true },
          provide: {
            boardType: NAMESPACE_GROUP,
            issuableType,
            isProjectBoard: false,
            isGroupBoard: true,
            isEpicBoard,
          },
          apolloQueryHandlers: [
            [listIssuesQuery, groupIssuesQueryHandlerSuccess],
            [listEpicsQuery, groupEpicsQueryHandlerSuccess],
            [issueCreateMutation, queryHandlerFailure],
            [epicCreateMutation, queryHandlerFailure],
          ],
          stubs: {
            BoardNewIssue,
            BoardNewEpic,
          },
        });

        await waitForPromises();

        expect(wrapper.findComponent(component).exists()).toBe(true);
        wrapper.findComponent(component).vm.$emit(event, { title: 'Foo' });

        await waitForPromises();

        expect(cacheUpdates.setError).toHaveBeenCalled();
      },
    );

    describe('when dragging between applicable status lists', () => {
      beforeEach(async () => {
        wrapper = createComponent({
          listProps: {
            id: 'gid://gitlab/List/5',
          },
          componentProps: {
            draggedItemId: 'gid://gitlab/WorkItems::Type/1',
          },
          provide: {
            boardType: NAMESPACE_PROJECT,
            isProjectBoard: true,
            isGroupBoard: false,
          },
          apolloQueryHandlers,
        });

        await waitForPromises();
      });

      it('should not mark the list as inapplicable', () => {
        expect(wrapper.classes()).not.toContain('board-column-not-applicable');
        expect(wrapper.find('.board-column-not-applicable-content').exists()).toBe(false);
      });

      it('should not show inapplicable message', () => {
        expect(wrapper.find('.board-column-not-applicable-content').exists()).toBe(false);
      });
    });

    describe('when dragging between in applicable status lists', () => {
      beforeEach(async () => {
        wrapper = createComponent({
          listProps: {
            id: 'gid://gitlab/List/5',
            status: {
              id: 'gid://gitlab/status/1',
              name: 'Open',
            },
            listType: ListType.status,
          },
          componentProps: {
            draggedItemId: 'gid://gitlab/WorkItems::Type/2',
          },
          provide: {
            boardType: NAMESPACE_PROJECT,
            isProjectBoard: true,
            isGroupBoard: false,
          },
          apolloQueryHandlers,
        });

        await waitForPromises();
        startDrag();

        await nextTick();
      });

      it('should mark the list as inapplicable', () => {
        expect(wrapper.classes()).toContain('board-column-not-applicable');
        expect(wrapper.find('.board-column-not-applicable-content').exists()).toBe(true);
      });

      it('should show inapplicable message', () => {
        expect(wrapper.find('.board-column-not-applicable-content').exists()).toBe(true);
      });
    });
  });
});
