import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoSiteProgressBar from 'ee/geo_sites/components/details/geo_site_progress_bar.vue';
import GeoSiteReplicationStatusMobile from 'ee/geo_sites/components/details/secondary_site/geo_site_replication_status_mobile.vue';

describe('GeoSiteReplicationStatusMobile', () => {
  let wrapper;

  const defaultProps = {
    item: {
      component: 'Test',
      syncValues: null,
      verificationValues: null,
    },
    translations: {
      progressBarSyncTitle: '%{component} synced',
      progressBarVerifTitle: '%{component} verified',
    },
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(GeoSiteReplicationStatusMobile, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findItemSyncStatus = () => wrapper.findByTestId('sync-status');
  const findItemVerificationStatus = () => wrapper.findByTestId('verification-status');

  describe('template', () => {
    describe.each`
      description                    | item
      ${'with no data'}              | ${{ namePlural: 'test_components', titlePlural: 'Test Component', syncValues: null, verificationValues: null }}
      ${'with no verification data'} | ${{ namePlural: 'test_components', titlePlural: 'Test Component', syncValues: { total: 100, success: 0 }, verificationValues: null }}
      ${'with no sync data'}         | ${{ namePlural: 'test_components', titlePlural: 'Test Component', syncValues: null, verificationValues: { total: 50, success: 50 } }}
      ${'with all data'}             | ${{ namePlural: 'test_components', titlePlural: 'Test Component', syncValues: { total: 100, success: 0 }, verificationValues: { total: 50, success: 50 } }}
    `('$description', ({ item }) => {
      beforeEach(() => {
        createComponent({ item });
      });

      it('always renders sync progress bar component with correct target', () => {
        expect(findItemSyncStatus().findComponent(GeoSiteProgressBar).props('target')).toBe(
          'mobile-sync-progress-test_components',
        );
      });

      it('always renders verification progress bar component with correct target', () => {
        expect(findItemVerificationStatus().findComponent(GeoSiteProgressBar).props('target')).toBe(
          'mobile-verification-progress-test_components',
        );
      });
    });
  });
});
