import { groupingStrategyFor } from '~/work_items/board/grouping';
import { statusStrategy } from 'ee/work_items/board/grouping/status_strategy';

describe('groupingStrategyFor', () => {
  it('returns the status strategy for the "status" property', () => {
    expect(groupingStrategyFor('status')).toBe(statusStrategy);
  });

  it('returns null for an unsupported property', () => {
    expect(groupingStrategyFor('assignee')).toBe(null);
  });
});
