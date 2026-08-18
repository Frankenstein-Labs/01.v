import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';

import IssueBoardFilteredSearch from 'ee/boards/components/issue_board_filtered_search.vue';
import EpicBoardFilteredSearch from 'ee/boards/components/epic_filtered_search.vue';

import BoardTopBar from '~/boards/components/board_top_bar.vue';
import BoardOptions from '~/boards/components/board_options.vue';
import BoardsSelector from '~/boards/components/boards_selector.vue';
import ConfigToggle from '~/boards/components/config_toggle.vue';
import ToggleFocus from '~/boards/components/toggle_focus.vue';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';

import groupBoardQuery from '~/boards/graphql/group_board.query.graphql';
import projectBoardQuery from '~/boards/graphql/project_board.query.graphql';
import { mockProjectBoardResponse, mockGroupBoardResponse } from 'jest/boards/mock_data';
import epicBoardQuery from 'ee_component/boards/graphql/epic_board.query.graphql';
import { mockEpicBoardResponse } from '../mock_data';

Vue.use(VueApollo);

describe('BoardTopBar', () => {
  let wrapper;
  let mockApollo;

  const projectBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockProjectBoardResponse);
  const groupBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupBoardResponse);
  const epicBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockEpicBoardResponse);

  const createComponent = ({ provide = {} } = {}) => {
    mockApollo = createMockApollo([
      [projectBoardQuery, projectBoardQueryHandlerSuccess],
      [groupBoardQuery, groupBoardQueryHandlerSuccess],
      [epicBoardQuery, epicBoardQueryHandlerSuccess],
    ]);

    wrapper = shallowMount(BoardTopBar, {
      apolloProvider: mockApollo,
      propsData: {
        boardId: 'gid://gitlab/Board/1',
        isSwimlanesOn: false,
        addColumnFormVisible: false,
        filters: {},
      },
      provide: {
        swimlanesFeatureAvailable: false,
        canAdminList: false,
        isSignedIn: false,
        fullPath: 'gitlab-org',
        boardType: 'group',
        releasesFetchPath: '/releases',
        epicFeatureAvailable: true,
        iterationFeatureAvailable: true,
        healthStatusFeatureAvailable: true,
        hasCustomFieldsFeature: true,
        isIssueBoard: true,
        isEpicBoard: false,
        isGroupBoard: true,
        statusListsAvailable: true,
        hasStatusFeature: true,
        ...provide,
      },
      stubs: { IssueBoardFilteredSearch, EpicBoardFilteredSearch },
    });
  };

  afterEach(() => {
    mockApollo = null;
  });

  describe('base template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders BoardsSelector component', () => {
      expect(wrapper.findComponent(BoardsSelector).exists()).toBe(true);
    });

    it('renders ConfigToggle component', () => {
      expect(wrapper.findComponent(ConfigToggle).exists()).toBe(true);
    });

    it('renders ToggleFocus component', () => {
      expect(wrapper.findComponent(ToggleFocus).exists()).toBe(true);
    });

    it('renders BoardOptions component', () => {
      expect(wrapper.findComponent(BoardOptions).exists()).toBe(true);
    });
  });

  describe('filter bar', () => {
    it.each`
      isIssueBoard | filterBarComponent          | filterBarName                 | otherFilterBar
      ${true}      | ${IssueBoardFilteredSearch} | ${'IssueBoardFilteredSearch'} | ${EpicBoardFilteredSearch}
      ${false}     | ${EpicBoardFilteredSearch}  | ${'EpicBoardFilteredSearch'}  | ${IssueBoardFilteredSearch}
    `(
      'renders $filterBarName when isIssueBoard is $isIssueBoard',
      async ({ isIssueBoard, filterBarComponent, otherFilterBar }) => {
        createComponent({ provide: { isIssueBoard } });

        await nextTick();

        expect(wrapper.findComponent(filterBarComponent).exists()).toBe(true);
        expect(wrapper.findComponent(otherFilterBar).exists()).toBe(false);
      },
    );
  });

  it.each`
    boardType            | isEpicBoard | queryHandler                       | notCalledHandler
    ${NAMESPACE_GROUP}   | ${false}    | ${groupBoardQueryHandlerSuccess}   | ${projectBoardQueryHandlerSuccess}
    ${NAMESPACE_PROJECT} | ${false}    | ${projectBoardQueryHandlerSuccess} | ${groupBoardQueryHandlerSuccess}
    ${NAMESPACE_GROUP}   | ${true}     | ${epicBoardQueryHandlerSuccess}    | ${groupBoardQueryHandlerSuccess}
  `(
    'fetches $boardType boards when isEpicBoard is $isEpicBoard',
    async ({ boardType, isEpicBoard, queryHandler, notCalledHandler }) => {
      createComponent({
        provide: {
          boardType,
          isProjectBoard: boardType === NAMESPACE_PROJECT,
          isGroupBoard: boardType === NAMESPACE_GROUP,
          isEpicBoard,
        },
      });

      await nextTick();

      expect(queryHandler).toHaveBeenCalled();
      expect(notCalledHandler).not.toHaveBeenCalled();
    },
  );
});
