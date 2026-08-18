import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlFormRadioGroup, GlToggle } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/editor_component.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/rule_section.vue';
import ActionBuilder from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_action.vue';
import OverloadWarningModal from 'ee/security_orchestration/components/overload_warning_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import {
  SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE,
  SCAN_EXECUTION_DEFAULT_POLICY,
  ASSIGNED_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  buildScannerAction,
  buildDefaultScheduleRule,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';

import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
  mockInvalidActionScanExecutionObject,
  mockInvalidRuleScanExecutionObject,
  mockScheduledTemplateScanExecutionObject,
  mockScanExecutionWithDefaultVariablesManifest,
  mockCustomScanExecutionWithDefaultVariablesManifest,
  mockCustomScanExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';

import {
  ACTION_SECTION_DISABLE_ERROR,
  CONDITION_SECTION_DISABLE_ERROR,
  SECURITY_POLICY_ACTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  DEFAULT_CONDITION_STRATEGY,
  DEFAULT_SCANNER,
  SCAN_EXECUTION_PIPELINE_RULE,
  POLICY_ACTION_BUILDER_TAGS_ERROR_KEY,
  POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY,
  RUNNER_TAGS_PARSING_ERROR,
  DAST_SCANNERS_PARSING_ERROR,
  SELECTION_CONFIG_CUSTOM,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { RULE_KEY_MAP } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';
import {
  DEFAULT_SKIP_SI_CONFIGURATION,
  SCAN_EXECUTION_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import { policyBodyToYaml } from 'ee/security_orchestration/components/policy_editor/utils';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import OptimizedScanSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/optimized_scan_selector.vue';
import RuleStrategySelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/strategy_selector.vue';
import { goToYamlMode } from '../policy_editor_helper';

jest.mock('lodash-es', () => ({ ...jest.requireActual('lodash-es'), uniqueId: jest.fn() }));

describe('EditorComponent', () => {
  let wrapper;
  const defaultProjectPath = 'path/to/project';
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';

  const mockCountResponse = (count = 0) =>
    jest.fn().mockResolvedValue({
      data: {
        group: {
          id: '1',
          projects: {
            count,
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);

    return createMockApollo([[getGroupProjectsCount, handler]]);
  };

  const factory = ({ propsData = {}, provide = {}, handler = mockCountResponse() } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        selectedPolicyType: SCAN_EXECUTION_POLICY_TYPE,
        errorSources: [],
        isCreating: false,
        isDeleting: false,
        isEditing: false,
        ...propsData,
      },
      provide: {
        maxScanExecutionPolicyActions: 10,
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.GROUP,
        scanPolicyDocumentationPath,
        ...provide,
      },
      stubs: {
        SkipCiSelector,
      },
    });
  };

  const factoryWithExistingPolicy = ({ policy = {}, provide = {} } = {}) => {
    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...mockDastScanExecutionObject, ...policy },
        isEditing: true,
      },
      provide,
    });
  };

  const findAddActionButton = () => wrapper.findComponentByTestId('add-action');
  const findAddActionButtonWrapper = () => wrapper.findByTestId('add-action-wrapper');
  const findAddRuleButton = () => wrapper.findComponentByTestId('add-rule');
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionBuilder = () => wrapper.findComponent(ActionBuilder);
  const findAllActionBuilders = () => wrapper.findAllComponents(ActionBuilder);
  const findRuleSection = () => wrapper.findComponent(RuleSection);
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findOverloadWarningModal = () => wrapper.findComponent(OverloadWarningModal);
  const findDisabledAction = () => wrapper.findComponentByTestId('disabled-action');
  const findDisabledRule = () => wrapper.findComponentByTestId('disabled-rule');
  const findSkipCiSelector = () => wrapper.findComponent(SkipCiSelector);
  const findOptimizedScanSelector = () => wrapper.findComponent(OptimizedScanSelector);
  const findRuleStrategySelector = () => wrapper.findComponent(RuleStrategySelector);
  const findConfigurationSelection = () => wrapper.findByTestId('configuration-selection');
  const findRadioFormGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findActionBuilderCustomConfig = () => wrapper.findByTestId('custom-action-config');
  const findActionBuilderDefaultConfig = () => wrapper.findByTestId('default-action-config');
  const findActionBuilderDefaultConfigRadioButton = () => findRadioFormGroup().props('options')[0];

  const selectScheduleRule = async () => {
    await findRuleSection().vm.$emit('changed', buildDefaultScheduleRule());
  };

  const navigateToCustomMode = async () => {
    await findRadioFormGroup().vm.$emit('input', SELECTION_CONFIG_CUSTOM);
  };

  beforeEach(() => {
    uniqueId
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}0`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}1`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}2`));
  });

  describe('default', () => {
    describe('scope', () => {
      it.each`
        namespaceType              | expected
        ${NAMESPACE_TYPES.GROUP}   | ${SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE}
        ${NAMESPACE_TYPES.PROJECT} | ${SCAN_EXECUTION_DEFAULT_POLICY}
      `('renders default policy for a $namespaceType', ({ namespaceType, expected }) => {
        factory({ provide: { namespaceType } });

        expect(findPolicyEditorLayout().props('policy')).toEqual(expected);
        expect(findSkipCiSelector().exists()).toBe(true);
      });
    });

    describe('policy', () => {
      it('renders default and custom selections', () => {
        factory();
        expect(findConfigurationSelection().exists()).toBe(true);
      });

      it('renders optimized scanner by default', () => {
        factory();
        expect(findRadioFormGroup().attributes('checked')).toBe('default');
        expect(findActionBuilderDefaultConfigRadioButton().disabled).toBe(false);
      });

      it('does not show custom configuration section', () => {
        factory();
        expect(findActionBuilderDefaultConfig().exists()).toBe(true);
        expect(findActionBuilderCustomConfig().exists()).toBe(false);
      });

      it('disables default configuration when the policy is incompatible', async () => {
        factory();
        await navigateToCustomMode();

        // Add a DAST scan action, but there are many reasons the policy may be invalid for
        // optimized scans. See the getConfiguration method in
        // ee/app/assets/javascripts/security_orchestration/components/policy_editor/scan_execution/lib/index.js
        // for more info
        const dastAction = { scan: 'dast' };
        await findActionBuilder().vm.$emit('changed', dastAction);

        expect(findRadioFormGroup().props('options')[0].disabled).toBe(true);
      });
    });
  });

  describe('modifying a policy', () => {
    it.each`
      status                           | action                            | event              | factoryFn                    | yamlEditorValue
      ${'creating a new policy'}       | ${undefined}                      | ${'save-policy'}   | ${factory}                   | ${policyBodyToYaml(fromYaml({ manifest: mockScanExecutionWithDefaultVariablesManifest, type: SCAN_EXECUTION_POLICY_TYPE }))}
      ${'updating an existing policy'} | ${undefined}                      | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}
      ${'deleting an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE} | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDastScanExecutionManifest}
    `('emits "save" when $status', async ({ action, event, factoryFn, yamlEditorValue }) => {
      factoryFn();
      findPolicyEditorLayout().vm.$emit(event);
      await waitForPromises();
      expect(wrapper.emitted('save')).toEqual([[{ action, policy: yamlEditorValue }]]);
    });
  });

  describe('when a user is not an owner of the project', () => {
    it('displays the empty state with the appropriate properties', () => {
      factory({ provide: { disableScanPolicyUpdate: true } });
      const emptyState = findEmptyState();

      expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
      expect(emptyState.props('primaryButtonLink')).toMatch('scan-execution-policy-editor');
      expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
    });
  });

  describe('yaml mode', () => {
    beforeEach(factory);

    it('renders yaml mode properties correctly', () => {
      expect(findPolicyEditorLayout().props()).toMatchObject({
        parsingError: '',
        yamlEditorValue: mockScanExecutionWithDefaultVariablesManifest,
      });
    });

    it('updates the yaml and policy object when "update-yaml" is emitted', async () => {
      const newManifest = `name: test
enabled: true`;
      await findPolicyEditorLayout().vm.$emit('update-yaml', newManifest);

      expect(findPolicyEditorLayout().props()).toMatchObject({
        parsingError: '',
        policy: expect.objectContaining({ enabled: true }),
        yamlEditorValue: newManifest,
      });
    });

    describe('properties', () => {
      it.each`
        component        | oldValue | newValue
        ${'name'}        | ${''}    | ${'new policy name'}
        ${'description'} | ${''}    | ${'new description'}
        ${'enabled'}     | ${true}  | ${false}
      `('updates the $component property', async ({ component, newValue, oldValue }) => {
        expect(findPolicyEditorLayout().props('policy')[component]).toBe(oldValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${oldValue}`,
        );

        await findPolicyEditorLayout().vm.$emit('update-property', component, newValue);

        expect(findPolicyEditorLayout().props('policy')[component]).toBe(newValue);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toMatch(
          `${component}: ${newValue}`,
        );
      });

      it('removes the policy scope property', async () => {
        const oldValue = {
          policy_scope: { compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] },
        };

        factoryWithExistingPolicy({ policy: oldValue });
        expect(findPolicyEditorLayout().props('policy').policy_scope).toEqual(
          oldValue.policy_scope,
        );
        await findPolicyEditorLayout().vm.$emit('remove-property', 'policy_scope');
        expect(findPolicyEditorLayout().props('policy').policy_scope).toBe(undefined);

        expect(findSkipCiSelector().findComponent(GlToggle).props('value')).toBe(
          !DEFAULT_SKIP_SI_CONFIGURATION.allowed,
        );
      });
    });
  });

  describe('rule builder', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
    });

    describe('default configuration', () => {
      describe('rule strategy selector', () => {
        it('updates the rules when a change is emitted', async () => {
          const rules = [{ branch_type: 'all' }];
          factory();
          expect(findRuleStrategySelector().props('strategy')).toBe(DEFAULT_CONDITION_STRATEGY);
          await findRuleStrategySelector().vm.$emit('changed', {
            strategy: 'any',
            rules,
          });
          expect(findRuleStrategySelector().props('strategy')).toBe('any');
          expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual(rules);
        });

        it('selects the pre-defined strategy for an existing policy', () => {
          factoryWithExistingPolicy({ policy: mockScheduledTemplateScanExecutionObject });
          expect(findRuleStrategySelector().props('strategy')).toBe('scheduled');
        });
      });
    });

    describe('custom configuration', () => {
      it('should add new rule', async () => {
        factory();
        await navigateToCustomMode();
        await findAddRuleButton().vm.$emit('click');

        expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual([
          { branch_type: 'default', id: undefined, type: 'pipeline' },
          {
            branch_type: 'target_default',
            id: undefined,
            pipeline_sources: { including: ['merge_request_event'] },
            type: 'pipeline',
          },
          { branches: ['*'], id: undefined, type: 'pipeline' },
        ]);
        expect(findAllRuleSections()).toHaveLength(3);
      });

      it('should add a new rule if there are zero rules', async () => {
        await factory({
          propsData: { existingPolicy: { name: 'test', rules: [] }, isEditing: true },
        });
        expect(findAllRuleSections()).toHaveLength(0);
        await findAddRuleButton().vm.$emit('click');
        expect(findAllRuleSections()).toHaveLength(1);
      });

      it('should update rule', async () => {
        factory();
        await navigateToCustomMode();
        await findRuleSection().vm.$emit('changed', {
          ...RULE_KEY_MAP[SCAN_EXECUTION_PIPELINE_RULE](),
          branches: ['main'],
        });
        expect(findPolicyEditorLayout().props('policy').rules).toStrictEqual([
          { branches: ['main'], id: undefined, type: 'pipeline' },
          {
            branch_type: 'target_default',
            id: undefined,
            pipeline_sources: { including: ['merge_request_event'] },
            type: 'pipeline',
          },
        ]);
      });

      it('should remove rule', async () => {
        factory();
        await navigateToCustomMode();
        await findAddRuleButton().vm.$emit('click');

        expect(findAllRuleSections()).toHaveLength(3);
        expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(3);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).rules,
        ).toHaveLength(3);

        await findRuleSection().vm.$emit('remove', 1);

        expect(findAllRuleSections()).toHaveLength(2);
        expect(findPolicyEditorLayout().props('policy').rules).toHaveLength(2);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).rules,
        ).toHaveLength(2);
      });
    });
  });

  describe('action builder', () => {
    beforeEach(() => {
      uniqueId.mockRestore();
    });

    describe('default configuration', () => {
      describe('optimized scan selector', () => {
        it('renders optimized scan selector', () => {
          factory();
          expect(findOptimizedScanSelector().exists()).toBe(true);
          expect(findOptimizedScanSelector().props()).toEqual({
            disabled: false,
            actions: [expect.objectContaining({ scan: 'secret_detection', template: 'latest' })],
          });
        });

        it('adds new action when selected', async () => {
          factory();
          await findOptimizedScanSelector().vm.$emit('change', {
            scanner: 'sast',
            enabled: true,
          });
          const finalValue = [
            buildScannerAction({
              scanner: DEFAULT_SCANNER,
              isOptimized: true,
              withDefaultVariables: true,
            }),
            buildScannerAction({ scanner: 'sast', isOptimized: true, withDefaultVariables: true }),
          ];
          expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
          expect(
            fromYaml({
              manifest: findPolicyEditorLayout().props('yamlEditorValue'),
              type: SCAN_EXECUTION_POLICY_TYPE,
            }).actions,
          ).toStrictEqual(finalValue);
        });

        it('removes action when deselected', async () => {
          factory();
          await findOptimizedScanSelector().vm.$emit('change', {
            scanner: 'secret_detection',
            enabled: false,
          });
          expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual([]);
          expect(
            fromYaml({
              manifest: findPolicyEditorLayout().props('yamlEditorValue'),
              type: SCAN_EXECUTION_POLICY_TYPE,
            }).actions,
          ).toStrictEqual([]);
        });
      });
    });

    describe('custom configuration', () => {
      const newActions = [
        {
          scan: 'secret_detection',
          template: 'latest',
          variables: { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' },
        },
      ];
      it('does not show default configuration section', async () => {
        factory();
        await navigateToCustomMode();
        expect(findActionBuilderDefaultConfig().exists()).toBe(false);
        expect(findActionBuilderCustomConfig().exists()).toBe(true);
      });

      it('adds new action', async () => {
        factory();
        await navigateToCustomMode();

        expect(findPolicyEditorLayout().props('policy').actions).toEqual(
          expect.objectContaining(newActions),
        );
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).actions,
        ).toEqual(expect.objectContaining(newActions));

        await findAddActionButton().vm.$emit('click');

        const finalValue = [
          buildScannerAction({
            scanner: DEFAULT_SCANNER,
            isOptimized: true,
            withDefaultVariables: true,
          }),
          buildScannerAction({ scanner: DEFAULT_SCANNER, withDefaultVariables: true }),
        ];

        expect(findPolicyEditorLayout().props('policy').actions).toEqual(finalValue);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).actions,
        ).toEqual(finalValue);
      });

      it('adds a new action if the action property does not exist', async () => {
        factory({
          propsData: { existingPolicy: { name: 'test' }, isEditing: true },
        });
        await navigateToCustomMode();

        expect(findAllActionBuilders()).toHaveLength(0);

        await findAddActionButton().vm.$emit('click');

        expect(findAddActionButtonWrapper().attributes('title')).toBe('');
        expect(findAllActionBuilders()).toHaveLength(1);
      });

      it('updates action', async () => {
        factory();
        await navigateToCustomMode();

        const initialValue = [
          buildScannerAction({
            scanner: DEFAULT_SCANNER,
            withDefaultVariables: true,
            isOptimized: true,
          }),
        ];

        expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(initialValue);
        expect(findPolicyEditorLayout().props('policy').actions).toEqual(
          expect.objectContaining(newActions),
        );
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).actions,
        ).toEqual(expect.objectContaining(newActions));

        const finalValue = [buildScannerAction({ scanner: 'sast', withDefaultVariables: true })];
        await findActionBuilder().vm.$emit('changed', finalValue[0]);

        expect(findPolicyEditorLayout().props('policy').actions).toStrictEqual(finalValue);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).actions,
        ).toStrictEqual(finalValue);
      });

      it('removes action', async () => {
        factory();
        await navigateToCustomMode();
        await findAddActionButton().vm.$emit('click');

        expect(findAllActionBuilders()).toHaveLength(2);
        expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(2);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).actions,
        ).toHaveLength(2);

        await findActionBuilder().vm.$emit('remove', 1);

        expect(findAllActionBuilders()).toHaveLength(1);
        expect(findPolicyEditorLayout().props('policy').actions).toHaveLength(1);
        expect(
          fromYaml({
            manifest: findPolicyEditorLayout().props('yamlEditorValue'),
            type: SCAN_EXECUTION_POLICY_TYPE,
          }).actions,
        ).toHaveLength(1);
      });

      it('limits number of actions', async () => {
        const MAX_ACTIONS = 3;
        factory({ provide: { maxScanExecutionPolicyActions: MAX_ACTIONS } });
        await navigateToCustomMode();

        expect(findAddActionButton().attributes().disabled).toBeUndefined();
        expect(findAllActionBuilders()).toHaveLength(1);

        await findAddActionButton().vm.$emit('click');
        await findAddActionButton().vm.$emit('click');

        expect(findAllActionBuilders()).toHaveLength(MAX_ACTIONS);
        expect(findAddActionButton().attributes().disabled).toBe('true');
        expect(findAddActionButtonWrapper().attributes('title')).toBe(
          'Policy has reached the maximum of 3 actions',
        );
        expect(findAllActionBuilders()).toHaveLength(3);
      });
    });
  });

  describe('parsing errors', () => {
    it.each`
      name               | errorKey                                         | error
      ${'tags'}          | ${POLICY_ACTION_BUILDER_TAGS_ERROR_KEY}          | ${RUNNER_TAGS_PARSING_ERROR}
      ${'DAST profiles'} | ${POLICY_ACTION_BUILDER_DAST_PROFILES_ERROR_KEY} | ${DAST_SCANNERS_PARSING_ERROR}
    `('disables action section when parsing of $name fails', async ({ errorKey, error }) => {
      factory();
      await navigateToCustomMode();
      await findActionBuilder().vm.$emit('parsing-error', errorKey);
      expect(findDisabledAction().props()).toEqual({ disabled: true, error });
      expect(findDisabledRule().props()).toEqual({
        disabled: false,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
    });

    it('disables action section for invalid action', () => {
      factory({
        propsData: { existingPolicy: mockInvalidActionScanExecutionObject, isEditing: true },
      });
      expect(findDisabledAction().props()).toEqual({
        disabled: true,
        error: ACTION_SECTION_DISABLE_ERROR,
      });
      expect(findDisabledRule().props()).toEqual({
        disabled: false,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
    });

    it('does not affect rule section errors', async () => {
      factory({
        propsData: { existingPolicy: mockInvalidRuleScanExecutionObject, isEditing: true },
      });
      expect(findDisabledRule().props()).toEqual({
        disabled: true,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
      await findActionBuilder().vm.$emit('parsing-error', POLICY_ACTION_BUILDER_TAGS_ERROR_KEY);
      expect(findDisabledRule().props()).toEqual({
        disabled: true,
        error: CONDITION_SECTION_DISABLE_ERROR,
      });
    });
  });

  describe('performance warning modal', () => {
    describe('group', () => {
      describe('performance threshold not reached', () => {
        beforeEach(async () => {
          factory();
          await navigateToCustomMode();
        });

        it('saves policy when performance threshold is not reached', async () => {
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
        });

        it('saves policy when performance threshold is not reached and schedule rule is selected', async () => {
          await selectScheduleRule();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
        });
      });

      it('does not show the warning when performance threshold is reached but no schedule rules were selected', async () => {
        factory({
          handler: mockCountResponse(1001),
        });
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(wrapper.emitted('save')[0]).toHaveLength(1);
      });

      describe('performance threshold reached', () => {
        beforeEach(async () => {
          factory({
            handler: mockCountResponse(1001),
          });

          await waitForPromises();
          await navigateToCustomMode();
        });

        it('shows the warning when performance threshold is reached but schedule rules were selected', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();
        });

        it('dismisses the warning without saving the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();

          await findOverloadWarningModal().vm.$emit('cancel-submit');

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')).toBeUndefined();
        });

        it('dismisses the warning and saves the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();

          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
          expect(wrapper.emitted('save')[0][0]).toMatchObject({ action: undefined });
        });

        it('dismisses the warning and deletes the policy', async () => {
          await selectScheduleRule();
          await waitForPromises();

          findPolicyEditorLayout().vm.$emit('remove-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();

          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(false);
          expect(wrapper.emitted('save')[0]).toHaveLength(1);
          expect(wrapper.emitted('save')[0][0]).toMatchObject({
            action: SECURITY_POLICY_ACTIONS.REMOVE,
          });
        });

        it('dismisses the warning without deleting the policy and then edits it', async () => {
          await selectScheduleRule();
          await waitForPromises();
          findPolicyEditorLayout().vm.$emit('remove-policy');
          await waitForPromises();
          await findOverloadWarningModal().vm.$emit('cancel-submit');
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();
          await findOverloadWarningModal().vm.$emit('confirm-submit');
          await waitForPromises();

          expect(wrapper.emitted('save')[0]).toHaveLength(1);
          expect(wrapper.emitted('save')[0][0]).toMatchObject({ action: undefined });
        });

        it('also shows warning modal in yaml mode', async () => {
          await selectScheduleRule();
          await waitForPromises();

          goToYamlMode(findPolicyEditorLayout);
          findPolicyEditorLayout().vm.$emit('save-policy');
          await waitForPromises();

          expect(findOverloadWarningModal().props('visible')).toBe(true);
          expect(wrapper.emitted('save')).toBeUndefined();
        });
      });
    });

    describe('project', () => {
      beforeEach(async () => {
        factory({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
          },
          handler: mockCountResponse(1001),
        });

        await waitForPromises();
        await navigateToCustomMode();
      });

      it('does not show the warning when performance threshold is reached but schedule rules were selected for a project', async () => {
        await selectScheduleRule();
        await waitForPromises();

        findPolicyEditorLayout().vm.$emit('save-policy');
        await waitForPromises();

        expect(findOverloadWarningModal().props('visible')).toBe(false);
        expect(wrapper.emitted('save')[0]).toHaveLength(1);
      });
    });
  });

  describe('skip ci configuration', () => {
    const skipCi = {
      allowed: false,
      allowlist: {
        users: [{ id: 1 }, { id: 2 }],
      },
    };

    it('renders skip ci configuration', () => {
      factory();

      expect(findSkipCiSelector().exists()).toBe(true);
      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual(
        DEFAULT_SKIP_SI_CONFIGURATION,
      );
    });

    it('renders existing skip ci configuration', () => {
      factoryWithExistingPolicy({
        policy: {
          skip_ci: skipCi,
        },
      });

      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual(skipCi);
    });

    it('renders existing default skip ci configuration when it is removed from yaml', async () => {
      factoryWithExistingPolicy({ policy: { skip_ci: skipCi } });

      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual(skipCi);
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDastScanExecutionManifest);
      expect(findSkipCiSelector().props('skipCiConfiguration')).toBe(undefined);
    });
  });

  describe('new yaml format with type as a wrapper', () => {
    it('renders default yaml in new format', () => {
      factoryWithExistingPolicy({ policy: mockCustomScanExecutionObject });
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        mockCustomScanExecutionWithDefaultVariablesManifest,
      );
    });

    it('converts new policy format to old policy format when saved', async () => {
      factory();
      findPolicyEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')).toEqual([
        [
          {
            action: undefined,
            policy: `name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding: []
rules:
  - type: pipeline
    branch_type: default
  - type: pipeline
    branch_type: target_default
    pipeline_sources:
      including:
        - merge_request_event
actions:
  - scan: secret_detection
    template: latest
    variables:
      SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
skip_ci:
  allowed: true
type: scan_execution_policy
`,
          },
        ],
      ]);
    });
  });
});
