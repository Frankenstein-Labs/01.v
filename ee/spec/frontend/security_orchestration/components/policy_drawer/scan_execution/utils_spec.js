import {
  humanizeActions,
  humanizeRules,
} from 'ee/security_orchestration/components/policy_drawer/scan_execution/utils';
import {
  ACTIONS,
  INVALID_RULE_MESSAGE,
  NO_RULE_MESSAGE,
} from 'ee/security_orchestration/components/policy_editor/constants';

jest.mock('~/locale', () => ({
  ...jest.requireActual('~/locale'),
  getPreferredLocales: jest.fn().mockReturnValue(['en']),
}));

const mockActions = [
  { scan: 'dast', scanner_profile: 'Scanner Profile', site_profile: 'Site Profile' },
  { scan: 'dast', scanner_profile: 'Scanner Profile 01', site_profile: 'Site Profile 01' },
  { scan: 'secret_detection' },
  { scan: 'container_scanning' },
  { scan: 'dependency_scanning' },
];

const mockRules = [
  { type: 'pipeline' },
  { type: 'schedule', cadence: '*/10 * * * *', branches: ['main'] },
  { type: 'pipeline', branches: ['release/*', 'staging'] },
  { type: 'pipeline', branches: ['release/1.*', 'canary', 'staging'] },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    agents: { 'default-agent': null },
  },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    agents: { 'default-agent': { namespaces: [] } },
  },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    agents: {
      'default-agent': { namespaces: ['production'] },
    },
  },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    agents: {
      'default-agent': { namespaces: ['staging', 'releases'] },
    },
  },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    agents: {
      'default-agent': { namespaces: ['staging', 'releases', 'dev'] },
    },
    time_window: { duration: 'random', value: 10800 },
  },
  { type: 'pipeline', branches: ['release/*', 'staging'], branch_exceptions: ['main', 'test'] },
  { type: 'pipeline', branches: ['release/*', 'staging'], branch_exceptions: ['main'] },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    branches: ['test'],
    branch_exceptions: ['main', 'test1'],
    time_window: { duration: 'random', value: 3600 },
  },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    agents: {
      'default-agent': { namespaces: ['staging', 'releases', 'dev'] },
    },
    branch_exceptions: ['main', 'test1'],
    time_window: { duration: 'random', value: 7200 },
  },
  { type: 'pipeline', branch_type: 'default' },
];

const mockDefaultTagsCriteria = {
  message: 'Automatically selected runners',
  tags: [],
  action: ACTIONS.tags,
};

const mockDefaultSecurityTemplateCriteria = {
  message: 'With the default security job template',
};

const mockDefaultCriteria = [mockDefaultTagsCriteria, mockDefaultSecurityTemplateCriteria];

const mockRulesBranchType = [
  { type: 'pipeline', branch_type: 'invalid' },
  { type: 'pipeline', branch_type: 'protected' },
  { type: 'pipeline', branch_type: 'default' },
  {
    type: 'schedule',
    cadence: '* */20 4 * *',
    branch_type: 'protected',
  },
];

