import {
  MOCK_POLICY_CONFIGURATION_ID,
  POLICY_SCOPE_MOCK,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import {
  PIPELINE_EXECUTION_POLICY_TYPE,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import { DEFAULT_SCHEDULE } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';

/**
 * Naming convention for mocks:
 * mock policy yaml => name ends in `Manifest`
 * mock parsed yaml => name ends in `Object`
 * mock policy for list/drawer => name ends in `Policy`
 *
 * If you have the same policy in multiple forms (e.g. mock yaml and mock parsed yaml that should
 * match), please name them similarly (e.g. fooBarManifest and fooBarObject)
 * and keep them near each other.
 */

export const customYaml = `variable: true
`;

export const invalidYaml = 'variable: true:';

export const customYamlObject = { variable: true };

export const mockPipelineExecutionObject = {
  content: { include: [{ project: '' }] },
  description: '',
  enabled: true,
  name: '',
  pipeline_config_strategy: 'inject_policy',
  skip_ci: {
    allowed: false,
  },
  variables_override: {
    allowed: false,
    exceptions: [],
  },
  type: PIPELINE_EXECUTION_POLICY_TYPE,
};

export const mockWithInjectCiPipelineExecutionObject = {
  content: { include: [{ project: '' }] },
  description: '',
  enabled: true,
  name: '',
  pipeline_config_strategy: 'inject_ci',
  skip_ci: {
    allowed: false,
  },
  type: PIPELINE_EXECUTION_POLICY_TYPE,
};

export const mockSchedulePipelineExecutionObject = {
  content: { include: [{ project: '' }] },
  description: 'like a pipeline_execution_policy but scheduled',
  enabled: true,
  name: '',
  schedules: [DEFAULT_SCHEDULE],
  type: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
};

export const mockSchedulePipelineExecutionManifest = `pipeline_execution_schedule_policy:
  - name: ''
    description: 'like a pipeline_execution_policy but scheduled'
    enabled: true
    schedules:
      - start_time: "00:00"
        time_window:
          distribution: "random"
          value: 3600
        type: "daily"
    content:
      include:
        - project: ''
`;

export const mockDefaultSchedulePipelineExecutionManifest = `name: ''
description: ''
enabled: true
content:
  include:
    - project: ''
skip_ci:
  allowed: false
schedules:
  - type: daily
    start_time: '00:00'
    time_window:
      value: 3600
      distribution: random
type: pipeline_execution_schedule_policy
`;

export const mockSchedulePipelineExecutionWithTypeManifest = `name: ''
description: ''
enabled: true
schedules:
  - start_time: "00:00"
    time_window:
      distribution: "random"
      value: 3600
    type: "daily"
content:
   include:
     - project: gitlab-policies/js6
       ref: main
       file: pipeline_execution_jobs.yml
type: pipeline_execution_schedule_policy
`;

export const mockInvalidStrategyPipelineExecutionPolicy = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: invalid
content:
  include:
    - project: ''
skip_ci:
  allowed: false
`;

export const mockInvalidContentPipelineExecutionPolicy = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: invalid
content:
  include_invalid:
    - project: ''
skip_ci:
  allowed: false
`;

export const mockObjectStrategyPipelineExecutionPolicy = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy:
  type: inject_policy
  apply_on_empty_pipeline: never
content:
  include:
    - project: ''
skip_ci:
  allowed: false
`;

export const mockNoStrategyPipelineExecutionPolicy = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
content:
  include:
    - project: ''
skip_ci:
  allowed: false
`;

export const mockWithScopePipelineExecutionObject = {
  ...mockPipelineExecutionObject,
  policy_scope: { projects: { excluding: [] } },
};

export const mockWithSuffixPipelineExecutionObject = {
  ...mockPipelineExecutionObject,
  suffix: 'on_conflict',
};

export const mockInvalidPipelineExecutionObject = {
  ...mockPipelineExecutionObject,
  pipeline_config_strategy: 'invalid_option',
};

export const customYamlUrlParams = {
  type: PIPELINE_EXECUTION_POLICY_TYPE,
  compliance_framework_id: 1,
  compliance_framework_name: 'Foo',
  path: 'foo@bar',
};

export const customYamlObjectFromUrlParams = (params) => `${customYaml.trim()}
type: ${params.type}
pipeline_config_strategy: override_project_ci
policy_scope:
  compliance_frameworks:
    - id: ${params.compliance_framework_id}
content:
  include:
    - project: bar
      file: foo
metadata:
  compliance_pipeline_migration: true
`;

export const mockWithoutRefPipelineExecutionManifest = `name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: inject_policy
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
type: pipeline_execution_policy
`;

export const mockWithoutRefPipelineExecutionObject = fromYaml({
  manifest: mockWithoutRefPipelineExecutionManifest,
  type: PIPELINE_EXECUTION_POLICY_TYPE,
  addIds: false,
});

export const mockInvalidStrategyPipelineExecutionManifest = `name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: this_is_wrong
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
type: pipeline_execution_policy
`;

export const mockInvalidStrategyPipelineExecutionObject = {
  content: { include: [{ file: '.pipeline-execution.yml', project: 'GitLab.org/GitLab' }] },
  description: 'triggers all protected branches except main',
  enabled: true,
  name: 'Ci config file',
  pipeline_config_strategy: 'this_is_wrong',
  type: PIPELINE_EXECUTION_POLICY_TYPE,
};

export const skipCiConfigurationManifest = `name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: inject_ci
skip_ci:
  allowed: true
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
`;

export const mockPipelineExecutionManifest = `type: pipeline_execution_policy
name: Include external file
description: This policy enforces pipeline execution with configuration from external file
pipeline_config_strategy: inject_policy
enabled: false
content:
   include:
     - project: gitlab-policies/js6
       ref: main
       file: pipeline_execution_jobs.yml
`;

export const mockInvalidTypePipelineExecutionManifest = `invalid_pipeline_execution_policy:
  - name: ''
    description: ''
    enabled: true
    pipeline_config_strategy: inject_policy
    content:
      include:
        - project: ''
    skip_ci:
      allowed: false
    variables_override:
      allowed: false
      exceptions: []`;

export const mockPipelineExecutionWithConfigurationManifest = `type: pipeline_execution_policy
name: Include external file
description: This policy enforces pipeline execution with configuration from external file
pipeline_config_strategy: inject_policy
enabled: false
skip_ci:
   allowed: true
content:
   include:
     - project: gitlab-policies/js6
       ref: main
       file: pipeline_execution_jobs.yml
`;

export const mockPipelineExecutionManifestWithVariablesOverride = `type: pipeline_execution_policy
name: Include external file
description: This policy enforces pipeline execution with configuration from external file
pipeline_config_strategy: inject_policy
enabled: false
content:
   include:
     - project: gitlab-policies/js6
       ref: main
       file: pipeline_execution_jobs.yml
variables_override:
  allowed: false
  exceptions:
    - DAST_BROWSER_DEVTOOLS_LOG
    - DAST_BROWSER_DEVTOOLS
`;

const mockPipelineExecutionWithSnoozeManifest = `name: ''
description: ''
enabled: true
content:
   include:
     - project: gitlab-policies/js6
       ref: main
       file: pipeline_execution_jobs.yml
skip_ci:
  allowed: false
schedules:
  - type: daily
    start_time: '00:00'
    time_window:
      value: 3600
      distribution: random
    snooze:
       reason: This is a reason
       until: "2021-10-13T07:11:00Z"
type: pipeline_execution_schedule_policy
`;

export const mockPipelineScanExecutionObject = {
  type: PIPELINE_EXECUTION_POLICY_TYPE,
  name: 'Include external file',
  description: 'This policy enforces pipeline execution with configuration from external file',
  enabled: false,
  rules: [],
  actions: [
    {
      content: 'include:\n project: gitlab-policies/js9 id: 27 ref: main file: README.md',
    },
  ],
};

export const mockProjectPipelineExecutionPolicy = {
  __typename: 'PipelineExecutionPolicy',
  id: 'gid://gitlab/Security::PipelineExecutionPolicy/1',
  csp: false,
  name: `${mockPipelineScanExecutionObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockPipelineExecutionManifest,
  type: PIPELINE_EXECUTION_POLICY_TYPE,
  editPath: '/policies/policy-name/edit?type="pipeline_execution_policy"',
  policyBlobFilePath: '/path/to/project/-/blob/main/pipeline_execution_jobs.yml',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectPipelineExecutionPolicyList = {
  __typename: 'PipelineExecutionPolicy',
  id: 'gid://gitlab/Security::PipelineExecutionPolicy/1',
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  csp: false,
  name: `${mockPipelineScanExecutionObject.name}-project`,
  policyAttributes: {
    __typename: 'PipelineExecutionPolicyAttributesType',
    source: {
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    },
  },
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockPipelineExecutionManifest,
  editPath: '/policies/policy-name/edit?type="pipeline_execution_policy"',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  type: PIPELINE_EXECUTION_POLICY_TYPE,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectPipelineExecutionWithConfigurationPolicy = {
  ...mockProjectPipelineExecutionPolicy,
  yaml: mockPipelineExecutionWithConfigurationManifest,
};

export const mockProjectPipelineExecutionWithVariablesOverride = {
  ...mockProjectPipelineExecutionPolicy,
  yaml: mockPipelineExecutionManifestWithVariablesOverride,
};

export const mockGroupPipelineExecutionPolicy = {
  ...mockProjectPipelineExecutionPolicy,
  enabled: false,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockGroupPipelineExecutionPolicyList = {
  ...mockProjectPipelineExecutionPolicy,
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  policyAttributes: {
    __typename: 'PipelineExecutionPolicyAttributesType',
    source: {
      __typename: 'GroupSecurityPolicySource',
      inherited: true,
      namespace: {
        __typename: 'Namespace',
        id: '1',
        fullPath: 'parent-group-path',
        name: 'parent-group-name',
      },
    },
  },
  enabled: false,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockProjectPipelineExecutionSchedulePolicy = {
  ...mockProjectPipelineExecutionPolicy,
  editPath: '/policies/policy-name/edit?type="pipeline_execution_schedule_policy"',
  yaml: mockSchedulePipelineExecutionWithTypeManifest,
  __typename: 'PipelineExecutionSchedulePolicy',
};

export const mockProjectPipelineExecutionSchedulePolicyList = {
  ...mockProjectPipelineExecutionPolicyList,
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  policyAttributes: {
    __typename: 'PipelineExecutionScheduledPolicyAttributesType',
    source: {
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    },
  },
  editPath: '/policies/policy-name/edit?type="pipeline_execution_schedule_policy"',
  yaml: mockSchedulePipelineExecutionWithTypeManifest,
  __typename: 'PipelineExecutionSchedulePolicy',
  type: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
};

export const mockSnoozePipelineExecutionSchedulePolicy = {
  ...mockProjectPipelineExecutionPolicy,
  yaml: mockPipelineExecutionWithSnoozeManifest,
  __typename: 'PipelineExecutionSchedulePolicy',
};

export const mockGroupPipelineExecutionSchedulePolicy = {
  ...mockProjectPipelineExecutionSchedulePolicy,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockGroupPipelineExecutionSchedulePolicyList = {
  ...mockGroupPipelineExecutionPolicyList,
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  policyAttributes: {
    __typename: 'PipelineExecutionScheduledPolicyAttributesType',
    source: {
      __typename: 'GroupSecurityPolicySource',
      inherited: true,
      namespace: {
        __typename: 'Namespace',
        id: '1',
        fullPath: 'parent-group-path',
        name: 'parent-group-name',
      },
    },
  },
  __typename: 'PipelineExecutionSchedulePolicy',
  type: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockPipelineExecutionPoliciesResponse = [
  mockProjectPipelineExecutionPolicy,
  mockGroupPipelineExecutionPolicy,
];
export const mockPipelineExecutionSchedulePoliciesResponse = [
  mockProjectPipelineExecutionSchedulePolicy,
  mockGroupPipelineExecutionSchedulePolicy,
];
