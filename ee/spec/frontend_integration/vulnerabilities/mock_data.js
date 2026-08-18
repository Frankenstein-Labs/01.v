export const mockVulnerability = {
  id: 1,
  title: 'Vulnerability Title',
  description: 'Vulnerability Description',
  descriptionHtml: 'Vulnerability Description <code>sample</code>',
  created_at: new Date(2020, 0, 1).toISOString(),
  severity: 'medium',
  state: 'detected',
  reportType: 'secret_detection',
  pipeline: {
    id: 2,
    created_at: new Date(2020, 0, 1).toISOString(),
  },
  project: {
    full_path: '/project_full_path',
  },
  identifiers: [],
  mergeRequestLinks: [],
  archivalInformation: {
    aboutToBeArchived: false,
    expectedToBeArchivedOn: null,
  },
};
