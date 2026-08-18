import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import GeoSiteFormShards from 'ee/geo_site_form/components/geo_site_form_shards.vue';
import { SELECTIVE_SYNC_SHARDS } from 'ee/geo_site_form/constants';
import { MOCK_SYNC_SHARDS, MOCK_SYNC_SHARD_VALUES } from '../mock_data';

describe('GeoSiteFormShards', () => {
  let wrapper;

  const defaultProps = {
    selectedShards: [],
    syncShardsOptions: MOCK_SYNC_SHARDS,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(GeoSiteFormShards, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findGlCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlCollapsibleListbox', () => {
      expect(findGlCollapsibleListbox().exists()).toBe(true);
    });
  });

  describe('events', () => {
    describe('select', () => {
      beforeEach(() => {
        createComponent();
        findGlCollapsibleListbox().vm.$emit('select', MOCK_SYNC_SHARD_VALUES);
      });

      it('emits update-sync-options with selected options', () => {
        expect(wrapper.emitted('update-sync-options')).toStrictEqual([
          [{ key: SELECTIVE_SYNC_SHARDS, value: MOCK_SYNC_SHARD_VALUES }],
        ]);
      });
    });
  });

  describe('GlCollapsibleListbox props', () => {
    describe('items', () => {
      beforeEach(() => {
        createComponent();
      });

      it('properly formats the dropdown items for the list box', () => {
        const expectedArray = MOCK_SYNC_SHARDS.map((item) => {
          return { ...item, text: item.label };
        });

        expect(findGlCollapsibleListbox().props('items')).toStrictEqual(expectedArray);
      });
    });

    describe('dropdownTitle', () => {
      describe('when selectedShards is empty', () => {
        beforeEach(() => {
          createComponent({
            selectedShards: [],
          });
        });

        it('returns `Select shards to replicate`', () => {
          expect(findGlCollapsibleListbox().props('toggleText')).toBe('Select shards to replicate');
        });
      });

      describe('when selectedShards length === 1', () => {
        beforeEach(() => {
          createComponent({
            selectedShards: [MOCK_SYNC_SHARDS[0].value],
          });
        });

        it('returns 1 shard selected', () => {
          expect(findGlCollapsibleListbox().props('toggleText')).toBe('1 shard selected');
        });
      });

      describe('when selectedShards length > 1', () => {
        beforeEach(() => {
          createComponent({
            selectedShards: [MOCK_SYNC_SHARDS[0].value, MOCK_SYNC_SHARDS[1].value],
          });
        });

        it('returns 2 shards selected', () => {
          expect(findGlCollapsibleListbox().props('toggleText')).toBe('2 shards selected');
        });
      });
    });

    describe('noResultsText', () => {
      describe('when selectedShards is empty', () => {
        beforeEach(() => {
          createComponent();
        });

        it('is set to `Nothing found…`', () => {
          expect(findGlCollapsibleListbox().props('noResultsText')).toBe('Nothing found…');
        });
      });
    });
  });
});
