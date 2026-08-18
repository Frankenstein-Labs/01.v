import { GlKeysetPagination } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { ACTION_TYPES } from 'ee/geo_replicable/constants';
import GeoReplicable from 'ee/geo_replicable/components/geo_replicable.vue';
import GeoReplicableItem from 'ee/geo_replicable/components/geo_replicable_item.vue';
import { MOCK_BASIC_GRAPHQL_DATA, MOCK_GRAPHQL_PAGINATION_DATA } from '../mock_data';

describe('GeoReplicable', () => {
  let wrapper;

  const defaultProps = {
    replicableItems: MOCK_BASIC_GRAPHQL_DATA,
    pageInfo: MOCK_GRAPHQL_PAGINATION_DATA,
  };

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMount(GeoReplicable, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findGeoReplicableContainer = () => wrapper.find('section');
  const findGlKeysetPagination = () =>
    findGeoReplicableContainer().findComponent(GlKeysetPagination);
  const findGeoReplicableItem = () =>
    findGeoReplicableContainer().findAllComponents(GeoReplicableItem);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the replicable container', () => {
      expect(findGeoReplicableContainer().exists()).toBe(true);
    });

    it('renders an instance for each replicableItem', () => {
      const replicableItemWrappers = findGeoReplicableItem();

      for (let i = 0; i < replicableItemWrappers.length; i += 1) {
        expect(replicableItemWrappers.at(i).props()).toEqual(
          expect.objectContaining({
            registryId: MOCK_BASIC_GRAPHQL_DATA[i].id,
            modelRecordId: MOCK_BASIC_GRAPHQL_DATA[i].modelRecordId,
            syncStatus: MOCK_BASIC_GRAPHQL_DATA[i].state,
            verificationState: MOCK_BASIC_GRAPHQL_DATA[i].verificationState,
            lastSyncFailure: MOCK_BASIC_GRAPHQL_DATA[i].lastSyncFailure,
            verificationFailure: MOCK_BASIC_GRAPHQL_DATA[i].verificationFailure,
          }),
        );
      }
    });

    it('GlKeysetPagination renders', () => {
      createComponent();
      expect(findGlKeysetPagination().exists()).toBe(true);
    });
  });

  describe('changing the page', () => {
    beforeEach(() => {
      createComponent();
    });

    it('to previous page emits the `prev` event with the cursor id', () => {
      findGlKeysetPagination().vm.$emit('prev', 'asdf');

      expect(wrapper.emitted('prev')).toStrictEqual([['asdf']]);
    });

    it('to next page emits the `next` event with the cursor id', () => {
      findGlKeysetPagination().vm.$emit('next', 'asdf');

      expect(wrapper.emitted('next')).toStrictEqual([['asdf']]);
    });
  });

  describe('clicking an action', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits the action-clicked event to the parent', () => {
      findGeoReplicableItem().at(0).vm.$emit('action-clicked', {
        action: ACTION_TYPES.RESYNC,
        name: 'TestRegistry/1',
        registryId: '123',
      });

      expect(wrapper.emitted('action-clicked')).toStrictEqual([
        [{ action: ACTION_TYPES.RESYNC, name: 'TestRegistry/1', registryId: '123' }],
      ]);
    });
  });
});
