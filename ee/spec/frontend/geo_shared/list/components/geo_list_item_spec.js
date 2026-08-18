import { GlLink, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoListItem from 'ee/geo_shared/list/components/geo_list_item.vue';
import GeoListItemTimeAgo from 'ee/geo_shared/list/components/geo_list_item_time_ago.vue';
import GeoListItemStatus from 'ee/geo_shared/list/components/geo_list_item_status.vue';
import GeoListItemErrors from 'ee/geo_shared/list/components/geo_list_item_errors.vue';
import { MOCK_STATUSES, MOCK_TIME_AGO, MOCK_BULK_ACTIONS, MOCK_ERRORS } from '../mock_data';

describe('GeoListItem', () => {
  let wrapper;

  const defaultProps = {
    name: 'Test Item',
    detailsPath: null,
    statusArray: MOCK_STATUSES,
    timeAgoArray: MOCK_TIME_AGO,
    actionsArray: MOCK_BULK_ACTIONS,
    errorsArray: [],
  };

  const createComponent = ({ props, extraDetails } = {}) => {
    wrapper = shallowMountExtended(GeoListItem, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      scopedSlots: extraDetails ? { 'extra-details': extraDetails } : null,
    });
  };

  const findDetailsLink = () => wrapper.findComponent(GlLink);
  const findNonLinkName = () => wrapper.findByTestId('non-link-name');
  const findStatus = () => wrapper.findComponent(GeoListItemStatus);
  const findActions = () => wrapper.findAllComponents(GlButton);
  const findTimeAgos = () => wrapper.findAllComponents(GeoListItemTimeAgo);
  const findErrors = () => wrapper.findComponent(GeoListItemErrors);
  const findExtraDetails = () => wrapper.findByTestId('extra-details');

  describe('list item status', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GeoListItemStatus with the status array', () => {
      expect(findStatus().props('statusArray')).toStrictEqual(MOCK_STATUSES);
    });
  });

  describe('details link', () => {
    describe('when link is not provided', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the item name as plain text and not link', () => {
        expect(findDetailsLink().exists()).toBe(false);
        expect(findNonLinkName().text()).toBe(defaultProps.name);
      });
    });

    describe('when link is provided', () => {
      beforeEach(() => {
        createComponent({ props: { detailsPath: '/path/to/item' } });
      });

      it('renders the item name as a link', () => {
        expect(findNonLinkName().exists()).toBe(false);
        expect(findDetailsLink().attributes('href')).toBe('/path/to/item');
        expect(findDetailsLink().text()).toBe(defaultProps.name);
      });
    });
  });

  describe('actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders actions with the actions array', () => {
      expect(findActions()).toHaveLength(MOCK_BULK_ACTIONS.length);
    });

    it('on click, emits `action-clicked` with the correct action', async () => {
      await findActions().at(0).vm.$emit('click');

      expect(wrapper.emitted('action-clicked')).toStrictEqual([[MOCK_BULK_ACTIONS[0]]]);
    });

    it.each([true, false])('sets button loading state for loading prop %s', (loading) => {
      const actionsArray = MOCK_BULK_ACTIONS.map((action) => ({ ...action, loading }));
      createComponent({ props: { actionsArray } });

      const loadingStates = findActions().wrappers.map((action) => action.props('loading'));
      expect(loadingStates.every((state) => state === loading)).toBe(true);
    });
  });

  describe('extra details', () => {
    describe('when slot is not provided', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render extra-details slot', () => {
        expect(findExtraDetails().exists()).toBe(false);
      });
    });

    describe('when slot is provided', () => {
      beforeEach(() => {
        createComponent({ extraDetails: '<div>Extra Details</div>' });
      });

      it('does render extra-details slot with slot contents', () => {
        expect(findExtraDetails().text()).toBe('Extra Details ·');
      });
    });
  });

  describe('time ago', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GeoListItemTimeAgo with the time ago array', () => {
      expect(findTimeAgos()).toHaveLength(MOCK_TIME_AGO.length);
    });

    it('renders GeoListTimeAgo with the correct props', () => {
      const expectedProps = findTimeAgos().wrappers.map((w) => w.props());
      const mockProps = [
        { ...MOCK_TIME_AGO[0], showDivider: true },
        { ...MOCK_TIME_AGO[1], showDivider: false },
      ];

      expect(expectedProps).toStrictEqual(mockProps);
    });
  });

  describe('errors', () => {
    describe('with no errors present', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render the errors component', () => {
        expect(findErrors().exists()).toBe(false);
      });
    });

    describe('with errors present', () => {
      beforeEach(() => {
        createComponent({ props: { errorsArray: MOCK_ERRORS } });
      });

      it('renders the errors component with correct errorsArray', () => {
        expect(findErrors().props('errorsArray')).toStrictEqual(MOCK_ERRORS);
      });
    });
  });
});
