import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapse, GlEmptyState } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import FallbackAndEdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_and_edge_cases_section.vue';
import {
  CLOSED,
  OPEN,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import EditorLayout from 'ee/security_orchestration/components/policy_editor/editor_layout.vue';
import BotCommentAction from 'ee/security_orchestration/components/policy_editor/scan_result/action/bot_message_action.vue';
import {
  ACTION_LISTBOX_ITEMS,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  BOT_MESSAGE_TYPE,
  buildApprovalAction,
  buildBotMessageAction,
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
  buildDefaultScannerObject,
  DEFAULT_SCANNERS,
  DISABLED_BOT_MESSAGE_ACTION,
  getInvalidBranches,
  REQUIRE_APPROVAL_TYPE,
  SCAN_FINDING,
  WARN_TYPE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import EditorComponent from 'ee/security_orchestration/components/policy_editor/scan_result/editor_component.vue';
import PolicyExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/policy_exceptions.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockDefaultBranchesScanResultObjectWithoutBotAction,
  mockDeprecatedScanResultManifest,
  mockDeprecatedScanResultObject,
  mockLegacyWarnTypeScanResultObject,
  mockFallbackInvalidScanResultManifest,
  mockDefaultBranchesScanResultManifestNewFormat,
  mockDefaultBranchesScanResultManifestWithWrapper,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  APPROVAL_POLICY_DEFAULT_POLICY,
  APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
  ASSIGNED_POLICY_PROJECT,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import {
  buildSettingsList,
  PERMITTED_INVALID_SETTINGS,
  BLOCK_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
  PREVENT_EDITING_APPROVAL_RULES,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import {
  policyBodyToYaml,
  removeIdsFromPolicy,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { SECURITY_POLICY_ACTIONS } from 'ee/security_orchestration/components/policy_editor/constants';
import ActionSection from 'ee/security_orchestration/components/policy_editor/scan_result/action/action_section.vue';
import EnforcementType from 'ee/security_orchestration/components/policy_editor/scan_result/enforcement/enforcement_type.vue';
import RuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/rule_section.vue';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { goToRuleMode } from '../policy_editor_helper';

jest.mock('lodash-es', () => ({ ...jest.requireActual('lodash-es'), uniqueId: jest.fn() }));

jest.mock('ee/security_orchestration/components/policy_editor/scan_result/lib', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/scan_result/lib'),
  getInvalidBranches: jest.fn().mockResolvedValue([]),
}));

describe('EditorComponent', () => {
  let wrapper;
  const defaultProjectPath = 'path/to/project';
  const policyEditorEmptyStateSvgPath = 'path/to/svg';
  const scanPolicyDocumentationPath = 'path/to/docs';

  const defaultGroups = [
    { id: '1', name: 'name1', fullPath: 'fullPath1', descendantGroups: { nodes: [] } },
  ];

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    return createMockApollo([[getSppLinkedProjectsGroups, handler]]);
  };

  const factory = ({
    propsData = {},
    provide = {},
    handler = mockLinkedSppItemsResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(EditorComponent, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        errorSources: [],
        selectedPolicyType: APPROVAL_POLICY_TYPE,
        isCreating: false,
        isDeleting: false,
        isEditing: false,
        ...propsData,
      },
      provide: {
        disableScanPolicyUpdate: false,
        policyEditorEmptyStateSvgPath,
        namespaceId: 1,
        namespacePath: defaultProjectPath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        scanPolicyDocumentationPath,
        ...provide,
      },
    });
  };

  const factoryWithExistingPolicy = ({
    policy = {},
    provide = {},
    handler,
    hasActions = true,
    hasRules = true,
  } = {}) => {
    const existingPolicy = { ...mockDefaultBranchesScanResultObject };

    if (!hasActions) {
      delete existingPolicy.actions;
    }

    if (!hasRules) {
      delete existingPolicy.rules;
    }

    return factory({
      propsData: {
        assignedPolicyProject: ASSIGNED_POLICY_PROJECT,
        existingPolicy: { ...existingPolicy, ...policy },
        isEditing: true,
      },
      provide,
      handler,
    });
  };

  const findDisabledSection = (section) => wrapper.findComponentByTestId(`disabled-${section}`);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findFallbackAndEdgeCasesSection = () => wrapper.findComponent(FallbackAndEdgeCasesSection);
  const findPolicyEditorLayout = () => wrapper.findComponent(EditorLayout);
  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findAllActionSections = () => wrapper.findAllComponents(ActionSection);
  const findAddRuleButton = () => wrapper.findComponentByTestId('add-rule');
  const findTooltip = () =>
    getBinding(wrapper.findByTestId('add-rule-wrapper').element, 'gl-tooltip');
  const findAllRuleSections = () => wrapper.findAllComponents(RuleSection);
  const findSettingsSection = () => wrapper.findComponent(SettingsSection);
  const findEmptyActionsAlert = () => wrapper.findComponentByTestId('empty-actions-alert');
  const findScanFilterSelector = () => wrapper.findComponent(ScanFilterSelector);
  const findBotCommentAction = () => wrapper.findComponent(BotCommentAction);
  const findBotCommentActions = () => wrapper.findAllComponents(BotCommentAction);
  const findAdvancedSectionButton = () => wrapper.findComponentByTestId('collapse-button');
  const findCollapseSection = () => wrapper.findComponent(GlCollapse);
  const findPolicyExceptions = () => wrapper.findComponent(PolicyExceptions);
  const findEnforcementSection = () => wrapper.findComponent(EnforcementType);
  const findWarnTypeAction = () => {
    const action = findActionSection();
    return action.props('isWarnType') === true ? action : { exists: () => false };
  };

  beforeEach(() => {
    getInvalidBranches.mockClear();
    uniqueId
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}0`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}1`))
      .mockImplementationOnce(jest.fn((prefix) => `${prefix}2`));
  });

  afterEach(() => {
    uniqueId.mockRestore();
  });

  describe('rendering', () => {
    it.each`
      namespaceType              | policy
      ${NAMESPACE_TYPES.GROUP}   | ${APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
      ${NAMESPACE_TYPES.PROJECT} | ${APPROVAL_POLICY_DEFAULT_POLICY}
    `('renders the default policy for a $namespaceType', ({ namespaceType, policy }) => {
      factory({ provide: { namespaceType } });
      expect(findPolicyEditorLayout().props('policy')).toStrictEqual(policy);
      expect(findPolicyEditorLayout().props('hasParsingError')).toBe(false);
      expect(findPolicyExceptions().exists()).toBe(true);
    });

    it.each`
      namespaceType              | manifest
      ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
      ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
    `(
      'uses the correct default policy yaml for a $namespaceType',
      ({ namespaceType, manifest }) => {
        factory({ provide: { namespaceType } });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(manifest);
      },
    );

    it('displays the initial rule and add rule button', () => {
      factory();
      expect(findAllRuleSections()).toHaveLength(1);
      expect(findAddRuleButton().exists()).toBe(true);
    });

    describe('when a user is not an owner of the project', () => {
      it('displays the empty state with the appropriate properties', () => {
        factory({ provide: { disableScanPolicyUpdate: true } });

        const emptyState = findEmptyState();

        expect(emptyState.props('primaryButtonLink')).toMatch(scanPolicyDocumentationPath);
        expect(emptyState.props('primaryButtonLink')).toMatch('scan-result-policy-editor');
        expect(emptyState.props('svgPath')).toBe(policyEditorEmptyStateSvgPath);
      });
    });

    describe('existing policy', () => {
      it('displays an approval policy', () => {
        factoryWithExistingPolicy();
        expect(findEmptyActionsAlert().exists()).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDefaultBranchesScanResultManifestWithWrapper,
        );

        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(1);
        expect(findBotCommentActions()).toHaveLength(1);
      });

      it('displays a scan result policy', () => {
        factoryWithExistingPolicy({ policy: mockDeprecatedScanResultObject });
        expect(findPolicyEditorLayout().props('hasParsingError')).toBe(false);
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
          mockDeprecatedScanResultManifest,
        );
        expect(findAllRuleSections()).toHaveLength(1);
        expect(findAllActionSections()).toHaveLength(1);
        expect(findBotCommentActions()).toHaveLength(1);
      });
    });

    describe('additional options section', () => {
      describe('default', () => {
        it('renders enforcement type section', () => {
          factory();
          expect(findEnforcementSection().exists()).toBe(true);
          expect(findEnforcementSection().props()).toEqual({
            enforcement: 'warn',
          });
        });
      });

      describe('enforcement is "enforce"', () => {
        it('does not display the warn action', () => {
          factoryWithExistingPolicy();
          expect(findWarnTypeAction().exists()).toBe(false);
        });

        it('does not display the warn action for legacy warn policies', () => {
          factoryWithExistingPolicy({
            policy: mockLegacyWarnTypeScanResultObject,
          });
          expect(findWarnTypeAction().exists()).toBe(false);
        });

        it('shows the correct scan filter selector options', () => {
          factoryWithExistingPolicy();
          expect(findAllActionSections()).toHaveLength(1);
          expect(findScanFilterSelector().props('shouldDisableFilter')(REQUIRE_APPROVAL_TYPE)).toBe(
            false,
          );
          expect(findScanFilterSelector().props('shouldDisableFilter')(BOT_MESSAGE_TYPE)).toBe(
            true,
          );
          expect(findScanFilterSelector().props('shouldDisableFilter')(WARN_TYPE)).toBe(true);
        });
      });

      describe('enforcement is "warn"', () => {
        it('shows the correct scan filter selector options', async () => {
          factory();
          await findEnforcementSection().vm.$emit('change', 'warn');
          expect(findWarnTypeAction().exists()).toBe(true);
          expect(findAllActionSections()).toHaveLength(1);
          expect(findScanFilterSelector().props('shouldDisableFilter')(REQUIRE_APPROVAL_TYPE)).toBe(
            true,
          );
          expect(findScanFilterSelector().props('shouldDisableFilter')(BOT_MESSAGE_TYPE)).toBe(
            true,
          );
          expect(findScanFilterSelector().props('shouldDisableFilter')(WARN_TYPE)).toBe(false);
        });

        it('does not display the bot comment action', () => {
          factory();
          expect(findWarnTypeAction().exists()).toBe(true);
          expect(findAllActionSections()).toHaveLength(1);
          expect(findBotCommentAction().exists()).toBe(false);
        });
      });

      describe('events', () => {
        it('replaces policy actions with the default actions when enforcement is changed to "enforce"', async () => {
          factoryWithExistingPolicy();
          await findEnforcementSection().vm.$emit('change', 'warn');
          await findEnforcementSection().vm.$emit('change', 'enforce');
          expect(findAllActionSections()).toHaveLength(1);
          expect(findWarnTypeAction().exists()).toBe(false);
          expect(findBotCommentAction().exists()).toBe(true);
        });

        describe('changing enforcement to "warn"', () => {
          it('replaces policy actions with a new warn-type action', async () => {
            factoryWithExistingPolicy();
            expect(findAllActionSections()).toHaveLength(1);
            expect(findBotCommentAction().exists()).toBe(true);
            expect(findWarnTypeAction().exists()).toBe(false);
            await findEnforcementSection().vm.$emit('change', 'warn');
            expect(findAllActionSections()).toHaveLength(1);
            expect(findBotCommentAction().exists()).toBe(false);
            expect(findWarnTypeAction().exists()).toBe(true);
          });

          it('preserves the user-chosen bot comment action', async () => {
            factoryWithExistingPolicy({
              policy: mockDefaultBranchesScanResultObject,
            });
            await findEnforcementSection().vm.$emit('change', 'warn');
            expect(findAllActionSections()).toHaveLength(1);
            expect(findBotCommentAction().exists()).toBe(false);
            expect(findWarnTypeAction().exists()).toBe(true);
            expect(findPolicyEditorLayout().props('policy').actions).toContainEqual(
              expect.objectContaining({
                type: REQUIRE_APPROVAL_TYPE,
                approvals_required: 1,
                user_approvers: ['the.one'],
              }),
            );
          });

          it('updates bot comment to be "true"', async () => {
            factoryWithExistingPolicy();
            expect(findBotCommentAction().exists()).toBe(true);
            await findBotCommentAction().vm.$emit('changed', DISABLED_BOT_MESSAGE_ACTION);
            expect(findBotCommentAction().exists()).toBe(false);
            await findEnforcementSection().vm.$emit('change', 'warn');
            expect(findBotCommentAction().exists()).toBe(false);
            expect(findPolicyEditorLayout().props('policy').actions).toContainEqual(
              expect.objectContaining({ type: BOT_MESSAGE_TYPE, enabled: true }),
            );
          });

          it('updates bot comment to exist', async () => {
            factoryWithExistingPolicy({
              policy: mockDefaultBranchesScanResultObjectWithoutBotAction,
            });
            expect(findAllActionSections()).toHaveLength(1);
            expect(findBotCommentAction().exists()).toBe(true);
            expect(findWarnTypeAction().exists()).toBe(false);
            await findEnforcementSection().vm.$emit('change', 'warn');
            expect(findPolicyEditorLayout().props('policy').actions).toContainEqual(
              expect.objectContaining({ type: BOT_MESSAGE_TYPE, enabled: true }),
            );
          });
        });
      });
    });

    describe('advanced section', () => {
      beforeEach(async () => {
        await factory();
      });

      it('renders the collapse button with the correct text', () => {
        const collapseButton = findAdvancedSectionButton();
        expect(collapseButton.exists()).toBe(true);
        expect(collapseButton.text()).toContain('Advanced');
      });

      it('initializes with the collapse section closed', () => {
        expect(findCollapseSection().props('visible')).toBe(false);
        expect(findAdvancedSectionButton().props('icon')).toBe('chevron-right');
      });

      it('toggles the collapse section when the button is clicked', async () => {
        const collapseButton = findAdvancedSectionButton();
        await collapseButton.vm.$emit('click');
        expect(findCollapseSection().props('visible')).toBe(true);
        expect(collapseButton.props('icon')).toBe('chevron-down');
        await collapseButton.vm.$emit('click');
        expect(findCollapseSection().props('visible')).toBe(false);
        expect(collapseButton.props('icon')).toBe('chevron-right');
      });
    });
  });

  describe('rule mode updates', () => {
    describe('properties', () => {
      it.each`
        component         | oldValue     | newValue
        ${'name'}         | ${''}        | ${'new policy name'}
        ${'description'}  | ${''}        | ${'new description'}
        ${'enabled'}      | ${true}      | ${false}
        ${'policy_scope'} | ${undefined} | ${{ compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] }}
      `('updates the $component property', ({ component, newValue, oldValue }) => {
        factory();
        expect(findPolicyEditorLayout().props('policy')[component]).toEqual(oldValue);
        findPolicyEditorLayout().vm.$emit('update-property', component, newValue);
        expect(findPolicyEditorLayout().props('policy')[component]).toEqual(newValue);
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
      });
    });

    describe('rule section', () => {
      it('adds a new rule', async () => {
        const rulesCount = 1;
        factory();
        expect(findAllRuleSections()).toHaveLength(rulesCount);
        await findAddRuleButton().vm.$emit('click');
        expect(findAllRuleSections()).toHaveLength(rulesCount + 1);
      });

      it('shows correct label for add rule button', () => {
        factory();
        expect(findAddRuleButton().text()).toBe('Add new rule');
        expect(findAddRuleButton().props('disabled')).toBe(false);
        expect(findTooltip().value.disabled).toBe(true);
      });

      it('disables add button when the limit of 5 rules has been reached', () => {
        const limit = 5;
        const { id, ...rule } = mockDefaultBranchesScanResultObject.rules[0];
        factoryWithExistingPolicy({ policy: { rules: [rule, rule, rule, rule, rule] } });
        expect(findAllRuleSections()).toHaveLength(limit);
        expect(findAddRuleButton().props('disabled')).toBe(true);
        expect(findTooltip().value).toMatchObject({
          disabled: false,
          title: 'You can add a maximum of 5 rules.',
        });
      });

      it('updates an existing rule', async () => {
        const newValue = {
          type: 'scan_finding',
          branches: [],
          scanners: [],
          vulnerabilities_allowed: 1,
          severity_levels: [],
          vulnerability_states: [],
        };
        factory();

        await findAllRuleSections().at(0).vm.$emit('changed', newValue);
        expect(findAllRuleSections().at(0).props('initRule')).toEqual(newValue);
        expect(findPolicyEditorLayout().props('policy').rules[0].vulnerabilities_allowed).toBe(1);
      });

      it('deletes the initial rule', async () => {
        const initialRuleCount = 1;
        factory();

        expect(findAllRuleSections()).toHaveLength(initialRuleCount);

        await findAllRuleSections().at(0).vm.$emit('remove', 0);

        expect(findAllRuleSections()).toHaveLength(initialRuleCount - 1);
      });
    });

    describe('action section', () => {
      describe('rendering', () => {
        describe.each`
          namespaceType              | manifest
          ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
          ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
        `('$namespaceType', ({ namespaceType, manifest }) => {
          it('should use the correct default policy yaml for a $namespaceType', () => {
            factory({ provide: { namespaceType } });
            expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(manifest);
          });

          it('displays the approver action and the add action button on the group-level', () => {
            factoryWithExistingPolicy({ provide: { namespaceType } });
            expect(findActionSection().exists()).toBe(true);
            expect(findAllActionSections()).toHaveLength(1);
            expect(findBotCommentActions()).toHaveLength(1);
          });
        });

        describe('bot message action section', () => {
          it('does not display a bot message action section if there is a bot message action in the policy with `enabled: false`', () => {
            factoryWithExistingPolicy({
              policy: {
                ...mockDefaultBranchesScanResultObject,
                actions: [DISABLED_BOT_MESSAGE_ACTION],
              },
            });
            expect(findAllActionSections()).toHaveLength(0);
            expect(findScanFilterSelector().props('filters')).toEqual(ACTION_LISTBOX_ITEMS());
          });

          it('displays a bot message action section if there is no bot message action in the policy', () => {
            factoryWithExistingPolicy({
              policy: mockDefaultBranchesScanResultObjectWithoutBotAction,
            });
            expect(findBotCommentActions()).toHaveLength(1);
          });
        });
      });

      describe('add', () => {
        it('displays the rule selector with approver option, when all bot message is selected', () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });
          expect(findScanFilterSelector().exists()).toBe(true);
          expect(
            findScanFilterSelector().props('customFilterTooltip')({ value: BOT_MESSAGE_TYPE }),
          ).toBe('Merge request approval policies allow a maximum 1 bot message action.');
          expect(
            findScanFilterSelector().props('shouldDisableFilter')({ value: REQUIRE_APPROVAL_TYPE }),
          ).toBe(false);
          expect(findScanFilterSelector().props('filters')).toEqual([
            { text: 'Require Approvers', value: REQUIRE_APPROVAL_TYPE },
            { text: 'Send bot message', value: BOT_MESSAGE_TYPE },
            { text: 'Warn in merge request', value: WARN_TYPE },
          ]);
        });

        it('shows the scan filter selector if there are action types not shown', async () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });
          await findAllActionSections().at(0).vm.$emit('remove');
          expect(findScanFilterSelector().exists()).toBe(true);
          expect(
            findScanFilterSelector().props('customFilterTooltip')({ value: REQUIRE_APPROVAL_TYPE }),
          ).toBe('Merge request approval policies allow a maximum of 5 approver actions.');
          expect(findScanFilterSelector().props('filters')).toEqual([
            { text: 'Require Approvers', value: REQUIRE_APPROVAL_TYPE },
            { text: 'Send bot message', value: BOT_MESSAGE_TYPE },
            { text: 'Warn in merge request', value: WARN_TYPE },
          ]);
        });

        it('updates an existing bot message action to be `enabled: true` when a bot message action is added', async () => {
          factoryWithExistingPolicy({
            policy: {
              ...mockDefaultBranchesScanResultObject,
              actions: [DISABLED_BOT_MESSAGE_ACTION],
            },
          });
          const { id: disabledId, ...disabledAction } = DISABLED_BOT_MESSAGE_ACTION;
          expect(findPolicyEditorLayout().props('policy').actions).toEqual([
            expect.objectContaining(disabledAction),
          ]);
          await findScanFilterSelector().vm.$emit('select', BOT_MESSAGE_TYPE);
          expect(findAllActionSections()).toHaveLength(0);
          expect(findBotCommentActions()).toHaveLength(1);
          const { id, ...action } = buildBotMessageAction();
          expect(findPolicyEditorLayout().props('policy').actions).toEqual([
            expect.objectContaining(action),
          ]);
        });

        it('adds an action when there are no other actions in the policy', async () => {
          factoryWithExistingPolicy({ hasActions: false });
          expect(findAllActionSections()).toHaveLength(0);
          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(1);
        });

        it('adds multiple approval rules', async () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });

          expect(findAllActionSections()).toHaveLength(1);
          expect(findBotCommentActions()).toHaveLength(1);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);

          expect(findAllActionSections()).toHaveLength(2);
          expect(findBotCommentActions()).toHaveLength(1);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);

          expect(findAllActionSections()).toHaveLength(3);
          expect(findBotCommentActions()).toHaveLength(1);
        });

        it('add maximum of 5 approval actions', async () => {
          factoryWithExistingPolicy({ policy: mockDefaultBranchesScanResultObject });

          expect(findAllActionSections()).toHaveLength(1);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(2);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(3);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(4);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(5);

          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);
          expect(findAllActionSections()).toHaveLength(5);
        });

        describe('multiple approval actions', () => {
          it('allows to add multiple approver actions', () => {
            factoryWithExistingPolicy({
              policy: mockDefaultBranchesScanResultObject,
            });

            expect(findScanFilterSelector().exists()).toBe(true);

            expect(
              findScanFilterSelector().props('shouldDisableFilter')({
                value: REQUIRE_APPROVAL_TYPE,
              }),
            ).toBe(false);
            expect(
              findScanFilterSelector().props('customFilterTooltip')({
                value: REQUIRE_APPROVAL_TYPE,
              }),
            ).toBe('Merge request approval policies allow a maximum of 5 approver actions.');
          });
        });
      });

      describe('remove', () => {
        it('removes the approver action', async () => {
          factory();
          expect(findAllActionSections()).toHaveLength(1);
          await findActionSection().vm.$emit('remove');
          expect(findAllActionSections()).toHaveLength(0);
          expect(findPolicyEditorLayout().props('policy').actions).not.toContainEqual(
            buildApprovalAction(),
          );
        });

        it('disables the bot message action', async () => {
          factoryWithExistingPolicy();
          expect(findAllActionSections()).toHaveLength(1);
          expect(findBotCommentActions()).toHaveLength(1);
          await findBotCommentAction().vm.$emit('changed', DISABLED_BOT_MESSAGE_ACTION);
          expect(findAllActionSections()).toHaveLength(1);
          expect(findBotCommentActions()).toHaveLength(0);
          expect(findPolicyEditorLayout().props('policy').actions).toContainEqual(
            DISABLED_BOT_MESSAGE_ACTION,
          );
        });

        it('removes the action approvers when the action is removed', async () => {
          factory();
          await findActionSection().vm.$emit(
            'changed',
            mockDefaultBranchesScanResultObject.actions[0],
          );
          await findAllActionSections().at(0).vm.$emit('remove');
          await findScanFilterSelector().vm.$emit('select', REQUIRE_APPROVAL_TYPE);

          expect(removeIdsFromPolicy(findPolicyEditorLayout().props('policy')).actions).toEqual([
            { approvals_required: 1, type: REQUIRE_APPROVAL_TYPE },
            { type: BOT_MESSAGE_TYPE, enabled: true },
          ]);
        });
      });

      describe('update', () => {
        beforeEach(() => {
          factory();
        });

        it('updates policy action when edited', async () => {
          const UPDATED_ACTION = {
            approvals_required: 1,
            group_approvers_ids: [29],
            id: 'action_0',
            type: REQUIRE_APPROVAL_TYPE,
          };
          await findActionSection().vm.$emit('changed', UPDATED_ACTION);
          expect(findActionSection().props('initAction')).toEqual(UPDATED_ACTION);
        });

        it('creates an error when the action section emits one', async () => {
          await findActionSection().vm.$emit('error');
          expect(findDisabledSection('actions').props('disabled')).toBe(true);
        });
      });
    });
  });

  describe('yaml mode updates', () => {
    beforeEach(factory);

    it('updates the policy yaml and policy object when "update-yaml" is emitted', async () => {
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockDefaultBranchesScanResultManifest);
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(
        mockDefaultBranchesScanResultManifest,
      );
      expect(removeIdsFromPolicy(findPolicyEditorLayout().props('policy'))).toMatchObject(
        removeIdsFromPolicy(mockDefaultBranchesScanResultObject),
      );
    });
  });

  describe('modifying a policy', () => {
    it.each`
      status                           | action                            | event              | factoryFn                    | yamlEditorValue
      ${'creating a new policy'}       | ${undefined}                      | ${'save-policy'}   | ${factory}                   | ${policyBodyToYaml(fromYaml({ manifest: DEFAULT_SCAN_RESULT_POLICY, type: APPROVAL_POLICY_TYPE }))}
      ${'updating an existing policy'} | ${undefined}                      | ${'save-policy'}   | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifestNewFormat}
      ${'deleting an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE} | ${'remove-policy'} | ${factoryWithExistingPolicy} | ${mockDefaultBranchesScanResultManifestNewFormat}
    `('emits "save" when $status', async ({ action, event, factoryFn, yamlEditorValue }) => {
      factoryFn();
      findPolicyEditorLayout().vm.$emit(event);
      await waitForPromises();
      expect(wrapper.emitted('save')).toEqual([
        [{ action, isRuleMode: true, policy: yamlEditorValue }],
      ]);
    });

    it('passes down action errors', () => {
      const errorCause = {
        field: 'approvers_ids',
        message: 'Required approvals exceed eligible approvers.',
        title: 'Logic error',
      };
      factory({ propsData: { errorSources: [['action', '0', 'approvers_ids', [errorCause]]] } });
      expect(findActionSection().props('errors')).toEqual([errorCause]);
    });

    it('does not pass down non-action errors', () => {
      const errorSources = [['rule', '0', 'type']];
      factory({ propsData: { errorSources } });
      expect(findActionSection().props('errors')).toEqual([]);
      expect(findAllRuleSections().at(0).props('errorSources')).toEqual(errorSources);
    });
  });

  describe('yaml mode validation errors', () => {
    it('creates an error for invalid yaml', async () => {
      factory();
      await findPolicyEditorLayout().vm.$emit('update-yaml', 'invalid: manifest:');
      expect(findDisabledSection('actions').props('disabled')).toBe(true);
      expect(findDisabledSection('rules').props('disabled')).toBe(true);
      expect(findDisabledSection('settings').props('disabled')).toBe(true);
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(true);
    });
  });

  describe('branches being validated', () => {
    it.each`
      status                             | value       | output
      ${'invalid branches do not exist'} | ${[]}       | ${''}
      ${'invalid branches exist'}        | ${['main']} | ${'The following branches do not exist on this development project: main. Please review all protected branches to ensure the values are accurate before updating this policy.'}
    `('triggers error event with the correct content when $status', async ({ value, output }) => {
      const rule = { ...mockDefaultBranchesScanResultObject.rules[0], branches: ['main'] };
      getInvalidBranches.mockReturnValue(value);

      factoryWithExistingPolicy({ policy: { rules: [rule] } });

      await goToRuleMode(findPolicyEditorLayout);
      await waitForPromises();
      const errors = wrapper.emitted('error');

      expect(errors[errors.length - 1][0]).toEqual(output);
    });

    it('does not query protected branches when namespaceType is other than project', async () => {
      factoryWithExistingPolicy({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });

      await goToRuleMode(findPolicyEditorLayout);
      await waitForPromises();

      expect(getInvalidBranches).not.toHaveBeenCalled();
    });
  });

  describe('settings section', () => {
    const defaultProjectApprovalConfiguration = {
      [PREVENT_PUSHING_AND_FORCE_PUSHING]: true,
      [BLOCK_BRANCH_MODIFICATION]: true,
      [PREVENT_APPROVAL_BY_AUTHOR]: true,
      [PREVENT_APPROVAL_BY_COMMIT_AUTHOR]: true,
      [REMOVE_APPROVALS_WITH_NEW_COMMIT]: true,
      [REQUIRE_PASSWORD_TO_APPROVE]: false,
      [PREVENT_EDITING_APPROVAL_RULES]: false,
    };

    describe('settings', () => {
      beforeEach(() => {
        factory();
      });

      it('displays setting section', () => {
        expect(findSettingsSection().exists()).toBe(true);
        expect(findSettingsSection().props('settings')).toEqual(
          defaultProjectApprovalConfiguration,
        );
      });

      it('updates the policy when settings change', async () => {
        findAllRuleSections().at(0).vm.$emit('changed', { type: 'any_merge_request' });
        await findSettingsSection().vm.$emit('changed', {
          [PREVENT_APPROVAL_BY_AUTHOR]: false,
        });
        expect(findSettingsSection().props('settings')).toEqual({
          ...buildSettingsList(),
          [PREVENT_APPROVAL_BY_AUTHOR]: false,
        });
      });

      it('updates the policy when a change is emitted for pushingBranchesConfiguration', async () => {
        await findSettingsSection().vm.$emit('changed', {
          [PREVENT_PUSHING_AND_FORCE_PUSHING]: false,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${PREVENT_PUSHING_AND_FORCE_PUSHING}: false`,
        );
      });

      it('updates the policy when a change is emitted for blockBranchModification', async () => {
        await findSettingsSection().vm.$emit('changed', {
          [BLOCK_BRANCH_MODIFICATION]: false,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${BLOCK_BRANCH_MODIFICATION}: false`,
        );
      });

      it('updates the settings containing permitted invalid settings', () => {
        factoryWithExistingPolicy({ policy: { approval_settings: PERMITTED_INVALID_SETTINGS } });
        expect(findPolicyEditorLayout().props('policy')).toEqual(
          expect.objectContaining({ approval_settings: PERMITTED_INVALID_SETTINGS }),
        );
        findAllRuleSections().at(0).vm.$emit('changed', { type: SCAN_FINDING });
        expect(findPolicyEditorLayout().props('policy')).toEqual(
          expect.objectContaining({
            approval_settings: buildSettingsList(),
          }),
        );
      });
    });

    describe('empty policy alert', () => {
      const branchSettingsPolicy = { approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true } };
      const projectSettingsPolicy = { approval_settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true } };
      const bothSettingsPolicy = {
        approval_settings: {
          [BLOCK_BRANCH_MODIFICATION]: true,
          [PREVENT_APPROVAL_BY_AUTHOR]: true,
        },
      };
      const groupBranchModificationSettingsPolicy = {
        actions: [{ type: BOT_MESSAGE_TYPE, enabled: false }],
        approval_settings: {
          [BLOCK_GROUP_BRANCH_MODIFICATION]: { enabled: true, exceptions: [{ id: 1 }] },
        },
      };
      const disabledBotPolicy = {
        actions: [
          { type: REQUIRE_APPROVAL_TYPE, approvals_required: 1 },
          { type: BOT_MESSAGE_TYPE, enabled: false },
        ],
      };
      const disabledBotPolicyWithBranchSettings = {
        approval_settings: { [BLOCK_BRANCH_MODIFICATION]: true },
        actions: [
          { type: REQUIRE_APPROVAL_TYPE, approvals_required: 1 },
          { type: BOT_MESSAGE_TYPE, enabled: false },
        ],
      };
      const disabledBotPolicyWithProjectSettings = {
        approval_settings: { [PREVENT_APPROVAL_BY_AUTHOR]: true },
        actions: [
          { type: REQUIRE_APPROVAL_TYPE, approvals_required: 1 },
          { type: BOT_MESSAGE_TYPE, enabled: false },
        ],
      };

      describe.each`
        title                                                                      | policy                                   | hasActions | hasRules | hasAlert | alertVariant
        ${'has require approval action, settings and rules'}                       | ${bothSettingsPolicy}                    | ${true}    | ${true}  | ${false} | ${''}
        ${'has require approval action and rules but no settings'}                 | ${{}}                                    | ${true}    | ${true}  | ${false} | ${''}
        ${'has rules, no actions, and both settings'}                              | ${bothSettingsPolicy}                    | ${false}   | ${true}  | ${true}  | ${'warning'}
        ${'has rules, no actions, and only branch settings'}                       | ${branchSettingsPolicy}                  | ${false}   | ${true}  | ${true}  | ${'warning'}
        ${'has rules, no actions, and only project settings'}                      | ${projectSettingsPolicy}                 | ${false}   | ${true}  | ${true}  | ${'warning'}
        ${'has rules, no actions, and no settings'}                                | ${{}}                                    | ${false}   | ${true}  | ${true}  | ${'danger'}
        ${'no rules, has actions, and has project settings'}                       | ${disabledBotPolicyWithProjectSettings}  | ${true}    | ${false} | ${true}  | ${'warning'}
        ${'no rules, has actions, and only branch settings'}                       | ${disabledBotPolicyWithBranchSettings}   | ${true}    | ${false} | ${true}  | ${'danger'}
        ${'no rules, has actions, and no settings'}                                | ${disabledBotPolicy}                     | ${true}    | ${false} | ${true}  | ${'danger'}
        ${'has approval actions with disabled bot and branch settings with rules'} | ${disabledBotPolicyWithBranchSettings}   | ${true}    | ${true}  | ${false} | ${''}
        ${'has approval actions with disabled bot but no settings with rules'}     | ${disabledBotPolicy}                     | ${true}    | ${true}  | ${false} | ${''}
        ${'only disabled bot action and group branch modification with rules'}     | ${groupBranchModificationSettingsPolicy} | ${true}    | ${true}  | ${true}  | ${'warning'}
        ${'no rules, no actions, and has project settings'}                        | ${projectSettingsPolicy}                 | ${false}   | ${false} | ${true}  | ${'warning'}
        ${'no rules, no actions, and no settings'}                                 | ${{}}                                    | ${false}   | ${false} | ${true}  | ${'danger'}
      `('$title', ({ policy, hasActions, hasRules, hasAlert, alertVariant }) => {
        beforeEach(() => {
          factoryWithExistingPolicy({ policy, hasActions, hasRules });
        });

        it('renders the alert appropriately', () => {
          expect(findEmptyActionsAlert().exists()).toBe(hasAlert);
          if (hasAlert) {
            expect(findEmptyActionsAlert().props('variant')).toBe(alertVariant);
          }
        });
      });

      it.each`
        title                                                 | policy                                                      | hasRules | expected
        ${'shows correct text for enforced mode'}             | ${branchSettingsPolicy}                                     | ${true}  | ${"For any merge request that matches this policy's rules, no action is applied. This policy overrides the project approval settings and notifies users with a bot message, which means that no approvals are required."}
        ${'shows correct text for warn mode'}                 | ${{ ...branchSettingsPolicy, enforcement_type: WARN_TYPE }} | ${true}  | ${"For any merge request that matches this policy's rules, no action is applied. Users are warned about project approval settings that could have been overridden, if the policy were enforced rather than in warn mode, through a bot message. No additional approvals are required."}
        ${'shows correct text for no rules with settings'}    | ${projectSettingsPolicy}                                    | ${false} | ${'This policy has no rules, so branch-level settings will not be applied. Only project approval settings will take effect.'}
        ${'shows correct text for no rules without settings'} | ${{}}                                                       | ${false} | ${'This policy has no rules to match merge requests against. Add rules for this policy to take effect.'}
      `('$title', ({ policy, hasRules, expected }) => {
        factoryWithExistingPolicy({
          policy,
          hasActions: !hasRules,
          hasRules,
        });
        expect(findEmptyActionsAlert().text()).toBe(expected);
      });
    });

    describe('linked groups', () => {
      describe('graphql request', () => {
        it('fetches when namespace type is project', async () => {
          const mockRequestHandler = mockLinkedSppItemsResponse();
          factory({ handler: mockRequestHandler });
          await waitForPromises();
          expect(mockRequestHandler).toHaveBeenCalledTimes(1);
        });

        it('does not fetch when namespace type is group', async () => {
          const mockRequestHandler = mockLinkedSppItemsResponse();
          factory({
            provide: { namespaceType: NAMESPACE_TYPES.GROUP },
            handler: mockRequestHandler,
          });
          await waitForPromises();
          expect(mockRequestHandler).not.toHaveBeenCalled();
        });
      });

      it('updates the settings if groups are linked', async () => {
        factory({ handler: mockLinkedSppItemsResponse({ groups: defaultGroups }) });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toEqual({
          ...defaultProjectApprovalConfiguration,
          [BLOCK_GROUP_BRANCH_MODIFICATION]: true,
        });
        expect(findPolicyEditorLayout().props('yamlEditorValue')).toContain(
          `${BLOCK_GROUP_BRANCH_MODIFICATION}: true`,
        );
      });

      it('does not update the settings if groups are not linked', async () => {
        factory({ handler: mockLinkedSppItemsResponse() });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toEqual(
          defaultProjectApprovalConfiguration,
        );
        expect(findPolicyEditorLayout().props('yamlEditorValue')).not.toContain(
          BLOCK_GROUP_BRANCH_MODIFICATION,
        );
      });

      it('does not change existing policy settings', async () => {
        const blockGroupBranchModificationSetting = {
          [BLOCK_GROUP_BRANCH_MODIFICATION]: {
            enabled: true,
            exceptions: [{ id: 1 }],
          },
        };
        factoryWithExistingPolicy({
          policy: {
            approval_settings: blockGroupBranchModificationSetting,
          },
          handler: mockLinkedSppItemsResponse({ groups: defaultGroups }),
        });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toMatchObject(
          blockGroupBranchModificationSetting,
        );
      });

      it('adds settings for an existing policy without settings', async () => {
        factoryWithExistingPolicy({
          handler: mockLinkedSppItemsResponse({ groups: defaultGroups }),
        });
        await waitForPromises();
        expect(findSettingsSection().props('settings')).toMatchObject({
          [BLOCK_GROUP_BRANCH_MODIFICATION]: true,
        });
      });
    });
  });

  describe('fallback and edge cases section', () => {
    it('renders the section without properties in the yaml', () => {
      factory();
      expect(findFallbackAndEdgeCasesSection().props('policy')).toMatchObject(
        expect.objectContaining({
          fallback_behavior: { fail: CLOSED },
        }),
      );
    });

    it('renders the fallback section with the fallback property in the yaml', () => {
      factoryWithExistingPolicy({
        policy: { fallback_behavior: { fail: OPEN } },
      });
      expect(findFallbackAndEdgeCasesSection().props('policy')).toMatchObject(
        expect.objectContaining({
          fallback_behavior: { fail: OPEN },
        }),
      );
    });

    it('handles update event', () => {
      factory();
      findFallbackAndEdgeCasesSection().vm.$emit('changed', 'fallback_behavior', {
        fail: OPEN,
      });
      expect(findFallbackAndEdgeCasesSection().props('policy')).toMatchObject(
        expect.objectContaining({
          fallback_behavior: { fail: OPEN },
        }),
      );
    });

    it('clears the fallback parsing error on update', async () => {
      factory();
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(false);
      await findPolicyEditorLayout().vm.$emit('update-yaml', mockFallbackInvalidScanResultManifest);
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(true);
      await findFallbackAndEdgeCasesSection().vm.$emit('changed', 'fallback_behavior', {
        fail: OPEN,
      });
      expect(findFallbackAndEdgeCasesSection().props('hasError')).toBe(false);
    });
  });

  describe('bypass options', () => {
    it('renders bypass policy exceptions', () => {
      factory();

      expect(findPolicyExceptions().exists()).toBe(true);
    });
  });

  describe('empty scanners migration', () => {
    const allScannerTypes = [
      'api_fuzzing',
      'container_scanning',
      'coverage_fuzzing',
      'dast',
      'dependency_scanning',
      'sast',
      'secret_detection',
    ];

    const policyWithEmptyScanners = {
      rules: [
        {
          type: 'scan_finding',
          branches: [],
          scanners: [],
          vulnerabilities_allowed: 1,
          severity_levels: ['critical'],
          vulnerability_states: ['newly_detected'],
        },
      ],
    };

    it('migrates empty scanners to all available scanner types', () => {
      factoryWithExistingPolicy({
        policy: policyWithEmptyScanners,
      });

      const { rules } = findPolicyEditorLayout().props('policy');
      const { scanners } = rules[0];

      expect(scanners).toHaveLength(allScannerTypes.length);
      expect(scanners.map((s) => s.type)).toEqual(allScannerTypes);
      scanners.forEach((scanner) => {
        expect(scanner).toEqual(buildDefaultScannerObject(scanner.type));
      });
    });

    it('does not migrate rules with existing scanners', () => {
      factoryWithExistingPolicy();

      const { rules } = findPolicyEditorLayout().props('policy');
      expect(rules[0].scanners).not.toEqual(DEFAULT_SCANNERS);
    });

    it('does not error when policy has no rules', () => {
      factoryWithExistingPolicy({
        hasRules: false,
      });

      expect(findPolicyEditorLayout().exists()).toBe(true);
    });
  });

  describe('new yaml format with type as a wrapper', () => {
    beforeEach(() => {
      factory();
    });

    it('renders default yaml in new format', () => {
      expect(findPolicyEditorLayout().props('yamlEditorValue')).toBe(DEFAULT_SCAN_RESULT_POLICY);
    });

    it('converts new policy format to old policy format when saved', async () => {
      findPolicyEditorLayout().vm.$emit('save-policy');
      await waitForPromises();

      expect(wrapper.emitted('save')).toEqual([
        [
          {
            action: undefined,
            isRuleMode: true,
            policy: `name: ''
description: ''
enabled: true
enforcement_type: warn
rules:
  - type: ''
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
  prevent_approval_by_author: true
  prevent_approval_by_commit_author: true
  remove_approvals_with_new_commit: true
  prevent_editing_approval_rules: false
  require_password_to_approve: false
fallback_behavior:
  fail: closed
type: approval_policy
`,
          },
        ],
      ]);
    });
  });
});
