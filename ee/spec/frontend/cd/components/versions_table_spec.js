import { GlTable, GlTruncate } from '@gitlab/ui';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VersionsTable from 'ee/cd/components/versions_table.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import { makeVersion } from './mock_data';

describe('VersionsTable', () => {
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTruncate = () => wrapper.findComponent(GlTruncate);
  const findTimeAgo = () => wrapper.findComponent(TimeAgo);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(VersionsTable, {
      propsData: {
        versions: [makeVersion()],
        ...props,
      },
    });
  };

  const mountComponent = (props = {}) => {
    wrapper = mountExtended(VersionsTable, {
      propsData: {
        versions: [makeVersion()],
        ...props,
      },
    });
  };

  describe('table rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a GlTable', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('passes versions as items', () => {
      expect(findTable().props('items')).toHaveLength(1);
    });

    it('configures three fields', () => {
      const fields = findTable().props('fields');
      expect(fields).toHaveLength(3);
      expect(fields.map((f) => f.key)).toEqual(['name', 'digest', 'createdAt']);
    });

    it('stacks the table on small viewports', () => {
      expect(findTable().attributes('stacked')).toBe('sm');
    });
  });

  describe('empty state', () => {
    it('shows empty text when no versions are provided', () => {
      createComponent({ versions: [] });

      expect(findTable().attributes('empty-text')).toBe('No versions recorded.');
      expect(findTable().attributes('show-empty')).toBeDefined();
    });
  });

  describe('digest column', () => {
    it('truncates the digest in the middle', () => {
      mountComponent();

      expect(findTruncate().props('text')).toBe('sha256:abc123def456');
      expect(findTruncate().props('position')).toBe('middle');
    });

    it('renders an empty string when the digest is missing', () => {
      mountComponent({ versions: [makeVersion({ digest: null })] });

      expect(findTruncate().props('text')).toBe('');
    });
  });

  describe('createdAt column', () => {
    it('renders the creation time via TimeAgo', () => {
      mountComponent();

      expect(findTimeAgo().props('time')).toBe('2024-06-01T12:00:00Z');
    });

    it('does not render TimeAgo when createdAt is missing', () => {
      mountComponent({ versions: [makeVersion({ createdAt: null })] });

      expect(findTimeAgo().exists()).toBe(false);
    });
  });
});
