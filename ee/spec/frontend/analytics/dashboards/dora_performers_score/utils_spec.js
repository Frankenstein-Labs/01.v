import { DORA_PERFORMERS_SCORE_CATEGORY_TYPES } from 'ee/analytics/dashboards/dora_performers_score/constants';
import {
  groupDoraPerformanceScoreCountsByCategory,
  validateProjectTopics,
} from 'ee/analytics/dashboards/dora_performers_score/utils';
import { mockDoraPerformersScoreResponseData } from './mock_data';

describe('Dora Performers Score panel utils', () => {
  describe('groupDoraPerformanceScoreCountsByCategory', () => {
    it('returns an object with all of the DORA performance score counts with the category as key', () => {
      const grouped = groupDoraPerformanceScoreCountsByCategory(
        mockDoraPerformersScoreResponseData,
      );

      expect(grouped).toEqual({
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.HIGH]: [86, 75, 15, 5],
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.MEDIUM]: [24, 30, 55, 70],
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.LOW]: [27, 25, 80, 81],
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.NO_DATA]: [1, 1, 1, 1],
      });
    });

    it('returns an object with DORA performance score categories as keys and empty arrays as values when given an empty array', () => {
      const grouped = groupDoraPerformanceScoreCountsByCategory([]);

      expect(grouped).toEqual({
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.HIGH]: [],
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.MEDIUM]: [],
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.LOW]: [],
        [DORA_PERFORMERS_SCORE_CATEGORY_TYPES.NO_DATA]: [],
      });
    });
  });

  describe('validateProjectTopics', () => {
    const goodTopics = ['one', 'two', 'three'];
    const badChars = ['\n', '\v', '\f', '\r', '\u0085', '\u2028', '\u2029'].map((c) =>
      encodeURIComponent(c),
    );

    it.each(badChars)(`removes invalid "%s" character`, (char) => {
      const allTopics = goodTopics.concat(`test${decodeURIComponent(char)}`);
      expect(validateProjectTopics(allTopics)).toEqual(goodTopics);
    });

    it.each([undefined, null, [], 0, 'F'])(`returns empty array for "%s"`, (input) => {
      expect(validateProjectTopics(input)).toEqual([]);
    });
  });
});
