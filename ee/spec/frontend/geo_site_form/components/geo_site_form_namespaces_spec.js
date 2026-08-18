import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import GeoSiteFormNamespaces from 'ee/geo_site_form/components/geo_site_form_namespaces.vue';
import { SELECTIVE_SYNC_NAMESPACES } from 'ee/geo_site_form/constants';
import waitForPromises from 'helpers/wait_for_promises';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { MOCK_SYNC_NAMESPACES, MOCK_SYNC_NAMESPACE_IDS } from '../mock_data';

Vue.use(Vuex);

describe('GeoSiteFormNamespaces', () => {
  let wrapper;

  const defaultProps = {
    selectedNamespaces: [],
  };

  const actionSpies = {
    fetchSyncNamespaces: jest.fn(),
    toggleNamespace: jest.fn(),
    isSelected: jest.fn(),
  };

  const createComponent = (props = {}, initialState) => {
    const fakeStore = new Vuex.Store({
      state: {
        synchronizationNamespaces: [],
        ...initialState,
      },
      actions: actionSpies,
    });

    wrapper = shallowMount(GeoSiteFormNamespaces, {
      store: fakeStore,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlCollapsibleListbox', () => {
      expect(findGlCollapsibleListbox().exists()).toBe(true);
    });
  });

  describe('events', () => {
    describe('select', () => {
      beforeEach(() => {
        createComponent();
        findGlCollapsibleListbox().vm.$emit('select', MOCK_SYNC_NAMESPACE_IDS);
      });

      it('emits update-sync-options with selected options', () => {
        expect(wrapper.emitted('update-sync-options')).toStrictEqual([
          [{ key: SELECTIVE_SYNC_NAMESPACES, value: MOCK_SYNC_NAMESPACE_IDS }],
        ]);
      });
    });

    describe('shown', () => {
      describe('with no current search', () => {
        beforeEach(() => {
          createComponent();
          findGlCollapsibleListbox().vm.$emit('shown');
        });

        it('calls fetchSyncNamespaces with an empty search', () => {
          expect(actionSpies.fetchSyncNamespaces).toHaveBeenCalledWith(expect.any(Object), '');
        });
      });

      describe('with a current search', () => {
        const mockSearch = 'test';

        beforeEach(() => {
          createComponent();
          findGlCollapsibleListbox().vm.$emit('search', mockSearch);
          findGlCollapsibleListbox().vm.$emit('shown');
        });

        it('calls fetchSyncNamespaces with current search', () => {
          expect(actionSpies.fetchSyncNamespaces).toHaveBeenCalledWith(
            expect.any(Object),
            mockSearch,
          );
        });
      });
    });

    describe('search', () => {
      const mockSearch = 'test';

      beforeEach(() => {
        createComponent();
      });

      it('debounces search before calling fetchSyncNamespaces', async () => {
        findGlCollapsibleListbox().vm.$emit('search', mockSearch);

        expect(actionSpies.fetchSyncNamespaces).not.toHaveBeenCalled();

        jest.advanceTimersByTime(DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
        await waitForPromises();

        expect(actionSpies.fetchSyncNamespaces).toHaveBeenCalledWith(
          expect.any(Object),
          mockSearch,
        );
      });
    });
  });

  describe('computed', () => {
    describe('dropdownItems', () => {
      beforeEach(() => {
        createComponent(null, { synchronizationNamespaces: MOCK_SYNC_NAMESPACES });
      });

      it('properly formats the dropdown items for the list box', () => {
        const expectedArray = MOCK_SYNC_NAMESPACES.map((item) => {
          return { ...item, value: item.id, text: item.full_name };
        });

        expect(findGlCollapsibleListbox().props('items')).toStrictEqual(expectedArray);
      });
    });

    describe('dropdownTitle', () => {
      describe('when selectedNamespaces is empty', () => {
        beforeEach(() => {
          createComponent({
            selectedNamespaces: [],
          });
        });

        it('returns `Select groups to replicate`', () => {
          expect(findGlCollapsibleListbox().props('toggleText')).toBe(
            GeoSiteFormNamespaces.i18n.noSelectedDropdownTitle,
          );
        });
      });

      describe('when selectedNamespaces length === 1', () => {
        beforeEach(() => {
          createComponent({
            selectedNamespaces: [MOCK_SYNC_NAMESPACES[0].id],
          });
        });

        it('returns `this.selectedNamespaces.length` group selected', () => {
          expect(findGlCollapsibleListbox().props('toggleText')).toBe(
            `${wrapper.vm.selectedNamespaces.length} group selected`,
          );
        });
      });

      describe('when selectedNamespaces length > 1', () => {
        beforeEach(() => {
          createComponent({
            selectedNamespaces: [MOCK_SYNC_NAMESPACES[0].id, MOCK_SYNC_NAMESPACES[1].id],
          });
        });

        it('returns `this.selectedNamespaces.length` group selected', () => {
          expect(findGlCollapsibleListbox().props('toggleText')).toBe(
            `${wrapper.vm.selectedNamespaces.length} groups selected`,
          );
        });
      });
    });
  });
});