describe('humanizeActions', () => {
  it('returns an empty Array of actions as an empty Set', () => {
    expect(humanizeActions([])).toStrictEqual([]);
  });

  it('returns a single action as human-readable string', () => {
    expect(humanizeActions([mockActions[0]])).toStrictEqual([
      {
        message: 'Run a %{scannerStart}DAST%{scannerEnd} scan with the following options:',
        criteriaList: mockDefaultCriteria,
      },
    ]);
  });

  it('returns multiple actions as human-readable strings', () => {
    expect(humanizeActions(mockActions)).toStrictEqual([
      {
        message: 'Run a %{scannerStart}DAST%{scannerEnd} scan with the following options:',
        criteriaList: mockDefaultCriteria,
      },
      {
        message:
          'Run a %{scannerStart}Secret detection%{scannerEnd} scan with the following options:',
        criteriaList: mockDefaultCriteria,
      },
      {
        message: 'Run %{scannerStart}Container scanning%{scannerEnd} with the following options:',
        criteriaList: mockDefaultCriteria,
      },
      {
        message: 'Run %{scannerStart}Dependency scanning%{scannerEnd} with the following options:',
        criteriaList: mockDefaultCriteria,
      },
    ]);
  });

  describe('with tags', () => {
    const mockActionsWithTags = [
      { scan: 'sast', tags: ['one-tag'] },
      { scan: 'secret_detection', tags: ['two-tag', 'three-tag'] },
      { scan: 'container_scanning', tags: ['four-tag', 'five-tag', 'six-tag'] },
    ];

    it.each`
      title                   | input                       | output
      ${'one tag'}            | ${[mockActionsWithTags[0]]} | ${[{ message: 'Run a %{scannerStart}SAST%{scannerEnd} scan with the following options:', criteriaList: [{ message: 'On runners with tag:', tags: mockActionsWithTags[0].tags, action: ACTIONS.tags }, mockDefaultSecurityTemplateCriteria] }]}
      ${'two tags'}           | ${[mockActionsWithTags[1]]} | ${[{ message: 'Run a %{scannerStart}Secret detection%{scannerEnd} scan with the following options:', criteriaList: [{ message: 'On runners with the tags:', tags: mockActionsWithTags[1].tags, action: ACTIONS.tags }, mockDefaultSecurityTemplateCriteria] }]}
      ${'more than two tags'} | ${[mockActionsWithTags[2]]} | ${[{ message: 'Run %{scannerStart}Container scanning%{scannerEnd} with the following options:', criteriaList: [{ message: 'On runners with the tags:', tags: mockActionsWithTags[2].tags, action: ACTIONS.tags }, mockDefaultSecurityTemplateCriteria] }]}
    `('$title', ({ input, output }) => {
      expect(humanizeActions(input)).toStrictEqual(output);
    });
  });

  describe('with security template', () => {
    const mockActionsWithSecurityTemplate = [
      { scan: 'dast' },
      { scan: 'sast', template: 'default' },
      { scan: 'secret_detection', template: 'latest' },
    ];

    it.each`
      title            | input                                   | output
      ${'no template'} | ${[mockActionsWithSecurityTemplate[0]]} | ${[{ message: 'Run a %{scannerStart}DAST%{scannerEnd} scan with the following options:', criteriaList: mockDefaultCriteria }]}
      ${'default'}     | ${[mockActionsWithSecurityTemplate[1]]} | ${[{ message: 'Run a %{scannerStart}SAST%{scannerEnd} scan with the following options:', criteriaList: mockDefaultCriteria }]}
      ${'latest'}      | ${[mockActionsWithSecurityTemplate[2]]} | ${[{ message: 'Run a %{scannerStart}Secret detection%{scannerEnd} scan with the following options:', criteriaList: [mockDefaultTagsCriteria, { message: 'With the latest security job template' }] }]}
    `('$title', ({ input, output }) => {
      expect(humanizeActions(input)).toStrictEqual(output);
    });
  });

  describe('with variables', () => {
    const mockActionsWithVariables = [
      { scan: 'sast', variables: [] },
      { scan: 'secret_detection', variables: { variable1: 'value1', variable2: 'value2' } },
    ];

    it.each`
      title             | input                            | output
      ${'no variables'} | ${[mockActionsWithVariables[0]]} | ${[{ message: 'Run a %{scannerStart}SAST%{scannerEnd} scan with the following options:', criteriaList: mockDefaultCriteria }]}
      ${'variables'}    | ${[mockActionsWithVariables[1]]} | ${[{ message: 'Run a %{scannerStart}Secret detection%{scannerEnd} scan with the following options:', criteriaList: [mockDefaultTagsCriteria, mockDefaultSecurityTemplateCriteria, { message: 'With the following customized CI variables:', variables: [{ variable: 'variable1', value: 'value1' }, { variable: 'variable2', value: 'value2' }], action: ACTIONS.variables }] }]}
    `('$title', ({ input, output }) => {
      expect(humanizeActions(input)).toStrictEqual(output);
    });
  });
});

