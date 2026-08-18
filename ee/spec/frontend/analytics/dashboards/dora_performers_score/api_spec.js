import { extractDoraPerformanceScoreCounts } from 'ee/analytics/dashboards/dora_performers_score/api';
import { mockDoraPerformersScoreResponseData, mockDoraPerformersScoreChartData } from './mock_data';

describe('Dora Performers Score panel api', () => {
  describe('extractDoraPerformanceScoreCounts', () => {
    it('returns each DORA performance score category', () => {
      const categories = extractDoraPerformanceScoreCounts(mockDoraPerformersScoreResponseData).map(
        ({ name }) => name,
      );
      expect(categories).toEqual(['High', 'Medium', 'Low', 'Not included']);
    });

    it('prepares DORA performance score counts for display', () => {
      expect(extractDoraPerformanceScoreCounts(mockDoraPerformersScoreResponseData)).toEqual(
        mockDoraPerformersScoreChartData,
      );
    });
  });
});
