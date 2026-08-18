import { nextTick } from 'vue';
import {
  GlFilteredSearchSuggestion,
  GlFilteredSearchToken,
  GlIcon,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { trimText } from 'helpers/text_helper';
import createStore from 'ee/dependencies/store';
import LicenseToken from 'ee/dependencies/components/filtered_search/tokens/license_token.vue';
import waitForPromises from 'helpers/wait_for_promises';

const TEST_LICENSES = [
  {
    name: 'Apache 2.0',
    spdx_identifier: 'Apache-2.0',
  },
  {
    name: 'MIT License',
    spdx_identifier: 'MIT',
  },
];

describe('ee/dependencies/components/filtered_search/tokens/license_token.vue', () => {
  let wrapper;
  let store;

  const createVuexStore = () => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(LicenseToken, {
      store,
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
        ...propsData,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
        GlIntersperse,
        DynamicScroller: stubComponent(
          {
            props: ['items'],
          },
          {
            template: `<div><slot :item="license" :active="false"></slot></div>`,
            data: () => ({ license: TEST_LICENSES[0] }),
          },
        ),
      },
    });
  };

  beforeEach(() => {
    createVuexStore();
  });

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isLoadingSuggestions = () => wrapper.findComponent(GlLoadingIcon).exists();
  const selectLicense = (license) => {
    findFilteredSearchToken().vm.$emit('select', license.name);
    return nextTick();
  };
  const searchForLicense = (searchTerm = '') => {
    findFilteredSearchToken().vm.$emit('input', { data: searchTerm });
    return waitForPromises();
  };
  const findDynamicScroller = () => wrapper.findComponentByTestId('dynamic-scroller');

  describe('when the component is initially rendered', () => {
    it('shows a loading indicator while fetching the list of licenses', () => {
      store.state.fetchingLicensesInProgress = true;
      createComponent();

      expect(isLoadingSuggestions()).toBe(true);
    });

    it('fetches licenses on creation', () => {
      createComponent();

      expect(store.dispatch).toHaveBeenCalledWith('fetchLicenses');
    });

    it.each([
      { licenses: TEST_LICENSES, expectDynamicScroller: true },
      {
        licenses: [],
        expectDynamicScroller: false,
      },
    ])(
      'with $licenses.length licenses it contains a dynamic-scroller is "$expectDynamicScroller"',
      ({ licenses, expectDynamicScroller }) => {
        store.state.licenses = licenses;
        createComponent();

        expect(findDynamicScroller().exists()).toBe(expectDynamicScroller);
      },
    );

    it.each([
      { active: true, expectedValue: { data: null } },
      { active: false, expectedValue: { data: [] } },
    ])(
      'passes "$expectedValue" to the search-token when the dropdown is open: "$active"',
      ({ active, expectedValue }) => {
        createComponent({
          propsData: {
            active,
            value: { data: [] },
          },
        });

        expect(findFilteredSearchToken().props('value')).toEqual(expectedValue);
      },
    );
  });

  describe('once the licenses have been fetched', () => {
    beforeEach(() => {
      store.state.licenses = TEST_LICENSES;
      createComponent();
    });

    it('correctly sets up a dynamic-scroller to enhance the render-performance of the licenses list', () => {
      expect(findDynamicScroller().attributes()).toMatchObject({
        'key-field': 'id',
        'min-item-size': '32',
        class: 'gl-max-h-37',
      });
    });

    it('shows the full list of licenses once the fetch is completed', () => {
      expect(findDynamicScroller().props('items')).toEqual(TEST_LICENSES);
    });

    describe('when a user enters a search term', () => {
      it('shows the filtered list of suggestions', async () => {
        await searchForLicense(TEST_LICENSES[0].name);

        expect(findDynamicScroller().props('items')).toEqual([TEST_LICENSES[0]]);
      });
    });

    describe('when a user selects licenses to be filtered', () => {
      beforeEach(async () => {
        await searchForLicense();
      });

      it('displays a check-icon next to the selected license', async () => {
        const findFirstSearchSuggestionIcon = () =>
          wrapper.findAllComponents(GlFilteredSearchSuggestion).at(0).findComponent(GlIcon);
        const hiddenClassName = 'gl-invisible';

        expect(findFirstSearchSuggestionIcon().classes()).toContain(hiddenClassName);

        await selectLicense(TEST_LICENSES[0]);

        expect(findFirstSearchSuggestionIcon().classes()).not.toContain(hiddenClassName);
      });

      it('shows a comma seperated list of selected licenses', async () => {
        await selectLicense(TEST_LICENSES[0]);
        await selectLicense(TEST_LICENSES[1]);

        expect(trimText(wrapper.findByTestId('selected-licenses').text())).toBe(
          `${TEST_LICENSES[0].name}, ${TEST_LICENSES[1].name}`,
        );
      });
    });
  });
});
