import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import GeoSiteForm from 'ee/geo_site_form/components/geo_site_form.vue';
import GeoSiteFormCapacities from 'ee/geo_site_form/components/geo_site_form_capacities.vue';
import GeoSiteFormCore from 'ee/geo_site_form/components/geo_site_form_core.vue';
import GeoSiteFormSelectiveSync from 'ee/geo_site_form/components/geo_site_form_selective_sync.vue';
import { SELECTIVE_SYNC_NAMESPACES } from 'ee/geo_site_form/constants';
import initStore from 'ee/geo_site_form/store';
import { visitUrl } from '~/lib/utils/url_utility';
import {
  MOCK_SITE,
  MOCK_SELECTIVE_SYNC_TYPES,
  MOCK_SYNC_SHARDS,
  MOCK_SITES_PATH,
  MOCK_SYNC_NAMESPACE_IDS,
} from '../mock_data';

Vue.use(Vuex);

jest.mock('~/helpers/help_page_helper');
jest.mock('~/lib/utils/url_utility', () => ({
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

const saveGeoSiteSpy = jest.fn();

const { state } = initStore(MOCK_SITES_PATH);
const fakeStore = ({ getters }) =>
  new Vuex.Store({
    state,
    getters: {
      formHasError: () => false,
      ...getters,
    },
    actions: {
      saveGeoSite: saveGeoSiteSpy,
    },
  });

describe('GeoSiteForm', () => {
  let wrapper;

  const createComponent = (props = {}, store = {}, glFeatures = {}) => {
    wrapper = shallowMount(GeoSiteForm, {
      store: fakeStore(store),
      propsData: {
        site: MOCK_SITE,
        selectiveSyncTypes: MOCK_SELECTIVE_SYNC_TYPES,
        syncShardsOptions: MOCK_SYNC_SHARDS,
        ...props,
      },
      provide: {
        glFeatures,
      },
    });
  };

  const findGeoSiteFormCoreField = () => wrapper.findComponent(GeoSiteFormCore);
  const findGeoSiteFormSelectiveSyncField = () => wrapper.findComponent(GeoSiteFormSelectiveSync);
  const findGeoSiteFormCapacitiesField = () => wrapper.findComponent(GeoSiteFormCapacities);
  const findGeoSiteSaveButton = () => wrapper.findComponent('#site-save-button');
  const findGeoSiteCancelButton = () => wrapper.findComponent('#site-cancel-button');

  describe('template', () => {
    describe.each`
      primarySite | orgMoverExtendSelectiveSyncToPrimaryChecksumming | showCore | showSelectiveSync | showCapacities
      ${true}     | ${false}                                         | ${true}  | ${false}          | ${true}
      ${true}     | ${true}                                          | ${true}  | ${true}           | ${true}
      ${false}    | ${false}                                         | ${true}  | ${true}           | ${true}
      ${false}    | ${true}                                          | ${true}  | ${true}           | ${true}
    `(
      `conditional fields`,
      ({
        primarySite,
        orgMoverExtendSelectiveSyncToPrimaryChecksumming,
        showCore,
        showSelectiveSync,
        showCapacities,
      }) => {
        beforeEach(() => {
          createComponent({ site: { MOCK_SITE, primary: primarySite } }, undefined, {
            orgMoverExtendSelectiveSyncToPrimaryChecksumming,
          });
        });

        it(`it ${showCore ? 'shows' : 'hides'} the Core Field`, () => {
          expect(findGeoSiteFormCoreField().exists()).toBe(showCore);
        });

        it(`it ${showSelectiveSync ? 'shows' : 'hides'} the Selective Sync Field`, () => {
          expect(findGeoSiteFormSelectiveSyncField().exists()).toBe(showSelectiveSync);
        });

        it(`it ${showCapacities ? 'shows' : 'hides'} the Capacities Field`, () => {
          expect(findGeoSiteFormCapacitiesField().exists()).toBe(showCapacities);
        });
      },
    );

    describe('Save Button', () => {
      describe('with errors on form', () => {
        it('disables button', () => {
          createComponent(undefined, {
            getters: {
              formHasError: () => true,
            },
          });

          expect(findGeoSiteSaveButton().attributes('disabled')).toBeDefined();
        });
      });

      describe('with mo errors on form', () => {
        it('does not disable button', () => {
          createComponent();

          expect(findGeoSiteSaveButton().attributes('disabled')).toBeUndefined();
        });
      });
    });
  });

  describe('methods', () => {
    describe('saveGeoSite', () => {
      beforeEach(() => {
        createComponent();
      });

      it('calls saveGeoSite when save is clicked', () => {
        findGeoSiteSaveButton().vm.$emit('click');
        expect(saveGeoSiteSpy).toHaveBeenCalledWith(expect.anything(), MOCK_SITE);
      });
    });

    describe('redirect', () => {
      beforeEach(() => {
        createComponent();
      });

      it('calls visitUrl when cancel is clicked', () => {
        findGeoSiteCancelButton().vm.$emit('click');
        expect(visitUrl).toHaveBeenCalledWith(MOCK_SITES_PATH);
      });
    });

    describe('update-sync-options', () => {
      beforeEach(() => {
        createComponent();
      });

      it('should update value of siteData', () => {
        expect(
          findGeoSiteFormSelectiveSyncField().props('siteData')[SELECTIVE_SYNC_NAMESPACES],
        ).toStrictEqual([]);

        findGeoSiteFormSelectiveSyncField().vm.$emit('update-sync-options', {
          key: SELECTIVE_SYNC_NAMESPACES,
          value: MOCK_SYNC_NAMESPACE_IDS,
        });

        expect(
          findGeoSiteFormSelectiveSyncField().props('siteData')[SELECTIVE_SYNC_NAMESPACES],
        ).toStrictEqual(MOCK_SYNC_NAMESPACE_IDS);
      });
    });
  });

  describe('created', () => {
    describe('when site prop exists', () => {
      beforeEach(() => {
        createComponent();
      });

      it('sets siteData to the correct site', () => {
        expect(findGeoSiteFormCoreField().props('siteData')).toMatchObject(MOCK_SITE);
        expect(findGeoSiteFormSelectiveSyncField().props('siteData')).toMatchObject(MOCK_SITE);
        expect(findGeoSiteFormCapacitiesField().props('siteData')).toMatchObject(MOCK_SITE);
      });
    });

    describe('when site prop does not exist', () => {
      beforeEach(() => {
        createComponent({ site: null });
      });

      it('sets siteData to the default site data', () => {
        expect(findGeoSiteFormCoreField().props('siteData')).not.toMatchObject(MOCK_SITE);
        expect(findGeoSiteFormSelectiveSyncField().props('siteData')).not.toMatchObject(MOCK_SITE);
        expect(findGeoSiteFormCapacitiesField().props('siteData')).not.toMatchObject(MOCK_SITE);
      });
    });

    describe('when site.selectiveSyncType is nullish', () => {
      beforeEach(() => {
        createComponent({ site: { ...MOCK_SITE, selectiveSyncType: null } });
      });

      it('sets siteData.selectiveSyncType to empty string', () => {
        const siteData = { ...MOCK_SITE, selectiveSyncType: '' };

        expect(findGeoSiteFormCoreField().props('siteData')).toMatchObject(siteData);
        expect(findGeoSiteFormSelectiveSyncField().props('siteData')).toMatchObject(siteData);
        expect(findGeoSiteFormCapacitiesField().props('siteData')).toMatchObject(siteData);
      });
    });
  });
});
