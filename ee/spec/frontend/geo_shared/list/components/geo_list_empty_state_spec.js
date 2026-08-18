import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import GEO_EMPTY_STATE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-geo-md.svg?url';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListEmptyState from 'ee/geo_shared/list/components/geo_list_empty_state.vue';
import { MOCK_EMPTY_STATE } from '../mock_data';

describe('GeoListEmptyState', () => {
  let wrapper;

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(GeoListEmptyState, {
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findGlLink = () => wrapper.findComponent(GlLink);

  describe.each`
    hasFilters | title                     | description                                                                      | link
    ${false}   | ${MOCK_EMPTY_STATE.title} | ${`No ${MOCK_EMPTY_STATE.itemTitle} were found. Click this link to learn more.`} | ${MOCK_EMPTY_STATE.helpLink}
    ${true}    | ${'No results found'}     | ${'Edit your search filter and try again.'}                                      | ${false}
  `('template when hasFilters is $hasFilters', ({ hasFilters, title, description, link }) => {
    beforeEach(() => {
      createComponent({ props: { emptyState: { ...MOCK_EMPTY_STATE, hasFilters } } });
    });

    it(`sets empty state title to ${title}`, () => {
      expect(findGlEmptyState().props('title')).toBe(title);
    });

    it(`sets empty state description to ${description}`, () => {
      expect(findGlEmptyState().text()).toContain(description);
    });

    it(`does${link ? '' : ' not'} provide a help link`, () => {
      expect(findGlLink().exists() && findGlLink().attributes('href')).toBe(link);
    });

    it('sets empty state image to the geo empty state', () => {
      expect(findGlEmptyState().props('svgPath')).toBe(GEO_EMPTY_STATE_SVG);
    });
  });
});
