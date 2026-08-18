import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { GlButton, GlLabel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import { updateHistory } from '~/lib/utils/url_utility';
import EpicItemDetails from 'ee/roadmap/components/epic_item_details.vue';
import WorkItemRelationshipIcons from '~/work_items/components/shared/work_item_relationship_icons.vue';
import {
  mockGroupId,
  mockFormattedEpic,
  mockFormattedChildEpic2,
  mockFormattedChildEpic1,
} from 'ee_jest/roadmap/mock_data';
import { expectPayload } from '../local_cache_helpers';

jest.mock('~/lib/utils/url_utility');

Vue.use(VueApollo);

const updateLocalSettingsMutationMock = jest.fn();

describe('EpicItemDetails', () => {
  let wrapper;

  const createWrapper = ({
    currentGroupId = mockGroupId,
    epic = mockFormattedEpic,
    childLevel = 0,
    allowSubEpics = true,
    allowScopedLabels = false,
    hasFiltersApplied = false,
    isChildrenEmpty = false,
    isExpanded = false,
    isFetchingChildren = false,
    isShowingLabels = false,
    filterParams = {},
  } = {}) => {
    wrapper = shallowMountExtended(EpicItemDetails, {
      propsData: {
        epic,
        currentGroupId,
        timeframeString: 'Jul 10, 2017 – Jun 2, 2018',
        childLevel,
        hasFiltersApplied,
        isChildrenEmpty,
        isExpanded,
        isFetchingChildren,
        filterParams,
        isShowingLabels,
      },
      provide: {
        allowSubEpics,
        allowScopedLabels,
        currentGroupId,
      },
      apolloProvider: createMockApollo([], {
        Mutation: {
          updateLocalRoadmapSettings: updateLocalSettingsMutationMock,
        },
      }),
    });
  };

  const getTitle = () => wrapper.findByTestId('epic-title');
  const getGroupName = () => wrapper.findByTestId('epic-group');
  const getEpicContainer = () => wrapper.findByTestId('epic-container');
  const getExpandIconButton = () => wrapper.findComponent(GlButton);
  const getExpandIconTooltip = () => wrapper.findByTestId('expand-icon-tooltip');
  const getChildEpicsCount = () => wrapper.findByTestId('child-epics-count');
  const getChildEpicsCountTooltip = () => wrapper.findByTestId('child-epics-count-tooltip');
  const findLabelsContainer = () => wrapper.findByTestId('epic-labels');
  const findAllLabels = () => wrapper.findAllComponents(GlLabel);
  const findRegularLabel = () => findAllLabels().at(0);
  const findScopedLabel = () => findAllLabels().at(1);
  const findRelationshipIcons = () => wrapper.findComponent(WorkItemRelationshipIcons);

  const getExpandButtonData = () => ({
    icon: wrapper.findComponent(GlButton).attributes('icon'),
    iconLabel: getExpandIconButton().attributes('aria-label'),
    tooltip: getExpandIconTooltip().text(),
  });

  const getEpicTitleData = () => ({
    title: getTitle().text(),
    link: getTitle().attributes('href'),
  });

  const getEpicGroupNameData = () => ({
    groupName: getGroupName().text(),
    title: getGroupName().attributes('title'),
  });

  const createMockEpic = (epic) => ({
    ...mockFormattedEpic,
    ...epic,
  });

  const epicWithNoLinkedItems = {
    ...mockFormattedEpic,
    blockingCount: 0,
  };

  describe('epic title', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('is displayed with a link to the epic', () => {
      expect(getEpicTitleData()).toEqual({
        title: mockFormattedEpic.title,
        link: mockFormattedEpic.webUrl,
      });
    });
  });

  describe('epic group name', () => {
    describe('when the epic group ID is different from the current group ID', () => {
      it('is displayed and set to the title attribute', () => {
        createWrapper({ currentGroupId: 123 });
        expect(getEpicGroupNameData()).toEqual({
          groupName: mockFormattedEpic.group.name,
          title: mockFormattedEpic.group.fullName,
        });
      });
    });

    describe('when the epic group ID is the same as the current group ID', () => {
      it('is hidden', () => {
        createWrapper();
        expect(getGroupName().exists()).toBe(false);
      });
    });
  });

  describe('timeframe', () => {
    it('is displayed', () => {
      createWrapper();
      const timeframe = wrapper.find('.epic-timeframe');

      expect(timeframe.text()).toBe('Jul 10, 2017 – Jun 2, 2018');
    });
  });

  describe('nested children styles', () => {
    const epic = createMockEpic({
      ...mockFormattedEpic,
      isChildEpic: true,
    });
    it('applies class for level 1 child', () => {
      createWrapper({ epic, childLevel: 1 });
      expect(getEpicContainer().classes('gl-ml-3')).toBe(true);
    });

    it('applies class for level 2 child', () => {
      createWrapper({ epic, childLevel: 2 });
      expect(getEpicContainer().classes('gl-ml-5')).toBe(true);
    });
  });

  describe('epic', () => {
    describe('expand icon', () => {
      it('is hidden when it is child epic', () => {
        const epic = createMockEpic({
          isChildEpic: true,
        });
        createWrapper({ epic });
        expect(getExpandIconButton().classes()).toContain('gl-invisible');
      });

      describe('when epic has no child epics', () => {
        beforeEach(() => {
          const epic = createMockEpic({
            hasChildrenWithinTimeframe: false,
            descendantCounts: {
              openedEpics: 0,
              closedEpics: 0,
            },
          });
          createWrapper({ epic });
        });
        it('is hidden', () => {
          expect(getExpandIconButton().classes()).toContain('gl-invisible');
        });
        describe('child epics count', () => {
          it('shows the count as 0', () => {
            expect(getChildEpicsCount().text()).toBe('0');
          });
        });
      });

      describe('when epic has child epics', () => {
        let epic;
        beforeEach(() => {
          epic = createMockEpic({
            hasChildrenWithinTimeframe: true,
            children: {
              edges: [mockFormattedChildEpic1],
            },
            descendantCounts: {
              openedEpics: 0,
              closedEpics: 1,
            },
          });
          createWrapper({ epic });
        });

        it('is shown', () => {
          expect(getExpandIconButton().classes()).not.toContain('gl-invisible');
        });

        it('emits `toggle-epic` event when clicked', () => {
          getExpandIconButton().vm.$emit('click');
          expect(wrapper.emitted('toggle-epic')).toEqual([[]]);
        });

        describe('when child epics are expanded', () => {
          it('shows collapse button', () => {
            createWrapper({ epic, isExpanded: true });

            expect(getExpandButtonData()).toEqual({
              icon: 'chevron-down',
              iconLabel: 'Collapse',
              tooltip: 'Collapse',
            });
          });

          describe('when filters are applied', () => {
            beforeEach(() => {
              createWrapper({
                epic,
                filterParams: { authorUsername: 'root' },
                isChildrenEmpty: true,
                isExpanded: true,
              });
            });

            it('shows child epics match filters button', () => {
              expect(getExpandButtonData()).toEqual({
                icon: 'information-o',
                iconLabel: 'No child epics match applied filters',
                tooltip: 'No child epics match applied filters',
              });
            });
          });
        });

        describe('when child epics are not expanded', () => {
          beforeEach(() => {
            createWrapper({
              epic,
            });
          });

          it('shows expand button', () => {
            expect(getExpandButtonData()).toEqual({
              icon: 'chevron-right',
              iconLabel: 'Expand',
              tooltip: 'Expand',
            });
          });
        });

        describe('child epics count', () => {
          it('has a tooltip with the count', () => {
            createWrapper({ epic });
            expect(getChildEpicsCountTooltip().text()).toBe('1 child epic');
          });

          it('has a tooltip with the count and explanation if search is being performed', () => {
            createWrapper({ epic, filterParams: { search: 'foo' } });
            expect(getChildEpicsCountTooltip().text()).toBe(
              '1 child epic Some child epics may be hidden due to applied filters',
            );
          });

          it('does not render if the user license does not support child epics', () => {
            createWrapper({ epic, allowSubEpics: false });
            expect(getChildEpicsCount().exists()).toBe(false);
          });

          it('shows the correct count of child epics', () => {
            epic = createMockEpic({
              children: {
                edges: [mockFormattedChildEpic1, mockFormattedChildEpic2],
              },
              descendantCounts: {
                openedEpics: 0,
                closedEpics: 2,
              },
            });
            createWrapper({ epic });
            expect(getChildEpicsCount().text()).toBe('2');
          });
        });
      });
    });
  });

  describe('epic labels', () => {
    const mockLabels = mockFormattedEpic.labels.nodes;
    const mockRegularLabel = mockLabels[0];
    const mockScopedLabel = mockLabels[1];

    it('do not display by default', () => {
      createWrapper();
      expect(findLabelsContainer().exists()).toBe(false);
    });

    it('display labels with correct props when isShowingLabels setting is set to true', () => {
      createWrapper({ allowScopedLabels: true, isShowingLabels: true });

      expect(findLabelsContainer().exists()).toBe(true);

      expect(findRegularLabel().props()).toMatchObject({
        title: mockRegularLabel.title,
        backgroundColor: mockRegularLabel.color,
        description: mockRegularLabel.description,
        scoped: false,
      });

      expect(findScopedLabel().props()).toMatchObject({
        title: mockScopedLabel.title,
        backgroundColor: mockScopedLabel.color,
        description: mockScopedLabel.description,
        scoped: true,
      });
    });

    it.each`
      assertionName       | allowScopedLabels | scopedLabel
      ${'do not display'} | ${false}          | ${false}
      ${'display'}        | ${true}           | ${true}
    `(
      '$assertionName scoped labels when allowScopedLabels is $allowScopedLabels',
      ({ allowScopedLabels, scopedLabel }) => {
        createWrapper({ allowScopedLabels, isShowingLabels: true });

        expect(findScopedLabel().props('scoped')).toBe(scopedLabel);
      },
    );

    describe('click on label', () => {
      beforeEach(() => {
        createWrapper({ isShowingLabels: true });
      });

      describe('when selected label is not in the filter', () => {
        beforeEach(() => {
          // setWindowLocation('?');
          wrapper.findComponent(GlLabel).vm.$emit('click', {
            preventDefault: jest.fn(),
          });
        });

        it('calls updateHistory', () => {
          expect(updateHistory).toHaveBeenCalledTimes(1);
        });

        it('calls updateLocalRoadmapSettings mutation', () => {
          expect(updateLocalSettingsMutationMock).toHaveBeenCalledWith(
            ...expectPayload({ filterParams: {} }),
          );
        });
      });

      describe('when selected label is already in the filter', () => {
        beforeEach(() => {
          // setWindowLocation('?label_name[]=Aquanix');
          createWrapper({
            filterParams: {
              labelName: ['Aquanix'],
            },
            isShowingLabels: true,
          });

          wrapper.findComponent(GlLabel).vm.$emit('click', {
            preventDefault: jest.fn(),
          });
        });

        it('does not call updateHistory', () => {
          expect(updateHistory).not.toHaveBeenCalled();
        });

        it('does not call `updateLocalRoadmapSettings` mutation', () => {
          expect(updateLocalSettingsMutationMock).not.toHaveBeenCalled();
        });
      });
    });
  });

  describe('epic relationships', () => {
    it.each`
      state                            | assertion | epic
      ${'rendered if epic has'}        | ${true}   | ${mockFormattedEpic}
      ${'not rendered if epic has no'} | ${false}  | ${epicWithNoLinkedItems}
    `('relationship icons are $state linked work items', async ({ assertion, epic }) => {
      createWrapper({ epic });
      await waitForPromises();

      expect(findRelationshipIcons().exists()).toBe(assertion);
    });
  });
});
