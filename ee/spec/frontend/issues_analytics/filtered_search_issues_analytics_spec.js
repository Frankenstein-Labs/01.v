import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import FilteredSearchIssueAnalytics from 'ee/issues_analytics/filtered_search_issues_analytics';
import IssuableFilteredSearchTokenKeys from 'ee/filtered_search/issuable_filtered_search_token_keys';

describe('FilteredSearchIssueAnalytics', () => {
  describe('Token keys', () => {
    const fixture = `<div class="filtered-search-box-input-container"><input class="filtered-search" /></div>`;
    let component;
    let availableTokens;
    let enableMultipleAssigneesSpy;

    const supportedTokenKeys = ['author', 'assignee', 'milestone', 'label', 'epic', 'weight'];

    describe.each`
      shouldEnableMultipleAssignees | hasIssuesCompletedFeature
      ${false}                      | ${false}
      ${true}                       | ${true}
    `(
      'when hasIssuesCompletedFeature=$hasIssuesCompletedFeature',
      ({ hasIssuesCompletedFeature, shouldEnableMultipleAssignees }) => {
        beforeEach(() => {
          setHTMLFixture(fixture);

          enableMultipleAssigneesSpy = jest
            .spyOn(IssuableFilteredSearchTokenKeys, 'enableMultipleAssignees')
            .mockImplementation();
          component = new FilteredSearchIssueAnalytics({ hasIssuesCompletedFeature });
          availableTokens = component.filteredSearchTokenKeys;
        });

        afterEach(() => {
          component = null;

          resetHTMLFixture();
          enableMultipleAssigneesSpy.mockRestore();
        });

        it('should only include the supported token keys', () => {
          const availableTokenKeys = availableTokens.getKeys();

          expect(availableTokenKeys).toEqual(supportedTokenKeys);
        });

        it(`should ${shouldEnableMultipleAssignees ? '' : 'not'} enable multiple assignees`, () => {
          expect(enableMultipleAssigneesSpy).toHaveBeenCalledTimes(
            shouldEnableMultipleAssignees ? 1 : 0,
          );
        });
      },
    );
  });
});
