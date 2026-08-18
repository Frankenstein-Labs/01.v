import { extractGroupNamespace, filterPathBySearchTerm } from 'ee/dependencies/store/utils';

describe('Dependencies store utils', () => {
  describe('extractGroupNamespace', () => {
    it('returns empty string when source endpoint does not match', () => {
      const invalidEndpoint = '/my-group/my-project/-/dependencies.json';
      expect(extractGroupNamespace(invalidEndpoint)).toBe('');
    });

    it('returns group namespace for a valid endpoint', () => {
      const validEndpoint = '/groups/my-group/-/dependencies.json';
      expect(extractGroupNamespace(validEndpoint)).toBe('my-group');
    });
  });

  describe('filterPathBySearchTerm', () => {
    const data = [
      {
        location: {
          path: 'path',
        },
      },
      {
        location: {
          path: 'file',
        },
      },
    ];

    it('returns all locations if search parameter is empty', () => {
      expect(filterPathBySearchTerm(data, '')).toBe(data);
    });

    it('returns only matching locations', () => {
      expect(filterPathBySearchTerm(data, 'pat')).toStrictEqual([data[0]]);
    });
  });
});
