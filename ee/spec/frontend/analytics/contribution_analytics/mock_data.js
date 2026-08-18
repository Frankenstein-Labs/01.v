import contributionAnalyticsFixture from 'test_fixtures/graphql/analytics/contribution_analytics/graphql/contributions.query.graphql.json';

export { contributionAnalyticsFixture };

export const MOCK_CONTRIBUTIONS = contributionAnalyticsFixture.data.group.contributions.nodes;

export const MOCK_PUSHES = [
  { count: 15, user: 'luffy' },
  { count: 19, user: 'zoro' },
  { count: 21, user: 'nami' },
];

export const MOCK_MERGE_REQUESTS = [
  { created: 5, closed: 7, merged: 4, user: 'luffy' },
  { created: 9, closed: 2, merged: 7, user: 'zoro' },
  { created: 17, closed: 27, merged: 21, user: 'nami' },
];

export const MOCK_ISSUES = [
  { created: 5, closed: 7, user: 'luffy' },
  { created: 9, closed: 2, user: 'zoro' },
  { created: 17, closed: 27, user: 'nami' },
];
