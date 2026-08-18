import {
  buildNodeStyleMap,
  entityColorsFromSchema,
  entityNamesFromSchema,
} from 'ee/orbit/utils/node_style_map';
import { ENTITY_TYPE_COLORS } from 'ee/orbit/constants';

describe('node_style_map', () => {
  describe('buildNodeStyleMap', () => {
    it('maps nodes by lowercase name', () => {
      const nodes = [
        {
          name: 'Job',
          domain: 'ci',
          label_field: 'name',
          primary_key: 'id',
          style: { color: '#f59e0b', size: 30 },
        },
      ];
      const map = buildNodeStyleMap(nodes);

      expect(map.job).toEqual({
        name: 'Job',
        domain: 'ci',
        labelField: 'name',
        primaryKey: 'id',
        color: '#f59e0b',
        size: 30,
      });
    });

    it('falls back to ENTITY_TYPE_COLORS when style color is missing', () => {
      const nodes = [{ name: 'User', domain: 'core' }];
      const map = buildNodeStyleMap(nodes);

      expect(map.user.color).toBe(ENTITY_TYPE_COLORS.user);
      expect(map.user.size).toBe(30);
    });

    it('falls back to default color for unknown entity type without style', () => {
      const nodes = [{ name: 'CustomNode', domain: 'custom' }];
      const map = buildNodeStyleMap(nodes);

      expect(map.customnode.color).toBe(ENTITY_TYPE_COLORS.default);
    });

    it('returns empty object for null input', () => {
      expect(buildNodeStyleMap(null)).toEqual({});
    });

    it('returns empty object for empty array', () => {
      expect(buildNodeStyleMap([])).toEqual({});
    });
  });

  describe('entityColorsFromSchema', () => {
    it('extracts colors from nodes with style.color', () => {
      const nodes = [
        { name: 'Job', style: { color: '#f59e0b' } },
        { name: 'User', style: { color: '#ec4899' } },
      ];

      expect(entityColorsFromSchema(nodes)).toEqual({
        job: '#f59e0b',
        user: '#ec4899',
      });
    });

    it('skips nodes without style color', () => {
      const nodes = [
        { name: 'Job', style: { color: '#f59e0b' } },
        { name: 'Stage', style: {} },
        { name: 'User' },
      ];

      expect(entityColorsFromSchema(nodes)).toEqual({ job: '#f59e0b' });
    });

    it('returns empty object for null input', () => {
      expect(entityColorsFromSchema(null)).toEqual({});
    });
  });

  describe('entityNamesFromSchema', () => {
    it('maps lowercase key to original name', () => {
      const nodes = [{ name: 'MergeRequest' }, { name: 'User' }];

      expect(entityNamesFromSchema(nodes)).toEqual({
        mergerequest: 'MergeRequest',
        user: 'User',
      });
    });

    it('returns empty object for null input', () => {
      expect(entityNamesFromSchema(null)).toEqual({});
    });
  });
});
