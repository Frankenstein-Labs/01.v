import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import BoardsSelector from 'ee/boards/components/boards_selector.vue';
import epicBoardsQuery from 'ee/boards/graphql/epic_boards.query.graphql';
import groupBoardsQuery from '~/boards/graphql/group_boards.query.graphql';
import projectBoardsQuery from '~/boards/graphql/project_boards.query.graphql';
import groupRecentBoardsQuery from '~/boards/graphql/group_recent_boards.query.graphql';
import projectRecentBoardsQuery from '~/boards/graphql/project_recent_boards.query.graphql';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import { TEST_HOST } from 'spec/test_constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockBoard,
  mockGroupAllBoardsResponse,
  mockProjectAllBoardsResponse,
  mockProjectRecentBoardsResponse,
  mockGroupRecentBoardsResponse,
} from 'jest/boards/mock_data';
import { mockEpicBoardsResponse } from '../mock_data';

const throttleDuration = 1;

Vue.use(VueApollo);

describe('BoardsSelector', () => {
  let wrapper;
  let fakeApollo;

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);

  const projectBoardsQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(mockProjectAllBoardsResponse);
  const groupBoardsQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupAllBoardsResponse);
  const epicBoardsQueryHandlerSuccess = jest.fn().mockResolvedValue(mockEpicBoardsResponse);

  const projectRecentBoardsQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(mockProjectRecentBoardsResponse);
  const groupRecentBoardsQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(mockGroupRecentBoardsResponse);

  const boardsHandlerFailure = jest.fn().mockRejectedValue(new Error('error'));

  const createComponent = ({
    isEpicBoard = false,
    isGroupBoard = false,
    isProjectBoard = false,
    projectBoardsQueryHandler = projectBoardsQueryHandlerSuccess,
    groupBoardsQueryHandler = groupBoardsQueryHandlerSuccess,
    epicBoardsQueryHandler = epicBoardsQueryHandlerSuccess,
  }) => {
    fakeApollo = createMockApollo([
      [projectBoardsQuery, projectBoardsQueryHandler],
      [groupBoardsQuery, groupBoardsQueryHandler],
      [epicBoardsQuery, epicBoardsQueryHandler],
      [projectRecentBoardsQuery, projectRecentBoardsQueryHandlerSuccess],
      [groupRecentBoardsQuery, groupRecentBoardsQueryHandlerSuccess],
    ]);

    wrapper = shallowMount(BoardsSelector, {
      apolloProvider: fakeApollo,
      propsData: {
        throttleDuration,
        board: mockBoard,
      },
      attachTo: document.body,
      provide: {
        fullPath: '',
        boardBaseUrl: `${TEST_HOST}/board/base/url`,
        hasMissingBoards: false,
        canAdminBoard: true,
        multipleIssueBoardsAvailable: true,
        scopedIssueBoardFeatureEnabled: true,
        weights: [],
        isEpicBoard,
        boardType: isGroupBoard ? NAMESPACE_GROUP : NAMESPACE_PROJECT,
        isGroupBoard,
        isProjectBoard,
      },
    });
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('fetching all boards', () => {
    it.each`
      boardType            | isEpicBoard | queryHandler                        | notCalledHandler
      ${NAMESPACE_GROUP}   | ${false}    | ${groupBoardsQueryHandlerSuccess}   | ${projectBoardsQueryHandlerSuccess}
      ${NAMESPACE_PROJECT} | ${false}    | ${projectBoardsQueryHandlerSuccess} | ${groupBoardsQueryHandlerSuccess}
      ${NAMESPACE_GROUP}   | ${true}     | ${epicBoardsQueryHandlerSuccess}    | ${groupBoardsQueryHandlerSuccess}
    `(
      'fetches $boardType boards when isEpicBoard is $isEpicBoard',
      async ({ boardType, isEpicBoard, queryHandler, notCalledHandler }) => {
        createComponent({
          isEpicBoard,
          isProjectBoard: boardType === NAMESPACE_PROJECT,
          isGroupBoard: boardType === NAMESPACE_GROUP,
        });

        await nextTick();

        // Emits gl-listbox shown event to simulate the dropdown is opened at initialization time
        findDropdown().vm.$emit('shown');

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
      'sets error when fetching $boardType boards when isEpicBoard is $isEpicBoard fails',
      async ({ boardType, isEpicBoard }) => {
        createComponent({
          isEpicBoard,
          isProjectBoard: boardType === NAMESPACE_PROJECT,
          isGroupBoard: boardType === NAMESPACE_GROUP,
          projectBoardsQueryHandler: boardsHandlerFailure,
          groupBoardsQueryHandler: boardsHandlerFailure,
          epicBoardsQueryHandler: boardsHandlerFailure,
        });

        await nextTick();

        // Emits gl-listbox shown event to simulate the dropdown is opened at initialization time
        findDropdown().vm.$emit('shown');

        await waitForPromises();

        expect(cacheUpdates.setError).toHaveBeenCalled();
      },
    );
  });
});
