import { GlDisclosureDropdown } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import GeoSiteActionsMobile from 'ee/geo_sites/components/header/geo_site_actions_mobile.vue';
import { MOCK_PRIMARY_SITE } from 'ee_jest/geo_sites/mock_data';

Vue.use(Vuex);

describe('GeoSiteActionsMobile', () => {
  let wrapper;

  const defaultProps = {
    site: MOCK_PRIMARY_SITE,
  };

  const createComponent = (props, getters, mountFn = shallowMountExtended) => {
    const store = new Vuex.Store({
      getters: {
        canRemoveSite: () => () => true,
        ...getters,
      },
    });

    wrapper = mountFn(GeoSiteActionsMobile, {
      store,
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findGeoMobileActionsDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findGeoMobileActionsDisclosureDropdownItems = () =>
    findGeoMobileActionsDisclosureDropdown().props('items');
  const findGeoMobileActionsRemoveDropdownItem = () =>
    wrapper.findByTestId('geo-mobile-remove-action');

  describe('template', () => {
    describe('always', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders Dropdown', () => {
        expect(findGeoMobileActionsDisclosureDropdown().exists()).toBe(true);
      });

      it('renders an Edit and Remove dropdown item', () => {
        expect(
          findGeoMobileActionsDisclosureDropdownItems().map((item) => item.text),
        ).toStrictEqual(['Edit', 'Remove']);
      });

      it('renders edit link correctly', () => {
        expect(findGeoMobileActionsDisclosureDropdownItems()[0].href).toBe(
          MOCK_PRIMARY_SITE.webEditUrl,
        );
      });
    });

    describe('actions', () => {
      beforeEach(() => {
        createComponent(null, null, mountExtended);
      });

      it('emits remove when remove button is clicked', () => {
        findGeoMobileActionsRemoveDropdownItem().trigger('click');

        expect(wrapper.emitted('remove')).toHaveLength(1);
      });
    });

    describe.each`
      canRemoveSite | disabled      | dropdownClass
      ${false}      | ${'disabled'} | ${'!gl-text-disabled'}
      ${true}       | ${undefined}  | ${'!gl-text-danger'}
    `(`conditionally`, ({ canRemoveSite, disabled, dropdownClass }) => {
      beforeEach(() => {
        createComponent({}, { canRemoveSite: () => () => canRemoveSite }, mountExtended);
      });

      describe(`when canRemoveSite is ${canRemoveSite}`, () => {
        it(`does ${
          canRemoveSite ? 'not ' : ''
        }disable the Mobile Remove dropdown item and adds proper class`, () => {
          expect(findGeoMobileActionsRemoveDropdownItem().attributes('disabled')).toBe(disabled);
          expect(findGeoMobileActionsRemoveDropdownItem().classes(dropdownClass)).toBe(true);
        });
      });
    });
  });
});
