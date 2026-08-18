import * as getters from 'ee/dependencies/store/getters';

describe('Dependencies getters', () => {
  describe('totals', () => {
    it('should return the total from pageInfo', () => {
      const state = {
        pageInfo: {
          total: 42,
        },
      };

      expect(getters.totals(state)).toBe(42);
    });

    it('should return 0 when total is not defined', () => {
      const state = {
        pageInfo: {},
      };

      expect(getters.totals(state)).toBe(0);
    });
  });

  describe('componentNames', () => {
    it('should return the component names in searchFilterParameters', () => {
      const state = {
        searchFilterParameters: {
          component_names: ['git', 'lodash'],
        },
      };

      expect(getters.componentNames(state)).toEqual(['git', 'lodash']);
    });

    it('should return an empty array when there are no component names', () => {
      const state = {
        searchFilterParameters: {},
      };

      expect(getters.componentNames(state)).toEqual([]);
    });
  });
});
