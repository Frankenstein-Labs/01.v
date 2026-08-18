import { GlIntersectionObserver } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VirtualList from 'vue-virtual-scroll-list';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import * as BoardUtils from 'ee/boards/boards_util';
import EpicLane from 'ee/boards/components/epic_lane.vue';
import EpicsSwimlanes from 'ee/boards/components/epics_swimlanes.vue';
import IssueLaneList from 'ee/boards/components/issues_lane_list.vue';
import SwimlanesLoadingSkeleton from 'ee/boards/components/swimlanes_loading_skeleton.vue';
import { EPIC_LANE_BASE_HEIGHT } from 'ee/boards/constants';
import epicsSwimlanesQuery from 'ee/boards/graphql/epics_swimlanes.query.graphql';
import BoardListHeader from 'ee_else_ce/boards/components/board_list_header.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Draggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { mockLists, mockEpics, mockEpic, mockEpicSwimlanesResponse } from '../mock_data';

Vue.use(VueApollo);
jest.mock('ee/boards/boards_util');

describe('EpicsSwimlanes', () => {
  let wrapper;
  let mockApollo;
  const bufferSize = 100;

  const findDraggable = () => wrapper.findComponent(Draggable);
  const findLoadMoreEpicsButton = () => wrapper.findComponentByTestId('load-more-epics');
  const findUnassignedLaneList = () => wrapper.findComponent(IssueLaneList);
  const findLaneUnassignedIssues = () => wrapper.findByTestId('board-lane-unassigned-issues-title');
  const findToggleUnassignedLaneButton = () =>
    wrapper.findComponentByTestId('unassigned-lane-toggle');
  const findLoadMoreIssuesButton = () => wrapper.findByTestId('board-lane-load-more-issues-button');
  const findLoadingSkeleton = () => wrapper.findComponent(SwimlanesLoadingSkeleton);
  const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

  const epicsSwimlanesQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(mockEpicSwimlanesResponse());
  const errorMessage = 'Failed to fetch issues';
  const epicsSwimlanesQueryHandlerFailure = jest.fn().mockRejectedValue(new Error(errorMessage));

  const createComponent = ({
    canAdminList = false,
    epicsSwimlanesQueryHandler = epicsSwimlanesQueryHandlerSuccess,
  } = {}) => {
    mockApollo = createMockApollo(
      [[epicsSwimlanesQuery, epicsSwimlanesQueryHandler]],
      {},
      {
        typePolicies: {
          Group: {
            fields: {
              board: {
                merge: true,
              },
            },
          },
        },
      },
    );
    const defaultProps = {
      lists: mockLists,
      boardId: 'gid://gitlab/Board/1',
    };

    wrapper = shallowMountExtended(EpicsSwimlanes, {
      propsData: { ...defaultProps, canAdminList, filters: {} },
      apolloProvider: mockApollo,
      provide: {
        fullPath: 'gitlab-org',
        boardType: 'group',
        disabled: false,
      },
    });
  };

  beforeEach(() => {
    jest.spyOn(BoardUtils, 'calculateSwimlanesBufferSize').mockReturnValue(bufferSize);
    cacheUpdates.setError = jest.fn();
  });

  afterEach(() => {
    mockApollo = null;
  });

  describe('reorder lists', () => {
    describe('when canAdminList prop is true', () => {
      beforeEach(async () => {
        createComponent({ canAdminList: true });
        await waitForPromises();
      });

      it('should return Draggable reference when canAdminList prop is true', () => {
        expect(findDraggable().exists()).toBe(true);
      });

      it('emits move-list event when drag & dropping list', async () => {
        findDraggable().vm.$emit('end', { oldIndex: 1, newIndex: 0 });
        await nextTick();

        expect(wrapper.emitted('move-list')).toEqual([[{ oldIndex: 1, newIndex: 0 }]]);
      });
    });

    describe('when canAdminList prop is false', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should not return Draggable reference when canAdminList prop is false', () => {
        expect(findDraggable().exists()).toBe(false);
      });
    });
  });

  describe('template', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('displays BoardListHeader components for lists', () => {
      expect(wrapper.findAllComponents(BoardListHeader)).toHaveLength(4);
    });

    it('does not display IssueLaneList component by default', () => {
      expect(findUnassignedLaneList().exists()).toBe(false);
    });

    it('renders virtual-list', () => {
      const scrollableContainer = wrapper.findComponent({ ref: 'scrollableContainer' }).element;

      expect(BoardUtils.calculateSwimlanesBufferSize).toHaveBeenCalledWith(
        wrapper.element.offsetTop,
      );

      expect(wrapper.findComponent(VirtualList).props()).toMatchObject({
        remain: bufferSize,
        bench: bufferSize,
        size: EPIC_LANE_BASE_HEIGHT,
      });
      expect(wrapper.findComponent(VirtualList).props('scrollelement')).toBe(scrollableContainer);
    });

    it('renders epic lanes', () => {
      expect(wrapper.findAllComponents(EpicLane)).toHaveLength(mockEpics.length);
    });

    it('does not display load more epics button if there are no more epics', () => {
      expect(findLoadMoreEpicsButton().exists()).toBe(false);
    });

    it('displays IssueLaneList component when toggling unassigned issues lane', async () => {
      expect(findLaneUnassignedIssues().classes()).not.toContain('board-epic-lane-shadow');
      findToggleUnassignedLaneButton().vm.$emit('click');

      await nextTick();

      expect(findLaneUnassignedIssues().classes()).toContain('board-epic-lane-shadow');
      expect(findUnassignedLaneList().exists()).toBe(true);
    });

    it('makes non preset lists draggable', () => {
      expect(wrapper.findAll('[data-testid="board-header-container"]').at(1).classes()).toContain(
        'is-draggable',
      );
    });

    it('does not make preset lists draggable', () => {
      expect(
        wrapper.findAll('[data-testid="board-header-container"]').at(0).classes(),
      ).not.toContain('is-draggable');
    });
    describe('unassigned issues lane', () => {
      it('adds a shadow to the unassigned issues lane header when the intersection observer is hidden', async () => {
        expect(findLaneUnassignedIssues().classes()).not.toContain('show');
        findIntersectionObserver().vm.$emit('disappear');

        await nextTick();
        expect(findLaneUnassignedIssues().classes()).toContain('show');
      });
    });
  });

  describe('load more epics', () => {
    const queryLoadMoreHandler = jest.fn();

    beforeEach(async () => {
      queryLoadMoreHandler.mockResolvedValueOnce(mockEpicSwimlanesResponse({ hasNextPage: true }));
      queryLoadMoreHandler.mockResolvedValueOnce(
        mockEpicSwimlanesResponse({
          epics: [
            {
              ...mockEpic,
              id: 'gid://gitlab/Epic/417',
              userPreferences: {
                collapsed: false,
              },
            },
          ],
        }),
      );
      createComponent({ epicsSwimlanesQueryHandler: queryLoadMoreHandler });
      await waitForPromises();
    });

    it('fetches more epics on click on Load more epics button', async () => {
      expect(findLoadMoreEpicsButton().exists()).toBe(true);
      findLoadMoreEpicsButton().vm.$emit('click');

      await waitForPromises();

      expect(queryLoadMoreHandler).toHaveBeenCalledTimes(2);
    });
  });

  it('displays loading skeleton while data is loading', async () => {
    createComponent();

    expect(findLoadingSkeleton().exists()).toBe(true);

    await waitForPromises();

    expect(findLoadingSkeleton().exists()).toBe(false);
  });

  describe('Queries', () => {
    beforeEach(async () => {
      createComponent({ canAdminList: true });
      await waitForPromises();
    });

    it('fetches epics swimlanes with includeSubepics set to false', () => {
      expect(epicsSwimlanesQueryHandlerSuccess).toHaveBeenCalledWith({
        boardId: 'gid://gitlab/Board/1',
        fullPath: 'gitlab-org',
        isGroup: true,
        isProject: false,
        issueFilters: { includeSubepics: false },
        sort: 'TITLE_ASC',
      });
    });

    it('emits move-list event on reordering lists', () => {
      findDraggable().vm.$emit('end', {});

      expect(wrapper.emitted('move-list')).toHaveLength(1);
    });

    describe('unassigned issues lane', () => {
      it('load more issues button does not display when all issues are loaded', async () => {
        expect(findUnassignedLaneList().exists()).toBe(false);
        expect(findLaneUnassignedIssues().exists()).toBe(true);

        findToggleUnassignedLaneButton().vm.$emit('click');

        await nextTick();

        expect(findUnassignedLaneList().exists()).toBe(true);
        expect(findLoadMoreIssuesButton().exists()).toBe(false);
      });

      it('load more issues button displays when there are more issues to load', async () => {
        findToggleUnassignedLaneButton().vm.$emit('click');
        await nextTick();

        wrapper
          .findComponent(IssueLaneList)
          .vm.$emit('update-page-info', { hasNextPage: true, endCursor: 'xyz' }, mockLists[0].id);

        await nextTick();

        expect(findLoadMoreIssuesButton().exists()).toBe(true);
      });
    });

    it('sets error when fetch epics swimlanes query fails', async () => {
      createComponent({
        canAdminList: true,
        epicsSwimlanesQueryHandler: epicsSwimlanesQueryHandlerFailure,
      });
      await waitForPromises();

      expect(cacheUpdates.setError).toHaveBeenCalled();
    });
  });
});
