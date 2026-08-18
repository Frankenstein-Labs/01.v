import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import DefaultRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/default_rule_builder.vue';
import ScanTypeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_type_select.vue';
import AnyMergeRequestRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/any_merge_request_rule_builder.vue';
import LicenseScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/license_scan_rule_builder.vue';
import DenyAllowList from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list.vue';
import SecurityScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/security_scan_rule_builder.vue';
import SettingsItem from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_item.vue';
import SettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/settings/settings_section.vue';
import * as urlUtils from '~/lib/utils/url_utility';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import {
  ANY_MERGE_REQUEST,
  SCAN_FINDING,
  LICENSE_FINDING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { verify } from '../utils';
import {
  mockSecurityApprovalManifest,
  mockLicenseApprovalManifest,
  mockAnyMergeRequestApprovalManifest,
  mockLicenseApprovalWithLicenseExceptionsManifest,
} from './mocks';

describe('Scan result policy rules', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
        SettingPopover: true,
      },
    });
  };

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(APPROVAL_POLICY_TYPE);
  });

  afterEach(() => {
    window.gon = {};
  });

  const findSecurityScanRuleBuilder = () => wrapper.findComponent(SecurityScanRuleBuilder);
  const findLicenseScanRuleBuilder = () => wrapper.findComponent(LicenseScanRuleBuilder);
  const findDefaultRuleBuilder = () => wrapper.findComponent(DefaultRuleBuilder);
  const findScanTypeSelect = () => wrapper.findComponent(ScanTypeSelect);
  const findAnyMergeRequestRuleBuilder = () => wrapper.findComponent(AnyMergeRequestRuleBuilder);
  const findSettingsSection = () => wrapper.findComponent(SettingsSection);
  const findAllSettingsItem = () => wrapper.findAllComponents(SettingsItem);
  const findDenyAllowList = () => wrapper.findComponent(DenyAllowList);

  describe('security scan', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should select security scan rule', async () => {
      const verifyRuleMode = () => {
        expect(findDefaultRuleBuilder().exists()).toBe(false);
        expect(findSecurityScanRuleBuilder().exists()).toBe(true);
        expect(findSettingsSection().exists()).toBe(true);
      };

      await findScanTypeSelect().vm.$emit('select', SCAN_FINDING);
      await verify({
        manifest: mockSecurityApprovalManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });

  describe('license rule', () => {
    const verifyRuleMode = () => {
      expect(findDefaultRuleBuilder().exists()).toBe(false);
      expect(findLicenseScanRuleBuilder().exists()).toBe(true);
      expect(findSettingsSection().exists()).toBe(true);
    };

    beforeEach(() => {
      createWrapper();
    });

    it('should select license rule', async () => {
      await findScanTypeSelect().vm.$emit('select', LICENSE_FINDING);
      await verify({ manifest: mockLicenseApprovalManifest, verifyRuleMode, wrapper });
    });
  });

  describe('license rule with exceptions', () => {
    const verifyRuleMode = () => {
      expect(findDefaultRuleBuilder().exists()).toBe(false);
      expect(findLicenseScanRuleBuilder().exists()).toBe(true);
    };

    it('renders license allow deny list', async () => {
      createWrapper();

      await findScanTypeSelect().vm.$emit('select', LICENSE_FINDING);

      expect(findDenyAllowList().exists()).toBe(true);
    });

    it('should select license rule', async () => {
      createWrapper();

      await findScanTypeSelect().vm.$emit('select', LICENSE_FINDING);

      await findDenyAllowList().vm.$emit('select-licenses', [
        {
          exceptions: ['path:to-purl@12.1.2', 'path:to-purl@12.1.3'],
          license: {
            text: 'Apache License 1.0',
            value: 'Apache License 1.0',
          },
        },
        {
          exceptions: ['path:to-purl@12.1.2'],
          license: {
            text: 'Japan Network Information Center License',
            value: 'Japan Network Information Center License',
          },
        },
      ]);

      await verify({
        manifest: mockLicenseApprovalWithLicenseExceptionsManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });

  describe('any merge request rule', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should select any merge request rule', async () => {
      const verifyRuleMode = () => {
        expect(findDefaultRuleBuilder().exists()).toBe(false);
        expect(findAnyMergeRequestRuleBuilder().exists()).toBe(true);
        expect(findSettingsSection().exists()).toBe(true);
        expect(findAllSettingsItem()).toHaveLength(3);
      };

      await findScanTypeSelect().vm.$emit('select', ANY_MERGE_REQUEST);
      await verify({ manifest: mockAnyMergeRequestApprovalManifest, verifyRuleMode, wrapper });
    });
  });
});
