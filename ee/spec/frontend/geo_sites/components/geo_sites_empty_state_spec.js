import { GlEmptyState } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import GeoSitesEmptyState from 'ee/geo_sites/components/geo_sites_empty_state.vue';
import { GEO_INFO_URL } from 'ee/geo_sites/constants';
import { MOCK_EMPTY_STATE_SVG } from '../mock_data';

describe('GeoSitesEmptyState', () => {
  let wrapper;

  const defaultProps = {
    title: 'test title',
    description: 'test description',
  };

  const defaultProvide = {
    geoSitesEmptyStateSvg: MOCK_EMPTY_STATE_SVG,
    geoLicenseAllows: true,
    manageSubscriptionUrl: 'http://test.host/subscriptions',
  };

  const createComponent = (props, provide) => {
    wrapper = shallowMount(GeoSitesEmptyState, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findGeoEmptyState = () => wrapper.findComponent(GlEmptyState);

  describe('template', () => {
    describe('always', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the Geo Empty State', () => {
        expect(findGeoEmptyState().exists()).toBe(true);
      });

      it('adds the correct SVG', () => {
        expect(findGeoEmptyState().props('svgPath')).toBe(MOCK_EMPTY_STATE_SVG);
      });

      it('sets the title and description', () => {
        expect(wrapper.text()).toContain(defaultProps.title);
        expect(findGeoEmptyState().props('description')).toBe(defaultProps.description);
      });
    });

    describe('when showLearnMoreButton is true', () => {
      describe('when license allows Geo', () => {
        beforeEach(() => {
          createComponent({ showLearnMoreButton: true }, { geoLicenseAllows: true });
        });

        it('renders the learn more button with the correct link', () => {
          expect(findGeoEmptyState().props('primaryButtonText')).toBe(
            GeoSitesEmptyState.i18n.learnMoreButtonText,
          );
          expect(findGeoEmptyState().props('primaryButtonLink')).toBe(GEO_INFO_URL);
        });

        it('does not append the premium license suffix to the description', () => {
          expect(findGeoEmptyState().props('description')).toBe(defaultProps.description);
        });
      });

      describe('when license does not allow Geo', () => {
        beforeEach(() => {
          createComponent({ showLearnMoreButton: true }, { geoLicenseAllows: false });
        });

        it('renders the manage subscription button as primary', () => {
          expect(findGeoEmptyState().props('primaryButtonText')).toBe(
            GeoSitesEmptyState.i18n.manageSubscriptionButtonText,
          );
          expect(findGeoEmptyState().props('primaryButtonLink')).toBe(
            defaultProvide.manageSubscriptionUrl,
          );
        });

        it('renders the learn more button as secondary', () => {
          expect(findGeoEmptyState().props('secondaryButtonText')).toBe(
            GeoSitesEmptyState.i18n.learnMoreButtonText,
          );
          expect(findGeoEmptyState().props('secondaryButtonLink')).toBe(GEO_INFO_URL);
        });

        it('appends the premium license suffix to the description', () => {
          expect(findGeoEmptyState().props('description')).toBe(
            `${defaultProps.description} ${GeoSitesEmptyState.i18n.availableOnPremiumOnly}`,
          );
        });
      });
    });

    describe('when showLearnMoreButton is false', () => {
      beforeEach(() => {
        createComponent({ showLearnMoreButton: false });
      });

      it('does not render the learn more button', () => {
        expect(findGeoEmptyState().props('primaryButtonText')).toBe('');
        expect(findGeoEmptyState().props('primaryButtonLink')).toBe('');
      });

      it('does not append the premium license suffix to the description', () => {
        expect(findGeoEmptyState().props('description')).toBe(defaultProps.description);
      });
    });
  });
});
