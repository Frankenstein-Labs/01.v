import { GlSprintf } from '@gitlab/ui';
import { convertToTitleCase } from '~/lib/utils/text_utility';
import DetailsDrawer from 'ee/security_orchestration/components/policy_drawer/scan_result/details_drawer.vue';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';
import DrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import Approvals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';
import Settings from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_settings.vue';
import EdgeCaseSettings from 'ee/security_orchestration/components/policy_drawer/scan_result/edge_case_settings.vue';
import PolicyExceptions from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/policy_exceptions.vue';
import DenyAllowViewList from 'ee/security_orchestration/components/policy_drawer/scan_result/deny_allow_view_list.vue';
import LicenseOverridesViewList from 'ee/security_orchestration/components/policy_drawer/scan_result/license_overrides_view_list.vue';
import MalwareBlockingAlert from 'ee/security_orchestration/components/policy_drawer/scan_result/malware_blocking_alert.vue';
import {
  disabledSendBotMessageActionScanResultManifest,
  enabledSendBotMessageActionScanResultManifest,
  mockProjectScanResultPolicy,
  mockProjectWithAllApproverTypesScanResultPolicy,
  mockProjectApprovalSettingsScanResultPolicy,
  mockProjectFallbackClosedScanResultManifest,
  mockNoFallbackScanResultManifest,
  zeroActionsScanResultManifest,
  mockProjectPolicyTuningScanResultManifest,
  allowDenyScanResultLicenseNonEmptyManifest,
  mockLegacyWarnTypeScanResultManifest,
  mockWarnTypeScanResultManifest,
  denyScanResultLicenseNonEmptyManifest,
  mockPolicyExceptionsScanResultManifest,
  licenseOverridesScanResultManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';

describe('DetailsDrawer component', () => {
  let wrapper;

  const findFallbackDetails = () => wrapper.findByTestId('fallback-details');
  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findPolicyApprovals = () => wrapper.findComponent(Approvals);
  const findDrawerLayout = () => wrapper.findComponent(DrawerLayout);
  const findToggleList = () => wrapper.findComponent(ToggleList);
  const findSettings = () => wrapper.findComponent(Settings);
  const findBotMessage = () => wrapper.findByTestId('policy-bot-message');
  const findApprovalSubheader = () => wrapper.findByTestId('approvals-subheader');
  const findEdgeCaseSettings = () => wrapper.findComponent(EdgeCaseSettings);
  const findDenyAllowViewList = () => wrapper.findComponent(DenyAllowViewList);
  const findLicenseOverridesViewList = () => wrapper.findComponent(LicenseOverridesViewList);
  const findPolicyExceptions = () => wrapper.findComponent(PolicyExceptions);

  const findMalwareBlockingAlert = () => wrapper.findComponent(MalwareBlockingAlert);

  const factory = ({ props, provide = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(DetailsDrawer, {
      propsData: {
        policy: mockProjectScanResultPolicy,
        ...props,
      },
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT, glFeatures, ...provide },
      stubs: {
        DrawerLayout,
        GlSprintf,
      },
    });
  };

  describe('policy drawer layout props', () => {
    it('passes the policy to the DrawerLayout component', () => {
      factory();
      expect(findDrawerLayout().props('policy')).toBe(mockProjectScanResultPolicy);
    });

    it('passes the description to the DrawerLayout component', () => {
      factory();
      expect(findDrawerLayout().props('description')).toBe(
        'This policy enforces critical vulnerability CS approvals',
      );
    });

    it('renders layout if yaml is invalid', () => {
      factory({ props: { policy: {} } });

      expect(findDrawerLayout().exists()).toBe(true);
      expect(findDrawerLayout().props('description')).toBe('');
      expect(findDenyAllowViewList().exists()).toBe(false);
      expect(findPolicyExceptions().exists()).toBe(false);
    });
  });

  describe('summary', () => {
    describe('actions', () => {
      describe('approvals', () => {
        it('renders the "Approvals" component correctly', () => {
          factory({ props: { policy: mockProjectWithAllApproverTypesScanResultPolicy } });
          expect(findPolicyApprovals().exists()).toBe(true);
          expect(findPolicyApprovals().props('isLastItem')).toBe(false);
          expect(findApprovalSubheader().exists()).toBe(true);
          expect(findPolicyApprovals().props('isWarnMode')).toBe(false);
          expect(findPolicyApprovals().props('approvers')).toStrictEqual([
            ...mockProjectWithAllApproverTypesScanResultPolicy.actionApprovers[0].allGroups,
            ...mockProjectWithAllApproverTypesScanResultPolicy.actionApprovers[0].roles.map((r) =>
              convertToTitleCase(r.toLowerCase()),
            ),
            ...mockProjectWithAllApproverTypesScanResultPolicy.actionApprovers[0].users,
          ]);
        });

        it('should not render branch exceptions list without exceptions', () => {
          factory({ props: { policy: mockProjectWithAllApproverTypesScanResultPolicy } });
          expect(findToggleList().exists()).toBe(false);
        });
      });

      describe('send bot message', () => {
        it('hides the text when it is disabled', () => {
          factory({
            props: {
              policy: {
                ...mockProjectWithAllApproverTypesScanResultPolicy,
                yaml: disabledSendBotMessageActionScanResultManifest,
              },
            },
          });
          expect(findBotMessage().exists()).toBe(false);
          expect(findApprovalSubheader().exists()).toBe(false);
        });

        it('shows the message when the action is not included', () => {
          factory({ props: { policy: mockProjectScanResultPolicy } });
          expect(findBotMessage().text()).toBe('Send a bot message when the conditions match.');
        });

        it('shows the message when the action is enabled', () => {
          factory({
            props: {
              policy: {
                ...mockProjectWithAllApproverTypesScanResultPolicy,
                yaml: enabledSendBotMessageActionScanResultManifest,
              },
            },
          });
          expect(findBotMessage().text()).toBe('Send a bot message when the conditions match.');
        });

        it('shows the message when there are zero actions is enabled', () => {
          factory({
            props: {
              policy: {
                ...mockProjectWithAllApproverTypesScanResultPolicy,
                yaml: zeroActionsScanResultManifest,
              },
            },
          });
          expect(findBotMessage().exists()).toBe(true);
          expect(findApprovalSubheader().exists()).toBe(false);
        });
      });

      describe('warn mode', () => {
        it('renders', () => {
          factory({
            props: {
              policy: {
                ...mockProjectWithAllApproverTypesScanResultPolicy,
                yaml: mockWarnTypeScanResultManifest,
              },
            },
          });
          expect(findPolicyApprovals().exists()).toBe(true);
          expect(findPolicyApprovals().props('isLastItem')).toBe(false);
          expect(findPolicyApprovals().props('isWarnMode')).toBe(true);
          expect(findBotMessage().exists()).toBe(false);
        });
      });

      describe('legacy warn mode', () => {
        it('renders correctly', () => {
          factory({
            props: {
              policy: {
                ...mockProjectWithAllApproverTypesScanResultPolicy,
                yaml: mockLegacyWarnTypeScanResultManifest,
              },
            },
          });
          expect(findPolicyApprovals().exists()).toBe(true);
          expect(findPolicyApprovals().props('isLastItem')).toBe(false);
          expect(findPolicyApprovals().props('isWarnMode')).toBe(false);
          expect(findBotMessage().exists()).toBe(true);
        });
      });
    });

    describe('rules', () => {
      it('renders the summary for a security scan rule', () => {
        factory();
        expect(findSummary().text()).toContain(
          'When Container scanning scanner finds more than 1 vulnerability in an open merge request targeting any protected branch and all the following apply:',
        );
        expect(findToggleList().exists()).toBe(false);
      });

      it('renders the summary for a license rule when licenses are present', () => {
        factory({
          props: {
            policy: {
              ...mockProjectScanResultPolicy,
              yaml: allowDenyScanResultLicenseNonEmptyManifest,
            },
          },
        });
        expect(findSummary().text()).toContain(
          'When license scanner finds any license matching  that is pre-existing and is in an open merge request targeting any protected branch.',
        );
        expect(findToggleList().exists()).toBe(true);
      });
    });

    describe('license overrides', () => {
      it('does not render LicenseOverridesViewList when no overrides are present', () => {
        factory();
        expect(findLicenseOverridesViewList().exists()).toBe(false);
      });

      it('renders LicenseOverridesViewList when license overrides are present', () => {
        factory({
          props: {
            policy: { ...mockProjectScanResultPolicy, yaml: licenseOverridesScanResultManifest },
          },
        });
        expect(findLicenseOverridesViewList().exists()).toBe(true);
      });

      it('passes the correct items to LicenseOverridesViewList', () => {
        factory({
          props: {
            policy: { ...mockProjectScanResultPolicy, yaml: licenseOverridesScanResultManifest },
          },
        });
        expect(findLicenseOverridesViewList().props('items')).toEqual([
          { purl: 'pkg:pypi/urllib3', license: 'MIT License', mode: 'patch' },
          { purl: 'pkg:gem/rails', license: 'Apache-2.0', mode: 'overwrite' },
        ]);
      });
    });

    describe('settings', () => {
      it('passes the settings to the "Settings" component if settings are present', () => {
        factory({ props: { policy: mockProjectApprovalSettingsScanResultPolicy } });
        expect(findSettings().props('settings')).toEqual(
          mockProjectApprovalSettingsScanResultPolicy.approval_settings,
        );
      });

      it('passes the empty object to the "Settings" component if no settings are present', () => {
        factory();
        expect(findSettings().props('settings')).toEqual({});
      });
    });
  });

  describe('policy exceptions bypass options', () => {
    it('renders the policy exceptions when exceptions present in yaml', () => {
      factory({
        props: {
          policy: { ...mockProjectScanResultPolicy, yaml: mockPolicyExceptionsScanResultManifest },
        },
      });

      expect(findPolicyExceptions().exists()).toBe(true);
      expect(findPolicyExceptions().props('exceptions')).toEqual({
        branches: [
          {
            source: {
              pattern: 'master',
            },
            target: {
              name: '*test',
            },
          },
          {
            source: {
              pattern: 'main',
            },
            target: {
              name: '*test2',
            },
          },
        ],
      });
    });
  });

  describe('fallback behavior', () => {
    it('does not render the fallback behavior section if the policy does not have the fallback behavior property', () => {
      factory({
        props: {
          policy: { ...mockProjectScanResultPolicy, yaml: mockNoFallbackScanResultManifest },
        },
      });
      expect(findFallbackDetails().isVisible()).toBe(false);
      expect(findFallbackDetails().text()).toBe('');
    });

    it('renders the open fallback behavior', () => {
      factory();
      expect(findFallbackDetails().isVisible()).toBe(true);
      expect(findFallbackDetails().text()).toBe(
        'Fail open: Allow the merge request to proceed, even if not all criteria are met',
      );
    });

    it('renders the closed fallback behavior', () => {
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: mockProjectFallbackClosedScanResultManifest,
          },
        },
      });
      expect(findFallbackDetails().isVisible()).toBe(true);
      expect(findFallbackDetails().text()).toBe(
        'Fail closed: Block the merge request until all criteria are met',
      );
    });
  });

  describe('edge case settings', () => {
    it('does not render the edge case settings', () => {
      factory();
      expect(findEdgeCaseSettings().exists()).toBe(false);
    });

    it('does render the edge case settings', () => {
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: mockProjectPolicyTuningScanResultManifest,
          },
        },
      });
      expect(findEdgeCaseSettings().exists()).toBe(true);
    });
  });

  describe('per-scanner details', () => {
    const objectScannersManifest = `name: test policy
description: test
enabled: true
rules:
  - type: scan_finding
    branch_type: default
    scanners:
      - type: sast
        vulnerabilities_allowed: 0
        severity_levels:
          - critical
        vulnerability_states:
          - newly_detected
        vulnerability_attributes:
          false_positive: false
      - type: dependency_scanning
        vulnerabilities_allowed: 0
        severity_levels:
          - critical
          - high
        vulnerability_states:
          - newly_detected
        vulnerability_attributes:
          false_positive: false
          fix_available: true
          known_exploited: true
          epss_score:
            operator: greater_than
            value: 0.1
actions:
  - type: require_approval
    approvals_required: 1
  - type: send_bot_message
    enabled: true
fallback_behavior:
  fail: closed
`;

    const findScannerDetails = () => wrapper.findByTestId('scanner-details');
    const findScannerDetailItems = () => wrapper.findAllByTestId('scanner-detail-item');

    it('renders per-scanner details for object-format scanners', () => {
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: objectScannersManifest,
            actionApprovers: [{}],
          },
        },
      });

      expect(findScannerDetails().exists()).toBe(true);
      expect(findScannerDetailItems()).toHaveLength(2);

      const firstScanner = findScannerDetailItems().at(0);
      expect(firstScanner.text()).toContain('SAST');
      expect(firstScanner.text()).toContain('No new vulnerabilities allowed');
      expect(firstScanner.text()).toContain('Severity is critical');

      const secondScanner = findScannerDetailItems().at(1);
      expect(secondScanner.text()).toContain('Dependency scanning');
      expect(secondScanner.text()).toContain('No new vulnerabilities allowed');
      expect(secondScanner.text()).toContain('KEV catalog');
      expect(secondScanner.text()).toContain('EPSS score');
    });

    it('renders per-scanner vulnerabilities_allowed overrides', () => {
      const manifest = `name: test policy
description: test
enabled: true
rules:
  - type: scan_finding
    branch_type: default
    vulnerabilities_allowed: 0
    scanners:
      - type: sast
        vulnerabilities_allowed: 5
        severity_levels:
          - critical
        vulnerability_states:
          - newly_detected
      - type: dependency_scanning
        vulnerabilities_allowed: 1
        severity_levels:
          - high
        vulnerability_states:
          - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
fallback_behavior:
  fail: closed
`;

      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml: manifest,
            actionApprovers: [{}],
          },
        },
      });

      const firstScanner = findScannerDetailItems().at(0);
      expect(firstScanner.text()).toContain('Allows more than 5 vulnerabilities');

      const secondScanner = findScannerDetailItems().at(1);
      expect(secondScanner.text()).toContain('Allows more than 1 vulnerability');
    });

    it('does not render per-scanner details for string-format scanners', () => {
      factory({
        props: {
          policy: mockProjectScanResultPolicy,
        },
      });

      expect(findScannerDetails().exists()).toBe(false);
    });
  });

  describe('malware blocking alert', () => {
    const maliciousScannerManifest = `name: test policy
description: test
enabled: true
rules:
  - type: scan_finding
    branch_type: default
    scanners:
      - type: dependency_scanning
        vulnerabilities_allowed: 0
        is_malicious: true
actions:
  - type: require_approval
    approvals_required: 1
`;

    const maliciousPolicy = {
      ...mockProjectScanResultPolicy,
      yaml: maliciousScannerManifest,
      actionApprovers: [{}],
    };

    it('renders the alert when the flag is on and a scanner blocks malware', () => {
      factory({
        props: { policy: maliciousPolicy },
        glFeatures: { securityPoliciesMalwareAttribute: true },
      });

      expect(findMalwareBlockingAlert().exists()).toBe(true);
    });

    it('does not render the alert when the feature flag is off', () => {
      factory({ props: { policy: maliciousPolicy } });

      expect(findMalwareBlockingAlert().exists()).toBe(false);
    });

    it('does not render the alert when no scanner blocks malware', () => {
      factory({ glFeatures: { securityPoliciesMalwareAttribute: true } });

      expect(findMalwareBlockingAlert().exists()).toBe(false);
    });
  });

  describe('deny allow license exceptions table', () => {
    it.each`
      yaml                                          | isDenied
      ${allowDenyScanResultLicenseNonEmptyManifest} | ${false}
      ${denyScanResultLicenseNonEmptyManifest}      | ${true}
    `('renders allow deny list when license packages exist', ({ yaml, isDenied }) => {
      factory({
        props: {
          policy: {
            ...mockProjectScanResultPolicy,
            yaml,
          },
        },
      });

      expect(findDenyAllowViewList().exists()).toBe(true);
      expect(findDenyAllowViewList().props('isDenied')).toBe(isDenied);
      expect(findDenyAllowViewList().props('items')).toEqual([
        { license: { value: 'MIT', text: 'MIT' }, exceptions: [] },
        {
          license: { value: 'NPM', text: 'NPM' },
          exceptions: ['pkg:npm40angular/animation', 'pkg:npm40angular/animation@12.3.1'],
        },
      ]);
    });
  });
});
