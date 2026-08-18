import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BoardSettingsListTypes from 'ee/boards/components/board_settings_list_types.vue';
import { mockWorkItemStatus } from 'ee_else_ce_jest/work_items/mock_data';
import { ListType, ListTypeTitles } from '~/boards/constants';

describe('BoardSettingsListTypes', () => {
  let wrapper;

  const createWrapper = ({
    boardListType = ListType.status,
    activeList = {
      [ListType.status]: {
        ...mockWorkItemStatus,
      },
    },
  } = {}) => {
    wrapper = shallowMountExtended(BoardSettingsListTypes, {
      propsData: {
        boardListType,
        activeList,
      },
    });
  };

  const findListTypeHeaderLabel = () => wrapper.find('.js-list-label');
  const findListName = () => wrapper.findByTestId('status-list-type');
  const findStatusIcon = () => wrapper.findComponent(GlIcon);

  describe('Default', () => {
    const listTypes = [
      ListType.label,
      ListType.milestone,
      ListType.iteration,
      ListType.assignee,
      ListType.status,
    ];

    it.each(listTypes)(
      'renders the list type header label when list type is : `%s`',
      (listType) => {
        createWrapper({ boardListType: listType });

        expect(findListTypeHeaderLabel().exists()).toBe(true);
        expect(findListTypeHeaderLabel().text()).toBe(ListTypeTitles[listType]);
      },
    );
  });

  describe('when boardListType is `status`', () => {
    it('renders status container with icon and name', () => {
      createWrapper();
      expect(findListName().classes()).toContain('gl-truncate');
      expect(findStatusIcon().exists()).toBe(true);
      expect(findStatusIcon().props()).toMatchObject({
        name: mockWorkItemStatus.iconName,
        size: 12,
      });
      expect(wrapper.find('span').text()).toBe(mockWorkItemStatus.name);
    });
  });
});
