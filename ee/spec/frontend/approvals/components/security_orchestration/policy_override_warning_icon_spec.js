import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PolicyOverrideWarningIcon from 'ee/approvals/components/security_orchestration/policy_override_warning_icon.vue';
import PolicyOverrideText from 'ee/approvals/components/security_orchestration/policy_override_text.vue';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';
import groupSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_security_policies.query.graphql';
import { projectSecurityPolicies } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import {
  WARN_VALUE,
  PREVENT_APPROVAL_BY_AUTHOR,
  REQUIRE_PASSWORD_TO_APPROVE,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { APPROVAL_POLICY_FILTER_TYPE } from 'ee/security_orchestration/components/policies/constants';

Vue.use(VueApollo);

const fullPath = 'full/path';

const defaultSettings = [
  PREVENT_APPROVAL_BY_AUTHOR,
  REQUIRE_PASSWORD_TO_APPROVE,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
];

const makePolicyNode = ({ enforcementType, approvalSettings } = {}) => ({
  yaml: [
    'name: test policy',
    'enabled: true',
    'rules: []',
    'actions: []',
    approvalSettings
      ? `approval_settings:\n  ${Object.entries(approvalSettings)
          .map(([k, v]) => `${k}: ${v}`)
          .join('\n  ')}`
      : `approval_settings:\n  ${PREVENT_APPROVAL_BY_AUTHOR}: true`,
    ...(enforcementType ? [`enforcement_type: ${enforcementType}`] : []),
  ].join('\n'),
  actionApprovers: [],
  editPath: '/edit',
  source: null,
});

describe('PolicyOverrideWarningIcon', () => {
  let wrapper;

  const createMockApolloProvider = (handler, isGroup = false) => {
    const query = isGroup ? groupSecurityPoliciesQuery : projectSecurityPoliciesQuery;
    return createMockApollo([[query, handler]]);
  };

  const createComponent = ({ propsData = {}, handler, isGroup = false, policyNodes } = {}) => {
    const mockHandler = handler || projectSecurityPolicies([]);

    wrapper = shallowMountExtended(PolicyOverrideWarningIcon, {
      apolloProvider: createMockApolloProvider(mockHandler, isGroup),
      provide: {
        fullPath,
        isGroup,
      },
      propsData: {
        settings: defaultSettings,
        ...propsData,
      },
      ...(policyNodes !== undefined
        ? {
            data() {
              return { securityPolicies: policyNodes };
            },
          }
        : {}),
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findAllPolicyOverrideTexts = () => wrapper.findAllComponents(PolicyOverrideText);

  describe('GraphQL query', () => {
    it('calls the project query with correct variables', async () => {
      const handler = jest.fn().mockResolvedValue(projectSecurityPolicies([]));
      createComponent({ handler });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath,
          type: APPROVAL_POLICY_FILTER_TYPE,
        }),
      );
    });

    it('calls the group query when isGroup is true', async () => {
      const handler = jest.fn().mockResolvedValue(projectSecurityPolicies([]));
      createComponent({ handler, isGroup: true });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath,
          type: APPROVAL_POLICY_FILTER_TYPE,
        }),
      );
    });
  });

  describe('rendering', () => {
    it('does not render icon when no policies exist', async () => {
      createComponent();
      await waitForPromises();

      expect(findIcon().exists()).toBe(false);
    });

    it('does not render icon when no policies with approval settings overrides exist', async () => {
      createComponent();
      await waitForPromises();

      expect(findIcon().exists()).toBe(false);
    });
  });

  describe('icon customization', () => {
    it('uses default iconId when not provided', () => {
      createComponent();

      // The icon element would use the default ID if rendered
      const expectedId = 'policy-override-warning-icon';
      expect(PolicyOverrideWarningIcon.props.iconId.default).toBe(expectedId);
    });

    it('uses custom iconId when provided', () => {
      const customId = 'custom-icon-id';
      createComponent({ propsData: { iconId: customId } });

      expect(wrapper.props('iconId')).toBe(customId);
    });
  });

  describe('settings prop', () => {
    it('accepts settings prop', () => {
      createComponent({ propsData: { settings: [PREVENT_APPROVAL_BY_AUTHOR] } });

      expect(wrapper.props('settings')).toEqual([PREVENT_APPROVAL_BY_AUTHOR]);
    });

    it('requires settings prop', () => {
      expect(PolicyOverrideWarningIcon.props.settings.required).toBe(true);
    });
  });

  describe('pre-enforcement policies (no enforcement_type)', () => {
    it('renders warning icon', () => {
      createComponent({ policyNodes: [makePolicyNode()] });

      expect(findIcon().exists()).toBe(true);
    });

    it('treats pre-enforcement policy as enforced', () => {
      createComponent({ policyNodes: [makePolicyNode()] });

      expect(findAllPolicyOverrideTexts()).toHaveLength(1);
      expect(findAllPolicyOverrideTexts().at(0).props('isWarn')).toBe(false);
    });

    it('does not render icon for warn enforcement_type', () => {
      createComponent({
        policyNodes: [makePolicyNode({ enforcementType: WARN_VALUE })],
      });

      expect(findIcon().exists()).toBe(true);
      expect(findAllPolicyOverrideTexts()).toHaveLength(1);
      expect(findAllPolicyOverrideTexts().at(0).props('isWarn')).toBe(true);
    });
  });
});
