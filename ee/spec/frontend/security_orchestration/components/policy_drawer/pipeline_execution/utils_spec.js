import {
  humanizeActions,
  humanizeExternalFileAction,
} from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/utils';

const mockActions = [
  {
    content: {
      include: [{ project: 'gitlab-policies/js9', ref: 'main', file: 'README.md' }],
    },
  },
  {
    content: { include: [{ ref: 'main', file: 'README.md', template: 'Template.md' }] },
  },
  {
    content: { include: [{ project: 'gitlab-policies/js9', file: 'README.md' }] },
  },
  { content: { include: [{ file: 'README.md' }] } },
  { content: { include: [{}] } },
  { content: {} },
  { content: undefined },
  { scan: 'invalid' },
  { include: [['/templates/.local.yml', '/templates/.remote.yml']] },
  { include: ['/templates/.local.yml'] },
  { content: { include: [{ file: '' }] } },
];

// Expected outputs for the mockActions. I kept the names simple so that it's easier to read the tests
const file = {
  content: 'README.md',
  label: 'Path',
  type: 'file',
};

const project = {
  content: 'gitlab-policies/js9',
  label: 'Project',
  type: 'project',
};

const ref = {
  content: 'main',
  label: 'Reference',
  type: 'ref',
};

const template = {
  content: 'Template.md',
  label: 'Template',
  type: 'template',
};

const local = {
  content: '/templates/.local.yml',
  label: 'Local',
};

const remote = {
  content: '/templates/.remote.yml',
  label: 'Remote',
};

describe('humanizeExternalFileAction', () => {
  it.each`
    action             | output
    ${mockActions[0]}  | ${{ file, project, ref }}
    ${mockActions[1]}  | ${{ file, ref, template }}
    ${mockActions[2]}  | ${{ file, project }}
    ${mockActions[3]}  | ${{ file }}
    ${mockActions[4]}  | ${{}}
    ${mockActions[5]}  | ${{}}
    ${mockActions[6]}  | ${{}}
    ${mockActions[7]}  | ${{}}
    ${mockActions[8]}  | ${{ local, remote }}
    ${mockActions[9]}  | ${{ local }}
    ${mockActions[11]} | ${{}}
  `('should parse action to messages', ({ action, output }) => {
    expect(humanizeExternalFileAction(action)).toEqual(output);
  });
});

describe('humanizeActions', () => {
  it('should parse action to messages', () => {
    expect(humanizeActions(mockActions)).toEqual([
      { file, project, ref },
      { file, ref, template },
      { file, project },
      { file },
      { local, remote },
      { local },
    ]);
  });
});
