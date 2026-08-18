import { DOCS_URL } from '~/constants';

export const testActions = {
  codeAdded: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  created: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  userAdded: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  duoSeatAssigned: {
    url: 'http://example.com/',
    enabled: true,
  },
  pipelineCreated: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  trialStarted: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  codeOwnersEnabled: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  requiredMrApprovalsEnabled: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  mergeRequestCreated: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
  licenseScanningRun: {
    url: `${DOCS_URL}/foobar/`,
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
    openInNewTab: true,
  },
  secureDependencyScanningRun: {
    url: `${DOCS_URL}/foobar/`,
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
    openInNewTab: true,
  },
  secureDastRun: {
    url: `${DOCS_URL}/foobar/`,
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
    openInNewTab: true,
  },
  issueCreated: {
    url: 'http://example.com/',
    svg: 'http://example.com/images/illustration.svg',
    enabled: true,
  },
};

export const testSections = [
  {
    code: {
      svg: 'code.svg',
    },
  },
  {
    workspace: {
      svg: 'workspace.svg',
    },
    deploy: {
      svg: 'deploy.svg',
    },
    plan: {
      svg: 'plan.svg',
    },
  },
];

export const testProject = {
  name: 'test-project',
};
