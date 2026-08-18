import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  APPROVAL_POLICY_TYPE,
  DEPENDENCY_FIREWALL_POLICY_TYPE,
  PIPELINE_EXECUTION_POLICY_TYPE,
  SCAN_EXECUTION_POLICY_TYPE,
  VULNERABILITY_MANAGEMENT_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import PolicyTypeSelector from 'ee/security_orchestration/components/policy_editor/policy_type_selector.vue';

describe('PolicyTypeSelector component', () => {
  const policiesPath = '/policies/path';
  let wrapper;

  const factory = (provide = {}, stubs = {}) => {
    wrapper = shallowMountExtended(PolicyTypeSelector, {
      stubs: { GlCard: true, ...stubs },
      provide: {
        policiesPath,
        maxScanExecutionPoliciesAllowed: 5,
        maxScanResultPoliciesAllowed: 5,
        maxPipelineExecutionPoliciesAllowed: 5,
        maxVulnerabilityManagementPoliciesAllowed: 5,
        maxActiveScanExecutionPoliciesReached: true,
        maxActiveScanResultPoliciesReached: false,
        maxActivePipelineExecutionPoliciesReached: false,
        maxActiveVulnerabilityManagementPoliciesReached: false,
        ...provide,
      },
    });
  };

  const findDescription = (title) => wrapper.findByTestId(`${title}-card`).findComponent(GlSprintf);
  const findPolicyButton = (urlParameter) => wrapper.findByTestId(`select-policy-${urlParameter}`);
  const findMaxAllowedPolicyText = (urlParameter) =>
    wrapper.findByTestId(`max-allowed-text-${urlParameter}`);

  describe('cards', () => {
    describe.each`
      title                                                         | description
      ${PolicyTypeSelector.i18n.scanResultPolicyTitle}              | ${PolicyTypeSelector.i18n.scanResultPolicyDesc}
      ${PolicyTypeSelector.i18n.scanExecutionPolicyTitle}           | ${PolicyTypeSelector.i18n.scanExecutionPolicyDesc}
      ${PolicyTypeSelector.i18n.pipelineExecutionPolicyTitle}       | ${PolicyTypeSelector.i18n.pipelineExecutionPolicyDesc}
      ${PolicyTypeSelector.i18n.vulnerabilityManagementPolicyTitle} | ${PolicyTypeSelector.i18n.vulnerabilityManagementPolicyDesc}
    `('selection card: $title', ({ title, description }) => {
      beforeEach(() => {
        factory();
      });

      it(`displays the title`, () => {
        expect(wrapper.findByText(title).exists()).toBe(true);
      });

      it(`displays the description`, () => {
        expect(findDescription(title).attributes('message')).toBe(description);
      });
    });

    describe('navigation button', () => {
      beforeEach(() => {
        factory();
      });

      it('displays the button for policy types that have not reached their max number allowed', () => {
        expect(findPolicyButton(APPROVAL_POLICY_TYPE).exists()).toBe(true);

        expect(findPolicyButton(APPROVAL_POLICY_TYPE).attributes('href')).toContain(
          `?type=${APPROVAL_POLICY_TYPE}`,
        );

        expect(findMaxAllowedPolicyText(APPROVAL_POLICY_TYPE).exists()).toBe(false);
      });

      it('displays warning text for policy types that have reached their max number allowed', () => {
        expect(findPolicyButton(SCAN_EXECUTION_POLICY_TYPE).exists()).toBe(false);
        expect(findMaxAllowedPolicyText(SCAN_EXECUTION_POLICY_TYPE).exists()).toBe(true);
        expect(findMaxAllowedPolicyText(SCAN_EXECUTION_POLICY_TYPE).text()).toBe('');
      });

      it('displays warning text for pipeline execution policy type', () => {
        factory(
          {
            maxActivePipelineExecutionPoliciesReached: true,
          },
          {
            GlSprintf,
          },
        );
        expect(findMaxAllowedPolicyText(PIPELINE_EXECUTION_POLICY_TYPE).exists()).toBe(true);
        expect(findMaxAllowedPolicyText(PIPELINE_EXECUTION_POLICY_TYPE).text()).toBe(
          'You already have the maximum 5 pipeline execution policies.',
        );
        expect(findPolicyButton(PIPELINE_EXECUTION_POLICY_TYPE).exists()).toBe(false);
      });

      it('displays warning text for vulnerability management policy type', () => {
        factory(
          {
            maxActiveVulnerabilityManagementPoliciesReached: true,
          },
          {
            GlSprintf,
          },
        );
        expect(findMaxAllowedPolicyText(VULNERABILITY_MANAGEMENT_POLICY_TYPE).exists()).toBe(true);
        expect(findMaxAllowedPolicyText(VULNERABILITY_MANAGEMENT_POLICY_TYPE).text()).toBe(
          'You already have the maximum 5 vulnerability management policies.',
        );
        expect(findPolicyButton(VULNERABILITY_MANAGEMENT_POLICY_TYPE).exists()).toBe(false);
      });
    });
  });

  describe('dependency firewall policy card', () => {
    it('does not display when dependencyFirewallPhase1 feature flag is disabled', () => {
      factory({ glFeatures: { dependencyFirewallPhase1: false } });
      expect(wrapper.findByTestId(`${DEPENDENCY_FIREWALL_POLICY_TYPE}-card`).exists()).toBe(false);
    });

    it('displays when dependencyFirewallPhase1 feature flag is enabled', () => {
      factory({ glFeatures: { dependencyFirewallPhase1: true } });
      expect(wrapper.findByTestId(`${DEPENDENCY_FIREWALL_POLICY_TYPE}-card`).exists()).toBe(true);
    });

    it('displays selection button with correct href when FF is enabled', () => {
      factory({ glFeatures: { dependencyFirewallPhase1: true } });
      expect(findPolicyButton(DEPENDENCY_FIREWALL_POLICY_TYPE).exists()).toBe(true);
      expect(findPolicyButton(DEPENDENCY_FIREWALL_POLICY_TYPE).attributes('href')).toContain(
        `?type=${DEPENDENCY_FIREWALL_POLICY_TYPE}`,
      );
    });
  });

  describe('malware blocking badge', () => {
    const findMalwareBadge = () => wrapper.findByTestId(`${APPROVAL_POLICY_TYPE}-badge`);

    it('renders on the approval card when the feature flag is enabled', () => {
      factory({ glFeatures: { securityPoliciesMalwareAttribute: true } });

      expect(findMalwareBadge().exists()).toBe(true);
      expect(findMalwareBadge().text()).toBe('New: Malware blocking');
    });

    it('exposes the full detail in a tooltip on the badge', () => {
      factory({ glFeatures: { securityPoliciesMalwareAttribute: true } });

      expect(findMalwareBadge().attributes('title')).toBe(
        'Blocks dependency and container packages flagged as malware.',
      );
    });

    it('does not render when the feature flag is disabled', () => {
      factory({ glFeatures: { securityPoliciesMalwareAttribute: false } });

      expect(findMalwareBadge().exists()).toBe(false);
    });

    it('does not render on other policy cards', () => {
      factory({ glFeatures: { securityPoliciesMalwareAttribute: true } });

      expect(wrapper.findByTestId(`${SCAN_EXECUTION_POLICY_TYPE}-badge`).exists()).toBe(false);
    });
  });

  it('displays a cancel button which brings back to policies page', () => {
    factory();
    expect(wrapper.findByTestId('back-button').attributes('href')).toBe(policiesPath);
  });
});
