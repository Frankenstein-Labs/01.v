import { nextTick } from 'vue';
import { GlBadge, GlButton, GlLoadingIcon, GlModal, GlTable } from '@gitlab/ui';
import mavenUpstreamCacheEntriesFixture from 'test_fixtures/ee/graphql/packages_and_registries/virtual_registries/graphql/queries/get_maven_upstream_cache_entries.query.graphql.json';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import CacheEntriesTable from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/show/cache_entries_table.vue';

describe('CacheEntriesTable', () => {
  let wrapper;

  const mockCacheEntries = mavenUpstreamCacheEntriesFixture.data.upstream.cacheEntries.nodes;
  const [mockCacheEntry] = mockCacheEntries;

  const defaultProps = {
    cacheEntries: mockCacheEntries,
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findDeleteButton = () => wrapper.findComponent(GlButton);
  const findModal = () => wrapper.findComponent(GlModal);
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findTimeAgo = () => wrapper.findComponent(TimeAgoTooltip);
  const findRelativePath = () => wrapper.findByTestId('relative-path');
  const findSize = () => wrapper.findByTestId('artifact-size');

  const createComponent = (props = {}, canDelete = true) => {
    wrapper = mountExtended(CacheEntriesTable, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        glAbilities: { destroyVirtualRegistry: canDelete },
        i18n: {
          upstreams: { deleteCacheModalTitle: 'Delete Maven upstream cache entry?' },
        },
      },
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('displays delete button', () => {
      expect(findDeleteButton().exists()).toBe(true);
    });

    it('displays badge', () => {
      expect(findBadge().text()).toBe(mockCacheEntry.contentType);
    });

    it('displays path', () => {
      expect(findRelativePath().text()).toBe(mockCacheEntry.relativePath);
    });

    it('displays time ago', () => {
      expect(findTimeAgo().props('time')).toBe(mockCacheEntry.upstreamCheckedAt);
    });

    it('displays artifact size', () => {
      expect(findSize().text()).toBe(numberToHumanSize(mockCacheEntry.size));
    });
  });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent({ loading: true });
    });

    it('displays loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('empty state', () => {
    beforeEach(() => {
      createComponent({ cacheEntries: [] });
    });

    it('shows empty state message', () => {
      expect(wrapper.text()).toContain('No artifacts to display.');
    });
  });

  describe('actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays modal on delete action', async () => {
      expect(findModal().props('visible')).toBe(false);

      await findDeleteButton().trigger('click');

      expect(findModal().props('visible')).toBe(true);
    });

    it('emits delete event with correct ID', async () => {
      expect(findModal().props('visible')).toBe(false);

      await findDeleteButton().trigger('click');

      findModal().vm.$emit('primary');

      await nextTick();

      expect(wrapper.emitted('delete')).toStrictEqual([[{ id: mockCacheEntry.id }]]);
    });
  });

  describe('without permission', () => {
    it('does not display delete button', () => {
      createComponent({}, false);

      expect(findDeleteButton().exists()).toBe(false);
    });
  });
});
