import { GlFilteredSearchToken } from '@gitlab/ui';
import { nextTick } from 'vue';
import StatusToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/status_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';

const ALL_STATUS_OPTION_VALUES = [
  'ALL',
  'DETECTED',
  'CONFIRMED',
  'RESOLVED',
  'DISMISSED',
  'ACCEPTABLE_RISK',
  'FALSE_POSITIVE',
  'MITIGATING_CONTROL',
  'USED_IN_TESTS',
  'NOT_APPLICABLE',
];

describe('Status Token component', () => {
  let wrapper;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_IS,
  };

  const createWrapper = ({
    value = { data: StatusToken.DEFAULT_VALUES, operator: '=' },
    active = false,
    config = mockConfig,
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(StatusToken, {
      propsData: {
        config,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
      },
      stubs: {
        QuerystringSync: true,
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const findDropdownOptions = () =>
    wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.props('text'));
  const findSlotView = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);
  const isOptionChecked = (v) =>
    wrapper.findComponentByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  const allOptionsExcept = (value) => {
    const exempt = Array.isArray(value) ? value : [value];

    return ALL_STATUS_OPTION_VALUES.filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('transforms the filters correctly (this is triggered by the parent component)', () => {
      expect(StatusToken.transformFilters(['DETECTED', 'ACCEPTABLE_RISK'])).toEqual({
        state: ['DETECTED'],
        dismissalReason: ['ACCEPTABLE_RISK'],
      });

      expect(StatusToken.transformFilters(['CONFIRMED'])).toEqual({
        state: ['CONFIRMED'],
        dismissalReason: [],
      });

      expect(StatusToken.transformFilters([])).toEqual({
        state: [],
        dismissalReason: [],
      });
    });

    it('has a defaultValues function', () => {
      expect(StatusToken.defaultValues()).toEqual(['DETECTED', 'CONFIRMED']);
    });

    it('returns config.defaultValue from defaultValues when provided', () => {
      expect(StatusToken.defaultValues({ config: { defaultValue: ['DETECTED'] } })).toEqual([
        'DETECTED',
      ]);
    });

    it('transforms the query params correctly', () => {
      expect(StatusToken.transformQueryParams([])).toBe('ALL');

      expect(StatusToken.transformQueryParams(['DISMISSED', 'CONFIRMED'])).toBe(
        'DISMISSED,CONFIRMED',
      );
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['ALL'],
        operator: '=',
      });
      expect(wrapper.findByTestId('status-token-placeholder').text()).toBe('All statuses');
    });

    it('shows the dropdown with correct options', () => {
      expect(findDropdownOptions()).toEqual([
        'All statuses',
        'Needs triage',
        'Confirmed',
        'Resolved',
        'All dismissal reasons',
        'Acceptable risk',
        'False positive',
        'Mitigating control',
        'Used in tests',
        'Not applicable',
      ]);
    });
  });

  describe('item selection', () => {
    beforeEach(async () => {
      createWrapper({});
      await clickDropdownItem('ALL');
    });

    it('toggles the item selection when clicked on', async () => {
      await clickDropdownItem('CONFIRMED', 'RESOLVED');

      expect(isOptionChecked('ALL')).toBe(false);
      expect(isOptionChecked('CONFIRMED')).toBe(true);
      expect(isOptionChecked('RESOLVED')).toBe(true);

      // Add a dismissal reason
      await clickDropdownItem('ACCEPTABLE_RISK');

      expect(isOptionChecked('CONFIRMED')).toBe(true);
      expect(isOptionChecked('RESOLVED')).toBe(true);
      expect(isOptionChecked('ACCEPTABLE_RISK')).toBe(true);
      expect(isOptionChecked('DISMISSED')).toBe(false);

      // Select all
      await clickDropdownItem('ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      // Select All Dismissed Values
      await clickDropdownItem('DISMISSED');

      allOptionsExcept('DISMISSED').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });

      // Selecting another dismissed should unselect All Dismissed values
      await clickDropdownItem('USED_IN_TESTS');

      expect(isOptionChecked('USED_IN_TESTS')).toBe(true);
      expect(isOptionChecked('DISMISSED')).toBe(false);
    });
  });

  describe('toggle text', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });

      // Let's set initial state as ALL. It's easier to manipulate because
      // selecting a new value should unselect this value automatically and
      // we can start from an empty state.
      await clickDropdownItem('ALL');
    });

    it('shows "Dismissed (all reasons)" when only "All dismissal reasons" option is selected', async () => {
      await clickDropdownItem('DISMISSED');
      expect(findSlotView().text()).toBe('Dismissed (all reasons)');
    });

    it('shows "Dismissed (2 reasons)" when only 2 dismissal reasons are selected', async () => {
      await clickDropdownItem('FALSE_POSITIVE', 'ACCEPTABLE_RISK');
      expect(findSlotView().text()).toBe('Dismissed (2 reasons)');
    });

    it('shows "Confirmed, False positive" when confirmed and a dismissal reason are selected', async () => {
      await clickDropdownItem('CONFIRMED', 'FALSE_POSITIVE');
      expect(findSlotView().text()).toBe('Confirmed, False positive');
    });

    it('shows "Needs triage, Confirmed +1 more" when more than 2 options are selected', async () => {
      await clickDropdownItem('CONFIRMED', 'DETECTED', 'DISMISSED');
      expect(findSlotView().text()).toBe('Needs triage, Confirmed +1 more');
    });
  });

  describe('with config.hideDismissalReasons', () => {
    beforeEach(() => {
      createWrapper({ config: { ...mockConfig, hideDismissalReasons: true } });
    });

    it('shows a flat list of statuses with Dismissed inline and no per-reason section', () => {
      expect(findDropdownOptions()).toEqual([
        'All statuses',
        'Needs triage',
        'Confirmed',
        'Dismissed',
        'Resolved',
      ]);
    });

    it('shows "Dismissed" (not "Dismissed (all reasons)") when Dismissed is selected', async () => {
      createWrapper({
        config: { ...mockConfig, hideDismissalReasons: true },
        mountFn: mountExtended,
      });
      await clickDropdownItem('ALL');
      await clickDropdownItem('DISMISSED');

      expect(findSlotView().text()).toBe('Dismissed');
    });
  });

  describe('with config.defaultValue', () => {
    it('initializes selectedStatuses from value.data when provided', () => {
      createWrapper({
        config: { ...mockConfig, defaultValue: ['DETECTED'] },
        value: { data: ['DETECTED'], operator: '=' },
      });

      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['DETECTED'],
        operator: '=',
      });
    });
  });
});
