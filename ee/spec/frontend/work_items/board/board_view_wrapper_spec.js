import { shallowMount } from '@vue/test-utils';
import BoardViewEE from 'ee/work_items/board/board_view.vue';
import BoardView from '~/work_items/board/board_view.vue';

describe('ee/work_items/board/board_view (EE wrapper)', () => {
  let wrapper;

  const findBoardView = () => wrapper.findComponent(BoardView);

  const props = {
    rootPageFullPath: 'group/project',
    queryVariables: { state: 'opened' },
    collapsedGroups: ['status:1'],
    groupOrder: ['status:2', 'status:1'],
    canReorder: true,
    hiddenMetadataKeys: ['labels'],
    activeItem: { id: 'gid://gitlab/WorkItem/1' },
    detailPanelEnabled: false,
    updatedWorkItem: { id: 'gid://gitlab/WorkItem/2' },
  };

  const createComponent = ({ listeners = {} } = {}) => {
    wrapper = shallowMount(BoardViewEE, { propsData: props, listeners });
  };

  it('forwards every prop to the CE board view', () => {
    createComponent();

    expect(findBoardView().props()).toMatchObject(props);
  });

  it('forwards the group order used to reorder columns', () => {
    createComponent();

    expect(findBoardView().props('groupOrder')).toEqual(['status:2', 'status:1']);
  });

  it('forwards listeners so reorder-groups bubbles up', () => {
    const onReorder = jest.fn();
    createComponent({ listeners: { 'reorder-groups': onReorder } });

    findBoardView().vm.$emit('reorder-groups', ['status:1', 'status:2']);

    expect(onReorder).toHaveBeenCalledWith(['status:1', 'status:2']);
  });
});
