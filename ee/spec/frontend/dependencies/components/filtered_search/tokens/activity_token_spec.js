import { nextTick } from 'vue';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlDropdownDivider,
  GlDropdownSectionHeader,
  GlBadge,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import ActivityToken, {
  GROUPS,
} from 'ee/dependencies/components/filtered_search/tokens/activity_token.vue';

const ALL_ACTIVITY_VALUE = 'ALL';
const DISMISSED_IN_MR_VALUE = 'DISMISSED_IN_MR';

describe('ee/dependencies/components/filtered_search/tokens/activity_token.vue', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(ActivityToken, {
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
        ...propsData,
      },
      provide: {
        namespaceType: 'group',
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
        GlDropdownDivider,
        GlDropdownSectionHeader,
        GlBadge,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);
  const findSecondSearchSuggestionIcon = () => findSuggestions().at(1).findComponent(GlIcon);
  const selectActivity = (activity) => {
    findFilteredSearchToken().vm.$emit('select', activity);
    return nextTick();
  };

  describe('when the component is initially rendered', () => {
    it('passes the correct props to the GlFilteredSearchToken', () => {
      createComponent();
      expect(findFilteredSearchToken().exists()).toBe(true);
      expect(findFilteredSearchToken().props()).toMatchObject({
        config: { multiSelect: true },
        value: { data: [ALL_ACTIVITY_VALUE] },
        active: false,
      });
    });

    it.each`
      active   | value             | expected
      ${true}  | ${{ data: [] }}   | ${{ data: null }}
      ${false} | ${{ data: null }} | ${{ data: [ALL_ACTIVITY_VALUE] }}
    `(
      'passes "$expected" to the search-token when the dropdown is open: "$active" and the data is "$value"',
      ({ active, value, expected }) => {
        createComponent({ propsData: { active, value } });
        expect(findFilteredSearchToken().props('value')).toEqual(expected);
      },
    );

    it('displays the placeholder text when no activities are selected', () => {
      createComponent();
      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('All activity');
    });

    it('displays the selected activity text when an activity is selected', () => {
      createComponent({ propsData: { value: { data: [DISMISSED_IN_MR_VALUE] } } });
      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('Dismissed in MR');
    });

    describe('activity token groups structure', () => {
      beforeEach(() => {
        createComponent();
      });

      it('has the correct number of groups', () => {
        expect(GROUPS).toHaveLength(2);
      });

      it('first group contains "All activity" option', () => {
        const firstGroup = GROUPS[0];

        expect(firstGroup.options).toHaveLength(1);
        expect(firstGroup.options[0].value).toBe(ALL_ACTIVITY_VALUE);
      });

      it('second group contains "Dismissed in MR" option', () => {
        const secondGroup = GROUPS[1];

        expect(secondGroup.options).toHaveLength(1);
        expect(secondGroup.options[0].value).toBe(DISMISSED_IN_MR_VALUE);
      });

      it('second group has the correct text and icon', () => {
        const secondGroup = GROUPS[1];

        expect(secondGroup.text).toBe('Policy violations');
        expect(secondGroup.icon).toBe('flag');
      });
    });
  });

  describe('when the list of activities has been rendered', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders all activity groups', () => {
      const headers = wrapper.findAllComponents(GlDropdownSectionHeader);

      // First group has no header (empty text), second group has a header
      expect(headers).toHaveLength(1);
    });

    it('renders all activity options', () => {
      expect(findSuggestions()).toHaveLength(GROUPS.flatMap((g) => g.options).length);
    });

    it('renders the "All activity" option in the first group', () => {
      const firstSuggestion = findSuggestions().at(0);
      expect(firstSuggestion.props('value')).toBe(ALL_ACTIVITY_VALUE);
      expect(firstSuggestion.text()).toContain('All activity');
    });

    it('renders the "Dismissed in MR" option in the second group', () => {
      const dismissedSuggestion = findSuggestions().at(1);
      expect(dismissedSuggestion.props('value')).toBe(DISMISSED_IN_MR_VALUE);
      expect(dismissedSuggestion.text()).toContain('Dismissed in MR');
    });

    it('renders a divider between groups', () => {
      const dividers = wrapper.findAllComponents(GlDropdownDivider);
      expect(dividers).toHaveLength(GROUPS.length - 1);
    });

    it('renders a badge with the correct icon for the policy violations group', () => {
      const badge = wrapper.findComponent(GlBadge);
      expect(badge.props('icon')).toBe('flag');
    });

    describe('when a user selects activities to be filtered', () => {
      it('displays a check-icon next to the selected activity', async () => {
        expect(findSecondSearchSuggestionIcon().classes()).toContain('gl-invisible');
        await selectActivity(DISMISSED_IN_MR_VALUE);
        expect(findSecondSearchSuggestionIcon().classes()).not.toContain('gl-invisible');
      });
    });
  });

  describe('when a user selects an activity', () => {
    beforeEach(() => {
      createComponent();
    });

    it('selects activity when clicking on the activity', async () => {
      await selectActivity(DISMISSED_IN_MR_VALUE);
      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([DISMISSED_IN_MR_VALUE]);

      await selectActivity(ALL_ACTIVITY_VALUE);

      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([ALL_ACTIVITY_VALUE]);
    });

    it('updates the placeholder text when an activity is selected', async () => {
      await selectActivity(DISMISSED_IN_MR_VALUE);

      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('Dismissed in MR');
    });

    it('updates the placeholder text back to "All activity" when deselecting', async () => {
      await selectActivity(DISMISSED_IN_MR_VALUE);
      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('Dismissed in MR');

      await selectActivity(DISMISSED_IN_MR_VALUE);

      expect(wrapper.findByTestId('activity-token-placeholder').text()).toBe('All activity');
    });
  });

  describe('when the token is destroyed', () => {
    it('resets the selected activities', async () => {
      createComponent({ propsData: { value: { data: [DISMISSED_IN_MR_VALUE] } } });
      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([DISMISSED_IN_MR_VALUE]);
      findFilteredSearchToken().vm.$emit('destroy');
      await nextTick();
      expect(findFilteredSearchToken().props('multiSelectValues')).toEqual([]);
    });
  });
});
