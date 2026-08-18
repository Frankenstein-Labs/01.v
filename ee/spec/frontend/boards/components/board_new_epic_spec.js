import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BoardNewEpic from 'ee/boards/components/board_new_epic.vue';
import GroupSelect from 'ee/boards/components/group_select.vue';
import epicBoardQuery from 'ee/boards/graphql/epic_board.query.graphql';
import { mockList } from 'jest/boards/mock_data';

import BoardNewItem from '~/boards/components/board_new_item.vue';

import { mockEpicBoardResponse } from '../mock_data';

Vue.use(VueApollo);

const epicBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockEpicBoardResponse);
const mockApollo = createMockApollo([[epicBoardQuery, epicBoardQueryHandlerSuccess]]);

const createComponent = () =>
  shallowMount(BoardNewEpic, {
    apolloProvider: mockApollo,
    propsData: {
      list: mockList,
      boardId: 'gid://gitlab/Board::EpicBoard/1',
    },
    provide: {
      boardType: 'group',
      fullPath: 'gitlab-org',
    },
    stubs: {
      BoardNewItem,
    },
  });

describe('Epic boards new epic form', () => {
  let wrapper;

  const findBoardNewItem = () => wrapper.findComponent(BoardNewItem);
  const submitForm = async (w) => {
    const boardNewItem = w.findComponent(BoardNewItem);

    boardNewItem.vm.$emit('form-submit', { title: 'Foo' });

    await nextTick();
  };

  beforeEach(async () => {
    wrapper = createComponent();

    await nextTick();
  });

  it('fetches board when creating epic and emits add-new-epic event', async () => {
    await submitForm(wrapper);
    await waitForPromises();

    expect(epicBoardQueryHandlerSuccess).toHaveBeenCalled();
    expect(wrapper.emitted('add-new-epic')[0][0]).toMatchObject({ title: 'Foo' });
  });

  it('renders board-new-item component', () => {
    const boardNewItem = findBoardNewItem();
    expect(boardNewItem.exists()).toBe(true);
    expect(boardNewItem.props()).toEqual({
      list: mockList,
      submitButtonTitle: 'Create epic',
      disableSubmit: false,
    });
  });

  it('renders group-select dropdown within board-new-item', () => {
    const boardNewItem = findBoardNewItem();
    const groupSelect = boardNewItem.findComponent(GroupSelect);

    expect(groupSelect.exists()).toBe(true);
  });

  it('emits event `toggle-new-form` when `board-new-item` emits form-cancel event', async () => {
    findBoardNewItem().vm.$emit('form-cancel');

    await nextTick();
    expect(wrapper.emitted('toggle-new-form')).toHaveLength(1);
  });
});
