import * as utils from 'ee/vue_shared/security_reports/utils';

describe('utils', () => {
  describe('getSecurityTabPath', () => {
    it.each([
      [undefined, '/security'],
      ['', '/security'],
      ['/foo/bar', '/foo/bar/security'],
    ])("when input is %p, returns '%s'", (input, expected) => {
      expect(utils.getSecurityTabPath(input)).toBe(expected);
    });
  });

  describe('latestNonClosedMergeRequest', () => {
    const open = { id: 'mr-1', state: 'opened' };
    const merged = { id: 'mr-2', state: 'merged' };
    const closed = { id: 'mr-3', state: 'closed' };

    it('returns undefined when given an empty list', () => {
      expect(utils.latestNonClosedMergeRequest([])).toBeUndefined();
    });

    it('returns undefined when called with no argument', () => {
      expect(utils.latestNonClosedMergeRequest()).toBeUndefined();
    });

    it('returns undefined when given null', () => {
      expect(utils.latestNonClosedMergeRequest(null)).toBeUndefined();
    });

    it('returns undefined when all merge requests are closed', () => {
      expect(utils.latestNonClosedMergeRequest([closed, closed])).toBeUndefined();
    });

    it('returns the last non-closed merge request in the list', () => {
      expect(utils.latestNonClosedMergeRequest([open, merged])).toBe(merged);
    });

    it('skips closed merge requests when picking the latest', () => {
      expect(utils.latestNonClosedMergeRequest([open, merged, closed])).toBe(merged);
    });
  });
});
