import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoList from 'ee/geo_shared/list/components/geo_list.vue';
import GeoListEmptyState from 'ee/geo_shared/list/components/geo_list_empty_state.vue';
import { MOCK_EMPTY_STATE } from '../mock_data';

describe('GeoList', () => {
  let wrapper;

  const defaultProps = {
    isLoading: false,
    hasItems: false,
    emptyState: MOCK_EMPTY_STATE,
  };

  const createComponent = ({ props, slotContent } = {}) => {
    wrapper = shallowMountExtended(GeoList, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      slots: slotContent ? { default: slotContent } : null,
    });
  };

  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findGeoListEmptyState = () => wrapper.findComponent(GeoListEmptyState);

  describe.each`
    isLoading | hasItems | showLoader | showEmptyState | showDefaultSlot
    ${false}  | ${false} | ${false}   | ${true}        | ${false}
    ${false}  | ${true}  | ${false}   | ${false}       | ${true}
    ${true}   | ${false} | ${true}    | ${false}       | ${false}
    ${true}   | ${true}  | ${true}    | ${false}       | ${false}
  `(
    'template when isLoading is $isLoading and hasItems is $hasItems',
    ({ isLoading, hasItems, showLoader, showEmptyState, showDefaultSlot }) => {
      beforeEach(() => {
        createComponent({
          props: { isLoading, hasItems },
          slotContent: '<div>This is slot content</div>',
        });
      });

      it(`does${showLoader ? '' : ' not'} render loading icon`, () => {
        expect(findGlLoadingIcon().exists()).toBe(showLoader);
      });

      it(`does${showEmptyState ? '' : ' not'} render empty state`, () => {
        expect(findGeoListEmptyState().exists()).toBe(showEmptyState);
      });

      it(`does${showDefaultSlot ? '' : ' not'} render default slot content`, () => {
        expect(wrapper.findByText('This is slot content').exists()).toBe(showDefaultSlot);
      });
    },
  );
});
