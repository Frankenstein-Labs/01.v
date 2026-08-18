import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListItemTimeAgo from 'ee/geo_shared/list/components/geo_list_item_time_ago.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';

const MOCK_LABEL = 'Test Label';
const MOCK_DEFAULT_TEXT = 'Default Text';
const MOCK_JUST_NOW = new Date().toISOString();

describe('GeoListItemTimeAgo', () => {
  let wrapper;

  const defaultProps = {
    label: MOCK_LABEL,
    dateString: MOCK_JUST_NOW,
    defaultText: MOCK_DEFAULT_TEXT,
    showDivider: false,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GeoListItemTimeAgo, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
        TimeAgo,
      },
    });
  };

  const findDateString = () => wrapper.findByTestId('date-string');
  const findDivider = () => wrapper.findByTestId('divider');

  describe.each`
    dateString       | showDivider | expectedText
    ${MOCK_JUST_NOW} | ${true}     | ${`${MOCK_LABEL} just now`}
    ${MOCK_JUST_NOW} | ${false}    | ${`${MOCK_LABEL} just now`}
    ${null}          | ${true}     | ${`${MOCK_LABEL} ${MOCK_DEFAULT_TEXT}`}
    ${null}          | ${false}    | ${`${MOCK_LABEL} ${MOCK_DEFAULT_TEXT}`}
  `('template', ({ dateString, showDivider, expectedText }) => {
    beforeEach(() => {
      createComponent({ dateString, showDivider });
    });

    describe(`with dateString is ${dateString} and showDivider is ${showDivider}`, () => {
      it(`sets Replicable Time Ago text to ${expectedText}`, () => {
        expect(findDateString().text()).toBe(expectedText);
      });

      it(`does${showDivider ? '' : ' not'} show right · divider`, () => {
        expect(findDivider().exists()).toBe(showDivider);
      });
    });
  });
});
