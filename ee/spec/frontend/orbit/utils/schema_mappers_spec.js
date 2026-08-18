import {
  mapSchemaDomains,
  buildNodeDomainMap,
  buildDomainColorMap,
  resolveNodeColor,
  filterSchemaNodes,
  filterSchemaEdges,
} from 'ee/orbit/utils/schema_mappers';
import { mockExpandedSchema } from '../mock_data';

describe('schema_mappers', () => {
  describe('mapSchemaDomains', () => {
    it('returns empty array for null input', () => {
      expect(mapSchemaDomains(null)).toEqual([]);
    });

    it('adds count and sorts alphabetically', () => {
      const result = mapSchemaDomains(mockExpandedSchema.domains);

      expect(result[0].name).toBe('ci');
      expect(result[0].count).toBe(3);
      expect(result[1].name).toBe('core');
      expect(result[1].count).toBe(2);
    });
  });

  describe('buildNodeDomainMap', () => {
    it('maps node names to domains', () => {
      const map = buildNodeDomainMap(mockExpandedSchema.nodes);

      expect(map.Job).toBe('ci');
      expect(map.User).toBe('core');
    });

    it('handles null input', () => {
      expect(buildNodeDomainMap(null)).toEqual({});
    });
  });

  describe('buildDomainColorMap', () => {
    it('maps domains to first available color', () => {
      const styleMap = { job: { color: '#f59e0b' }, user: { color: '#ec4899' } };
      const map = buildDomainColorMap(mockExpandedSchema.nodes, styleMap);

      expect(map.ci).toBe('#f59e0b');
      expect(map.core).toBe('#ec4899');
    });

    it('skips domains without color', () => {
      const map = buildDomainColorMap(mockExpandedSchema.nodes, {});

      expect(map).toEqual({});
    });

    it('uses fallback color when style color is missing', () => {
      const map = buildDomainColorMap(mockExpandedSchema.nodes, {}, '#cccccc');

      expect(Object.values(map).every((c) => c === '#cccccc')).toBe(true);
    });

    it('handles null input', () => {
      expect(buildDomainColorMap(null, {})).toEqual({});
    });
  });

  describe('resolveNodeColor', () => {
    const styleMap = { job: { color: '#f59e0b' } };
    const domainColorMap = { ci: '#fbbf24' };
    const nodeDomainMap = { Job: 'ci', Stage: 'ci' };

    it('returns style color when available', () => {
      expect(
        resolveNodeColor('Job', { nodeStyleMap: styleMap, domainColorMap, nodeDomainMap }),
      ).toBe('#f59e0b');
    });

    it('falls back to domain color', () => {
      expect(
        resolveNodeColor('Stage', { nodeStyleMap: styleMap, domainColorMap, nodeDomainMap }),
      ).toBe('#fbbf24');
    });

    it('returns null when no color found', () => {
      expect(
        resolveNodeColor('Unknown', { nodeStyleMap: styleMap, domainColorMap, nodeDomainMap }),
      ).toBeNull();
    });

    it('returns null for null nodeName', () => {
      expect(resolveNodeColor(null, { nodeStyleMap: styleMap })).toBeNull();
    });
  });

  describe('filterSchemaNodes', () => {
    const { nodes } = mockExpandedSchema;

    it('returns all nodes when no filters', () => {
      expect(filterSchemaNodes(nodes)).toHaveLength(5);
    });

    it('returns empty for null input', () => {
      expect(filterSchemaNodes(null)).toEqual([]);
    });

    it('filters by domain', () => {
      const result = filterSchemaNodes(nodes, { domain: 'ci' });

      expect(result).toHaveLength(3);
      expect(result.every((n) => n.domain === 'ci')).toBe(true);
    });

    it('filters by query matching name', () => {
      const result = filterSchemaNodes(nodes, { query: 'User' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('User');
    });

    it('filters by query matching property name', () => {
      const result = filterSchemaNodes(nodes, { query: 'username' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('User');
    });

    it('filters by query matching description', () => {
      const result = filterSchemaNodes(nodes, { query: 'GitLab user' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('User');
    });

    it('is case-insensitive', () => {
      const result = filterSchemaNodes(nodes, { query: 'job' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Job');
    });

    it('combines domain and query filters', () => {
      const result = filterSchemaNodes(nodes, { domain: 'ci', query: 'Job' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('Job');
    });
  });

  describe('filterSchemaEdges', () => {
    const { edges, nodes } = mockExpandedSchema;

    it('returns all edges when no filters', () => {
      expect(filterSchemaEdges(edges, nodes)).toHaveLength(2);
    });

    it('returns empty for null input', () => {
      expect(filterSchemaEdges(null, nodes)).toEqual([]);
    });

    it('filters by query', () => {
      const result = filterSchemaEdges(edges, nodes, { query: 'AUTHORED' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('AUTHORED');
    });

    it('filters by domain membership', () => {
      const result = filterSchemaEdges(edges, nodes, { domain: 'ci' });

      expect(result.some((e) => e.name === 'CONTAINS')).toBe(true);
    });

    it('filters by query matching description', () => {
      const result = filterSchemaEdges(edges, nodes, { query: 'Containment' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('CONTAINS');
    });

    it('combines domain and query filters', () => {
      const result = filterSchemaEdges(edges, nodes, { domain: 'ci', query: 'CONTAINS' });

      expect(result).toHaveLength(1);
      expect(result[0].name).toBe('CONTAINS');
    });

    it('returns empty when domain has no matching edges', () => {
      const result = filterSchemaEdges(edges, nodes, { domain: 'nonexistent' });

      expect(result).toEqual([]);
    });
  });
});
