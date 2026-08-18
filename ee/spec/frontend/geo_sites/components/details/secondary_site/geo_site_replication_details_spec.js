import { GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoSiteReplicationDetails from 'ee/geo_sites/components/details/secondary_site/geo_site_replication_details.vue';
import GeoSiteReplicationDetailsResponsive from 'ee/geo_sites/components/details/secondary_site/geo_site_replication_details_responsive.vue';
import GeoSiteReplicationStatusMobile from 'ee/geo_sites/components/details/secondary_site/geo_site_replication_status_mobile.vue';
import { MOCK_SECONDARY_SITE, MOCK_SORTED_REPLICABLE_TYPES } from 'ee_jest/geo_sites/mock_data';

Vue.use(Vuex);

describe('GeoSiteReplicationDetails', () => {
  let wrapper;

  const mockSync = {
    dataTypeTitle: MOCK_SORTED_REPLICABLE_TYPES[1].dataTypeTitle,
    namePlural: MOCK_SORTED_REPLICABLE_TYPES[1].namePlural,
    titlePlural: MOCK_SORTED_REPLICABLE_TYPES[1].titlePlural,
    replicationEnabled: true,
    values: { total: 100, success: 0 },
  };

  const mockVerif = {
    dataTypeTitle: MOCK_SORTED_REPLICABLE_TYPES[1].dataTypeTitle,
    namePlural: MOCK_SORTED_REPLICABLE_TYPES[1].namePlural,
    titlePlural: MOCK_SORTED_REPLICABLE_TYPES[1].titlePlural,
    verificationEnabled: true,
    values: { total: 50, success: 50 },
  };

  const defaultProps = {
    site: MOCK_SECONDARY_SITE,
  };

  const createComponent = (props, getters) => {
    const store = new Vuex.Store({
      getters: {
        syncInfo: () => () => [],
        verificationInfo: () => () => [],
        sortedReplicableTypes: () => MOCK_SORTED_REPLICABLE_TYPES,
        ...getters,
      },
    });

    wrapper = shallowMountExtended(GeoSiteReplicationDetails, {
      store,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: { GeoSiteReplicationDetailsResponsive, GlSprintf },
    });
  };

  const findGeoMobileReplicationDetails = () =>
    wrapper.findComponentByTestId('geo-replication-details-mobile');
  const findGeoMobileReplicationStatus = () =>
    findGeoMobileReplicationDetails().findComponent(GeoSiteReplicationStatusMobile);
  const findGeoDesktopReplicationDetails = () =>
    wrapper.findComponentByTestId('geo-replication-details-desktop');
  const findCollapseButton = () => wrapper.findComponent(GlButton);
  const findReplicableComponent = () => wrapper.findByTestId('replicable-component');
  const findReplicableComponentLink = () => findReplicableComponent().findComponent(GlLink);

  describe('template', () => {
    describe('when un-collapsed', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the collapse button correctly', () => {
        expect(findCollapseButton().exists()).toBe(true);
        expect(findCollapseButton().attributes('icon')).toBe('chevron-down');
      });

      it('renders mobile replication details with correct visibility class', () => {
        expect(findGeoMobileReplicationDetails().exists()).toBe(true);
        expect(findGeoMobileReplicationDetails().classes()).toStrictEqual(['@md/panel:!gl-hidden']);
      });

      it('renders mobile replication details with mobile component slot', () => {
        expect(findGeoMobileReplicationStatus().exists()).toBe(true);
      });

      it('renders desktop details with correct visibility class', () => {
        expect(findGeoDesktopReplicationDetails().exists()).toBe(true);
        expect(findGeoDesktopReplicationDetails().classes()).toStrictEqual([
          'gl-hidden',
          '@md/panel:gl-block',
        ]);
      });
    });

    describe('when collapsed', () => {
      beforeEach(() => {
        createComponent();
        findCollapseButton().vm.$emit('click');
      });

      it('renders the collapse button correctly', () => {
        expect(findCollapseButton().exists()).toBe(true);
        expect(findCollapseButton().attributes('icon')).toBe('chevron-right');
      });

      it('does not render mobile replication details', () => {
        expect(findGeoMobileReplicationDetails().exists()).toBe(false);
      });

      it('does not render desktop replication details', () => {
        expect(findGeoDesktopReplicationDetails().exists()).toBe(false);
      });
    });

    const replicationUrl = `/admin/geo/sites/${MOCK_SECONDARY_SITE.id}/replication/${MOCK_SORTED_REPLICABLE_TYPES[1].namePlural}`;

    const mockExpectedNoValues = {
      dataTypeTitle: MOCK_SORTED_REPLICABLE_TYPES[1].dataTypeTitle,
      namePlural: MOCK_SORTED_REPLICABLE_TYPES[1].namePlural,
      titlePlural: MOCK_SORTED_REPLICABLE_TYPES[1].titlePlural,
      replicationView: replicationUrl,
      syncValues: undefined,
      verificationValues: undefined,
    };

    const mockExpectedOnlySync = {
      dataTypeTitle: MOCK_SORTED_REPLICABLE_TYPES[1].dataTypeTitle,
      namePlural: MOCK_SORTED_REPLICABLE_TYPES[1].namePlural,
      titlePlural: MOCK_SORTED_REPLICABLE_TYPES[1].titlePlural,
      replicationView: replicationUrl,
      syncValues: { total: 100, success: 0 },
      verificationValues: undefined,
    };

    const mockExpectedOnlyVerif = {
      dataTypeTitle: MOCK_SORTED_REPLICABLE_TYPES[1].dataTypeTitle,
      namePlural: MOCK_SORTED_REPLICABLE_TYPES[1].namePlural,
      titlePlural: MOCK_SORTED_REPLICABLE_TYPES[1].titlePlural,
      replicationView: replicationUrl,
      syncValues: undefined,
      verificationValues: { total: 50, success: 50 },
    };

    const mockExpectedBothTypes = {
      dataTypeTitle: MOCK_SORTED_REPLICABLE_TYPES[1].dataTypeTitle,
      namePlural: MOCK_SORTED_REPLICABLE_TYPES[1].namePlural,
      titlePlural: MOCK_SORTED_REPLICABLE_TYPES[1].titlePlural,
      replicationView: replicationUrl,
      syncValues: { total: 100, success: 0 },
      verificationValues: { total: 50, success: 50 },
    };

    describe.each`
      description                    | mockSyncData  | mockVerificationData | expectedProps
      ${'with no data'}              | ${[]}         | ${[]}                | ${[mockExpectedNoValues]}
      ${'with no verification data'} | ${[mockSync]} | ${[]}                | ${[mockExpectedOnlySync]}
      ${'with no sync data'}         | ${[]}         | ${[mockVerif]}       | ${[mockExpectedOnlyVerif]}
      ${'with all data'}             | ${[mockSync]} | ${[mockVerif]}       | ${[mockExpectedBothTypes]}
    `('$description', ({ mockSyncData, mockVerificationData, expectedProps }) => {
      beforeEach(() => {
        createComponent(null, {
          syncInfo: () => () => mockSyncData,
          verificationInfo: () => () => mockVerificationData,
          sortedReplicableTypes: () => [MOCK_SORTED_REPLICABLE_TYPES[1]],
        });
      });

      it('passes the correct props to the mobile replication details', () => {
        expect(findGeoMobileReplicationDetails().props()).toStrictEqual({
          replicationItems: expectedProps,
          siteId: MOCK_SECONDARY_SITE.id,
        });
      });

      it('passes the correct props to the desktop replication details', () => {
        expect(findGeoDesktopReplicationDetails().props()).toStrictEqual({
          replicationItems: expectedProps,
          siteId: MOCK_SECONDARY_SITE.id,
        });
      });
    });

    describe('component links', () => {
      describe('when replication is disabled', () => {
        beforeEach(() => {
          createComponent(null, {
            sortedReplicableTypes: () => [
              { ...MOCK_SORTED_REPLICABLE_TYPES[2], replicationEnabled: false },
            ],
          });
        });

        it('renders replicable component title', () => {
          expect(findReplicableComponent().text()).toBe(
            MOCK_SORTED_REPLICABLE_TYPES[2].titlePlural,
          );
        });

        it(`does not render GlLink to secondary replication view`, () => {
          expect(findReplicableComponentLink().exists()).toBe(false);
        });
      });
    });

    describe.each`
      description              | relativeUrl  | expectedUrl
      ${'with relativeUrl'}    | ${'/gitlab'} | ${`/gitlab${replicationUrl}`}
      ${'without relativeUrl'} | ${''}        | ${replicationUrl}
    `(
      'component links $description when replication is enabled',
      ({ relativeUrl, expectedUrl }) => {
        beforeEach(() => {
          gon.relative_url_root = relativeUrl;
          createComponent(null, {
            syncInfo: () => () => [mockSync],
            sortedReplicableTypes: () => [
              { ...MOCK_SORTED_REPLICABLE_TYPES[1], replicationEnabled: true },
            ],
          });
        });

        it(`renders GlLink to secondary replication view`, () => {
          expect(findReplicableComponentLink().exists()).toBe(true);
          expect(findReplicableComponentLink().attributes('href')).toBe(expectedUrl);
        });
      },
    );
  });
});
