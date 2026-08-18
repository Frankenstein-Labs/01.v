import { GlFilteredSearchToken } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueRouter from 'vue-router';
import ScannerToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/scanner_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { MOCK_SCANNERS } from './mock_data';

Vue.use(VueRouter);

describe('ScannerToken', () => {
  let wrapper;
  let router;

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = { data: ['ALL'], operator: '||' },
    active = false,
    scanners = MOCK_SCANNERS,
    toolFilterType = 'scanner',
    stubs,
    mountFn = shallowMountExtended,
  } = {}) => {
    router = new VueRouter({ mode: 'history' });

    wrapper = mountFn(ScannerToken, {
      router,
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        toolFilterType,
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
        scanners,
      },
      stubs: {
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
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
    return wrapper.vm.items.map((i) => i.value).filter((i) => !exempt.includes(i));
  };

  describe('default view', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({
        data: ['ALL'],
        operator: '||',
      });
      expect(wrapper.findByTestId('scanner-token-value').text()).toBe('All scanners');
    });

    it('shows the dropdown with correct options', () => {
      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual([
        'All scanners',
        'ESLint',
        'Find Security Bugs',
        'Gemnasium',
        'GitLab API Fuzzing',
        'GitLeaks',
        'libfuzzer',
        'Trivy',
        'OWASP Zed Attack Proxy (ZAP)',
        'A Custom Scanner (SamScan)',
      ]);
    });
  });

  describe('item selection - toolFilterType: scanner', () => {
    beforeEach(async () => {
      createWrapper({});
      await clickDropdownItem('ALL');
    });

    it('allows multiple selection of items across groups', async () => {
      await clickDropdownItem('gitlab-api-fuzzing', 'zaproxy');

      expect(isOptionChecked('gitlab-api-fuzzing')).toBe(true);
      expect(isOptionChecked('zaproxy')).toBe(true);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All scanners" when that item is selected', async () => {
      await clickDropdownItem('gitlab-api-fuzzing', 'zaproxy', 'ALL');

      allOptionsExcept('ALL').forEach((value) => {
        expect(isOptionChecked(value)).toBe(false);
      });
      expect(isOptionChecked('ALL')).toBe(true);
    });
  });

  describe('toggle text', () => {
    const findViewSlot = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended });

      // Let's set initial state as ALL. It's easier to manipulate because
      // selecting a new value should unselect this value automatically and
      // we can start from an empty state.
      await clickDropdownItem('ALL');
    });

    it.each(MOCK_SCANNERS.map((i) => [i.external_id, i.name, i.vendor]))(
      'when only "%s" is selected shows "%s" as placeholder text',
      async (externalId, scannerName, vendor) => {
        await clickDropdownItem(externalId);
        expect(findViewSlot().text()).toBe(
          `${scannerName}${vendor !== 'GitLab' ? ` (${vendor})` : ''}`,
        );
      },
    );

    it('shows "OWASP Zed Attack Proxy (ZAP) +1 more" when "zaproxy" and another option is selected', async () => {
      await clickDropdownItem('zaproxy', 'gitleaks');
      expect(findViewSlot().text()).toBe('GitLeaks, OWASP Zed Attack Proxy (ZAP)');
    });

    it('shows "All scanners" when "All scanners" is selected', async () => {
      await clickDropdownItem('ALL');
      expect(findViewSlot().text()).toBe('All scanners');
    });
  });
});
