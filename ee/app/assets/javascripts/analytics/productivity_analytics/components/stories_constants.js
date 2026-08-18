/* eslint-disable @gitlab/require-i18n-strings */
export const mergeRequests = [
  {
    id: 285,
    iid: 15,
    description: 'Fixes #15',
    title: 'Productivity Analytics merge_request',
    days_to_merge: 24,
    time_to_first_comment: 173,
    time_to_last_commit: 162,
    time_to_merge: 249,
    commits_count: 1,
    loc_per_commit: 3,
    files_touched: 1,
    author_avatar_url:
      'https://www.gravatar.com/avatar/d3e05dc6a5abad23d24bf2b1b9737b7cc2871d87b8ce5aebe1b7a8201fd3684d?s=80&d=identicon',
    merge_request_url: 'http://gdk.test:3001/yaml-config/project-with-data/-/merge_requests/15',
  },
  {
    id: 276,
    iid: 6,
    description: 'Fixes #6',
    title: 'Productivity Analytics merge_request',
    days_to_merge: 13,
    time_to_first_comment: 199,
    time_to_last_commit: -343,
    time_to_merge: 465,
    commits_count: 1,
    loc_per_commit: 3,
    files_touched: 1,
    author_avatar_url:
      'https://www.gravatar.com/avatar/bca13b210f8df07736342b3124da2f55619bca35fbfa6e9165cce4a50fa629a9?s=80&d=identicon',
    merge_request_url: 'http://gdk.test:3001/yaml-config/project-with-data/-/merge_requests/6',
  },
];

export const metricType = 'time_to_first_comment';
export const metricLabel = 'Time from first commit until first comment';

export const metricTypes = [
  {
    key: metricType,
    label: metricLabel,
    charts: ['timeBasedHistogram', 'scatterplot'],
  },
  {
    key: 'time_to_last_commit',
    label: 'Time from first comment to last commit',
    charts: ['timeBasedHistogram', 'scatterplot'],
  },
  {
    key: 'time_to_merge',
    label: 'Time from last commit to merge',
    charts: ['timeBasedHistogram', 'scatterplot'],
  },
];