describe('humanizeRules', () => {
  it('returns the empty rules message in an Array if no rules are specified', () => {
    expect(humanizeRules([])).toStrictEqual([{ summary: NO_RULE_MESSAGE }]);
  });

  it('returns the empty rules message in an Array if a single rule is passed in without a branch or agent', () => {
    expect(humanizeRules([mockRules[0]])).toStrictEqual([{ summary: NO_RULE_MESSAGE }]);
  });

  it('returns rules with different number of branches as human-readable strings', () => {
    expect(humanizeRules(mockRules)).toStrictEqual([
      {
        branchExceptions: [],
        summary: 'every 10 minutes, every hour, every day on the main branch',
      },
      {
        branchExceptions: [],
        summary: 'Every time a pipeline runs for the release/* and staging branches',
      },
      {
        branchExceptions: [],
        summary: 'Every time a pipeline runs for the release/1.*, canary and staging branches',
      },
      {
        branchExceptions: [],
        summary:
          'by the agent named default-agent for all namespaces every minute, every 20 hours, on day 4 of the month',
      },
      {
        branchExceptions: [],
        summary:
          'by the agent named default-agent for all namespaces every minute, every 20 hours, on day 4 of the month',
      },
      {
        branchExceptions: [],
        summary:
          'by the agent named default-agent for the production namespace every minute, every 20 hours, on day 4 of the month',
      },
      {
        branchExceptions: [],
        summary:
          'by the agent named default-agent for the staging and releases namespaces every minute, every 20 hours, on day 4 of the month',
      },
      {
        branchExceptions: [],
        summary:
          'by the agent named default-agent for the staging, releases and dev namespaces every minute, every 20 hours, on day 4 of the month with scans distributed over 3 hours',
      },
      {
        branchExceptions: ['main', 'test'],
        summary:
          'Every time a pipeline runs for the release/* and staging branches except branches:',
      },
      {
        branchExceptions: ['main'],
        summary: 'Every time a pipeline runs for the release/* and staging branches except branch:',
      },
      {
        branchExceptions: ['main', 'test1'],
        summary:
          'every minute, every 20 hours, on day 4 of the month on the test branch with scans distributed over 1 hour except branches:',
      },
      {
        branchExceptions: ['main', 'test1'],
        summary:
          'by the agent named default-agent for the staging, releases and dev namespaces every minute, every 20 hours, on day 4 of the month with scans distributed over 2 hours except branches:',
      },
      {
        branchExceptions: [],
        summary: 'Every time a pipeline runs for the default branch',
      },
    ]);
  });

  it('returns the empty rules message in an Array if a single rule is passed in without an invalid branch type', () => {
    expect(humanizeRules([mockRulesBranchType[0]])).toStrictEqual([
      { summary: INVALID_RULE_MESSAGE },
    ]);
  });

  it('returns rules with different branch types as human-readable strings', () => {
    expect(humanizeRules(mockRulesBranchType)).toStrictEqual([
      { summary: INVALID_RULE_MESSAGE },
      {
        branchExceptions: [],
        summary: 'Every time a pipeline runs for any protected branch',
      },
      {
        branchExceptions: [],
        summary: 'Every time a pipeline runs for the default branch',
      },
      {
        branchExceptions: [],
        summary: 'every minute, every 20 hours, on day 4 of the month on any protected branch',
      },
    ]);
  });

  describe('pipeline sources', () => {
    const mockRulesWithPipelineSources = [
      {
        type: 'pipeline',
        branches: ['main'],
        pipeline_sources: { including: ['web'] },
      },
      {
        type: 'pipeline',
        branches: ['main'],
        pipeline_sources: { including: ['web', 'api'] },
      },
      {
        type: 'pipeline',
        branches: ['main'],
        pipeline_sources: { including: ['web', 'api', 'schedule'] },
      },
      {
        type: 'pipeline',
        branch_type: 'default',
        pipeline_sources: { including: ['web'] },
      },
    ];

    it.each`
      title                                                    | rule                               | summary
      ${'creates summary message for single source'}           | ${mockRulesWithPipelineSources[0]} | ${'Every time a pipeline runs for the main branch triggered by Web UI'}
      ${'creates summary message for two sources'}             | ${mockRulesWithPipelineSources[1]} | ${'Every time a pipeline runs for the main branch triggered by Web UI or API request'}
      ${'creates summary message for three sources'}           | ${mockRulesWithPipelineSources[2]} | ${'Every time a pipeline runs for the main branch triggered by Web UI, API request or Scheduled pipeline'}
      ${'creates summary message with branch type and source'} | ${mockRulesWithPipelineSources[3]} | ${'Every time a pipeline runs for the default branch triggered by Web UI'}
    `('$title', ({ rule, summary }) => {
      expect(humanizeRules([rule])[0].summary).toStrictEqual(summary);
    });
  });
});
