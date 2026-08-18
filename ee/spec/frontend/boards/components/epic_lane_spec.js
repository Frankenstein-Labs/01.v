import { GlButton, GlIcon, GlIntersectionObserver, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import listsIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import EpicLane from 'ee/boards/components/epic_lane.vue';
import IssuesLaneList from 'ee/boards/components/issues_lane_list.vue';
import updateBoardEpicUserPreferencesMutation from 'ee/boards/graphql/update_board_epic_user_preferences.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockEpic, mockLists, mockGroupIssuesResponse } from '../mock_data';

Vue.use(VueApollo);

describe('EpicLane', () => {
  let wrapper;
  let mockApollo;

  const findChevronButton = () => wrapper.findComponent(GlButton);
  const findIssuesLaneLists = () => wrapper.findAllComponents(IssuesLaneList);
  const findEpicLane = () => wrapper.findByTestId('board-epic-lane');
  const findEpicLaneIssueCount = () => wrapper.findByTestId('epic-lane-issue-count');
  const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

  const listIssuesQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupIssuesResponse());
  const errorMessage = 'Failed to fetch issues';
  const listIssuesQueryHandlerFailure = jest.fn().mockRejectedValue(new Error(errorMessage));
  const updateEpicPreferencesMutationHandler = jest.fn();

  const createComponent = ({
    props = {},
    listIssuesQueryHandler = listIssuesQueryHandlerSuccess,
  } = {}) => {
    mockApollo = createMockApollo([
      [listsIssuesQuery, listIssuesQueryHandler],
      [updateBoardEpicUserPreferencesMutation, updateEpicPreferencesMutationHandler],
    ]);

    const defaultProps = {
      epic: mockEpic,
      lists: mockLists,
      boardId: 'gid://gitlab/Board/1',
      filterParams: {},
      totalIssuesCountByListId: {},
    };

    wrapper = shallowMountExtended(EpicLane, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      apolloProvider: mockApollo,
      provide: {
        fullPath: 'gitlab-org',
        boardType: 'group',
      },
    });
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  describe('template', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('has the right CSS class applied to the epic lane header', () => {
      expect(findEpicLane().classes()).toContain('board-epic-lane-shadow');
    });

    it('adds a shadow to the epic lane header when the intersection observer is hidden', async () => {
      expect(findEpicLane().classes()).not.toContain('show');
      findIntersectionObserver().vm.$emit('disappear');

      await nextTick();
      expect(findEpicLane().classes()).toContain('show');
    });

    it('displays count of issues in epic which belong to board', () => {
      expect(findEpicLaneIssueCount().text()).toContain('1');
    });

    it('displays 1 icon', () => {
      expect(wrapper.findAllComponents(GlIcon)).toHaveLength(1);
    });

    it('displays epic title', () => {
      expect(wrapper.text()).toContain(mockEpic.title);
    });

    it('renders one IssuesLaneList component per list passed in props passing lists as props', () => {
      expect(findIssuesLaneLists()).toHaveLength(wrapper.props('lists').length);
      expect(wrapper.findComponent(IssuesLaneList).props('lists')).toEqual(wrapper.props('lists'));
    });

    it('hides issues when collapsing', async () => {
      expect(findIssuesLaneLists()).toHaveLength(wrapper.props('lists').length);
      expect(wrapper.vm.isCollapsed).toBe(false);

      findChevronButton().vm.$emit('click');

      await nextTick();
      expect(findIssuesLaneLists()).toHaveLength(0);
      expect(wrapper.vm.isCollapsed).toBe(true);
    });

    it('does not display loading icon when issues are not loading', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(false);
    });

    it('displays loading icon and hides issues count when issues are loading', () => {
      createComponent({ isLoading: true });
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(findEpicLaneIssueCount().exists()).toBe(false);
    });

    it('updates epic user preferences on collapse', async () => {
      createComponent();

      await waitForPromises();

      const collapsedValue = false;

      expect(findEpicLane().classes()).toContain('board-epic-lane-shadow');
      expect(findIssuesLaneLists()).toHaveLength(wrapper.props('lists').length);

      findChevronButton().vm.$emit('click');

      await waitForPromises();
      expect(updateEpicPreferencesMutationHandler).toHaveBeenCalledWith({
        boardId: 'gid://gitlab/Board/1',
        collapsed: !collapsedValue,
        epicId: mockEpic.id,
      });

      expect(findEpicLane().classes()).not.toContain('board-epic-lane-shadow');
      expect(findIssuesLaneLists()).toHaveLength(0);
    });

    it('does not render when issuesCount is 0', async () => {
      createComponent({
        listIssuesQueryHandler: jest
          .fn()
          .mockResolvedValue(mockGroupIssuesResponse('gid://gitlab/List/1', [])),
      });
      await waitForPromises();
      expect(findEpicLane().exists()).toBe(false);
    });
  });

  describe('queries', () => {
    it('fetches list issues', async () => {
      createComponent();

      await nextTick();
      expect(listIssuesQueryHandlerSuccess).toHaveBeenCalled();
    });

    it('fetches list issues with includeSubepics set to false', async () => {
      createComponent();

      await nextTick();
      expect(listIssuesQueryHandlerSuccess).toHaveBeenCalledWith(
        expect.objectContaining({
          filters: expect.objectContaining({
            epicId: mockEpic.id,
            includeSubepics: false,
          }),
        }),
      );
    });

    it('sets error when list issues query fails', async () => {
      createComponent({
        listIssuesQueryHandler: listIssuesQueryHandlerFailure,
      });

      await waitForPromises();
      expect(cacheUpdates.setError).toHaveBeenCalled();
    });
  });
});
