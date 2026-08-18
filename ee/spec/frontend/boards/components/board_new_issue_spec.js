import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import BoardNewIssue from 'ee/boards/components/board_new_issue.vue';
import currentIterationQuery from 'ee/boards/graphql/board_current_iteration.query.graphql';
import BoardNewItem from '~/boards/components/board_new_item.vue';
import groupBoardQuery from '~/boards/graphql/group_board.query.graphql';

import {
  mockList,
  mockGroupProjects,
  mockGroupBoardResponse,
  mockStatusList,
} from 'jest/boards/mock_data';
import {
  mockGroupBoardCurrentIterationResponse,
  mockGroupBoardNoIterationResponse,
  currentIterationQueryResponse,
  currentIterationQueryResponseWithoutCadence,
  currentIterationQueryEmptyResponse,
} from '../mock_data';

Vue.use(VueApollo);

const groupBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupBoardResponse);
const currentIterationBoardQueryHandlerSuccess = jest
  .fn()
  .mockResolvedValue(mockGroupBoardCurrentIterationResponse);
const noIterationBoardQueryHandlerSuccess = jest
  .fn()
  .mockResolvedValue(mockGroupBoardNoIterationResponse);
const currentIterationQueryHandlerSuccess = jest
  .fn()
  .mockResolvedValue(currentIterationQueryResponse);

const createComponent = ({
  isGroupBoard = true,
  data = { selectedProject: mockGroupProjects[0] },
  provide = {},
  boardQueryHandler = groupBoardQueryHandlerSuccess,
  iterationQueryHandler = currentIterationQueryHandlerSuccess,
  list = mockList,
} = {}) => {
  const mockApollo = createMockApollo([
    [groupBoardQuery, boardQueryHandler],
    [currentIterationQuery, iterationQueryHandler],
  ]);
  return shallowMount(BoardNewIssue, {
    apolloProvider: mockApollo,
    propsData: {
      list,
      boardId: 'gid://gitlab/Board/1',
    },
    data: () => data,
    provide: {
      groupId: 1,
      fullPath: mockGroupProjects[0].fullPath,
      weightFeatureAvailable: false,
      boardWeight: null,
      isGroupBoard,
      boardType: isGroupBoard ? 'group' : 'project',
      isEpicBoard: false,
      ...provide,
    },
    stubs: {
      BoardNewItem,
    },
  });
};

describe('Issue boards new issue form', () => {
  let wrapper;

  const findBoardNewItem = () => wrapper.findComponent(BoardNewItem);

  it('does not fetch current iteration and cadence by default', async () => {
    wrapper = createComponent();

    await nextTick();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await nextTick();
    expect(currentIterationQueryHandlerSuccess).not.toHaveBeenCalled();
  });

  it('fetches current iteration and cadence when board scope is set to current iteration without a cadence', async () => {
    wrapper = createComponent({
      boardQueryHandler: currentIterationBoardQueryHandlerSuccess,
      data: {
        selectedProject: mockGroupProjects[0],
        board: { iteration: { id: 'gid://gitlab/Iteration/-4' }, iterationCadence: {} },
      },
    });

    await waitForPromises();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await waitForPromises();
    expect(currentIterationQueryHandlerSuccess).toHaveBeenCalled();
    expect(wrapper.emitted('add-new-issue')).toEqual([
      [
        expect.objectContaining({
          iterationCadenceId: 'gid://gitlab/Iterations::Cadence/1',
          iterationWildcardId: 'CURRENT',
        }),
      ],
    ]);
  });

  describe('when board is scoped to the current iteration', () => {
    const currentIterationBoardData = {
      selectedProject: mockGroupProjects[0],
      board: { iteration: { id: 'gid://gitlab/Iteration/-4' }, iterationCadence: {} },
    };

    it('uses the already-loaded cadence without refetching the query', async () => {
      const iterationQueryHandler = jest.fn().mockResolvedValue(currentIterationQueryResponse);
      wrapper = createComponent({
        boardQueryHandler: currentIterationBoardQueryHandlerSuccess,
        iterationQueryHandler,
        data: currentIterationBoardData,
      });

      await waitForPromises();
      findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

      await waitForPromises();
      expect(iterationQueryHandler).toHaveBeenCalledTimes(1);
      expect(wrapper.emitted('add-new-issue')[0][0]).toMatchObject({
        iterationCadenceId: 'gid://gitlab/Iterations::Cadence/1',
        iterationWildcardId: 'CURRENT',
      });
    });

    it('refetches the cadence when it is not yet available and creates the issue', async () => {
      const iterationQueryHandler = jest
        .fn()
        .mockResolvedValueOnce(currentIterationQueryResponseWithoutCadence)
        .mockResolvedValueOnce(currentIterationQueryResponse);
      wrapper = createComponent({
        boardQueryHandler: currentIterationBoardQueryHandlerSuccess,
        iterationQueryHandler,
        data: currentIterationBoardData,
      });

      await waitForPromises();
      findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

      await waitForPromises();
      expect(iterationQueryHandler).toHaveBeenCalledTimes(2);
      expect(wrapper.emitted('add-new-issue')[0][0]).toMatchObject({
        iterationCadenceId: 'gid://gitlab/Iterations::Cadence/1',
        iterationWildcardId: 'CURRENT',
      });
    });

    it('does not create the issue when the cadence cannot be resolved even after refetching', async () => {
      const iterationQueryHandler = jest.fn().mockResolvedValue(currentIterationQueryEmptyResponse);
      wrapper = createComponent({
        boardQueryHandler: currentIterationBoardQueryHandlerSuccess,
        iterationQueryHandler,
        data: currentIterationBoardData,
      });

      await waitForPromises();
      findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

      await waitForPromises();
      expect(iterationQueryHandler).toHaveBeenCalledTimes(2);
      expect(wrapper.emitted('add-new-issue')).toBeUndefined();
    });
  });

  it('excludes iteration when board is scoped to No iteration', async () => {
    wrapper = createComponent({ boardQueryHandler: noIterationBoardQueryHandlerSuccess });

    await waitForPromises();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await waitForPromises();

    expect(wrapper.emitted('add-new-issue')).toEqual([
      [
        expect.not.objectContaining({
          iterationWildcardId: null,
          iterationId: null,
          iterationCadenceId: null,
        }),
      ],
    ]);
  });

  it('does not add the `statusId` argument to new issue create mutation if not a status list', async () => {
    wrapper = createComponent();

    await waitForPromises();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await waitForPromises();
    expect(wrapper.emitted('add-new-issue')[0]).not.toEqual([
      expect.objectContaining({
        statusId: expect.anything(),
      }),
    ]);
  });

  it('adds the `statusId` argument to new issue create mutation if status list', async () => {
    wrapper = createComponent({ list: mockStatusList });

    await waitForPromises();
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await waitForPromises();
    expect(wrapper.emitted('add-new-issue')[0]).toEqual([
      expect.objectContaining({
        statusId: mockStatusList.status.id,
      }),
    ]);
  });
});
