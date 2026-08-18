import { getLanguageDisplayName } from 'ee/analytics/analytics_dashboards/code_suggestions_languages';

describe('Code Suggestions Languages', () => {
  describe('getLanguageDisplayName', () => {
    it('returns correct display when matching by language ID', () => {
      expect(getLanguageDisplayName('js')).toBe('JavaScript');
    });

    it('returns correct display name when matching by file extension', () => {
      expect(getLanguageDisplayName('h')).toBe('C++');
    });

    it('returns language ID as-is if it does not return a match', () => {
      expect(getLanguageDisplayName('unknown')).toBe('unknown');
    });

    it.each([null, undefined, ''])('returns `null` when languageId=`%s`', (languageId) => {
      expect(getLanguageDisplayName(languageId)).toBeNull();
    });
  });
});
