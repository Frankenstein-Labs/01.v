import { GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective } from 'helpers/vue_mock_directive';
import GeoListItemStatus from 'ee/geo_shared/list/components/geo_list_item_status.vue';
import { MOCK_STATUSES } from '../mock_data';

describe('GeoListItemStatus', () => {
  let wrapper;

  const defaultProps = {
    statusArray: MOCK_STATUSES,
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(GeoListItemStatus, {
      propsData: { ...defaultProps },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: { GlBadge },
    });
  };

  const findGlBadges = () => wrapper.findAllComponents(GlBadge);

  describe('Status Badges', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the correct tooltip for each status', () => {
      const expectedTooltips = findGlBadges().wrappers.map((w) => w.attributes('title'));

      expect(expectedTooltips).toStrictEqual(MOCK_STATUSES.map(({ tooltip }) => tooltip));
    });

    it('renders the correct icon for each status', () => {
      const expectedIcons = findGlBadges().wrappers.map((w) => w.props('icon'));

      expect(expectedIcons).toStrictEqual(MOCK_STATUSES.map(({ icon }) => icon));
    });

    it('renders the correct variant for each status', () => {
      const expectedVariants = findGlBadges().wrappers.map((w) => w.props('variant'));

      expect(expectedVariants).toStrictEqual(MOCK_STATUSES.map(({ variant }) => variant));
    });

    it('renders the correct label for each status', () => {
      const expectedLabels = findGlBadges().wrappers.map((w) => w.text());

      expect(expectedLabels).toStrictEqual(MOCK_STATUSES.map(({ label }) => label));
    });
  });
});
