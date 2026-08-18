// Everything the wizard emits on save, as StepWizard builds it.
export const mockWizardState = {
  name: 'Prod gate',
  description: 'Gates production deployments',
  mode: 'enforce',
  scope: { mode: 'all', projects: [], exclusions: [] },
  scopeChanged: true,
  policyData: {
    trigger: 'deployment_requested',
    triggerConfig: {},
    rules: ['custom'],
    ruleConfigs: { custom: { policy: 'package governance' } },
    actions: [],
    actionConfigs: {},
  },
};

// The request params serializePolicyParams builds from mockWizardState.
export const mockPolicyParams = {
  name: 'Prod gate',
  description: 'Gates production deployments',
  mode: 'enforce',
  policy_scope: {},
  trigger_type: 'deployment_requested',
  rules: [{ type: 'custom', value: 'package governance' }],
  actions: [],
};
