import { GlSprintf, GlAlert } from '@gitlab/ui';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import LicenseScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/license_scan_rule_builder.vue';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filter.vue';
import LicenseFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/license_filter.vue';
import DenyAllowList from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list.vue';
import ScanTypeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_type_select.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import {
  getDefaultRule,
  licenseScanBuildRule,
  SCAN_FINDING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  ALLOW_DENY,
  ALLOWED,
  DENIED,
  LICENCE_FILTERS,
  LICENSE_OVERRIDES,
  OVERRIDES,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import LicenseOverridesList from 'ee/security_orchestration/components/policy_editor/scan_result/rule/license_overrides_list.vue';
import { mapComponentLicenseFormatToYaml } from 'ee/security_orchestration/components/policy_editor/utils';

const actionId = 'action_0';
jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: jest.fn().mockReturnValue(actionId),
}));

describe('LicenseScanRuleBuilder', () => {
  let wrapper;

  const PROTECTED_BRANCHES_MOCK = [{ id: 1, name: 'main' }];

  const UPDATED_RULE = {
    ...licenseScanBuildRule(),
    branches: [PROTECTED_BRANCHES_MOCK[0].name],
    match_on_inclusion: false,
    license_types: ['MIT', 'BSD'],
    license_states: ['newly_detected', 'detected'],
  };

  const factory = ({ stubs = {}, props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(LicenseScanRuleBuilder, {
      propsData: {
        initRule: licenseScanBuildRule(),
        ...props,
      },
      provide: {
        namespaceType: NAMESPACE_TYPES.GROUP,
        enabledExperiments: [],
        ...provide,
      },
      stubs: {
        SectionLayout,
        GlSprintf,
        BranchSelection: true,
        StatusFilter,
        ...stubs,
      },
    });
  };

  const findBranches = () => wrapper.findComponent(BranchSelection);
  const findGroupLevelBranches = () => wrapper.findByTestId('group-level-branch');
  const findPolicyRuleMultiSelect = () => wrapper.findComponent(RuleMultiSelect);
  const findStatusFilter = () => wrapper.findComponent(StatusFilter);
  const findLicenseFilter = () => wrapper.findComponent(LicenseFilter);
  const findScanTypeSelect = () => wrapper.findComponent(ScanTypeSelect);
  const findBranchExceptionSelector = () => wrapper.findComponent(BranchExceptionSelector);
  const findDenyAllowList = () => wrapper.findComponent(DenyAllowList);
  const findScanFilterSelector = () => wrapper.findComponent(ScanFilterSelector);
  const findAlert = () => wrapper.findComponent(GlAlert);

  describe('initial rendering', () => {
    it('renders one field for each attribute of the rule', () => {
      factory();
      expect(findBranches().exists()).toBe(true);
      expect(findGroupLevelBranches().exists()).toBe(false);
      expect(findStatusFilter().exists()).toBe(true);
    });

    it('includes select all option to all PolicyRuleMultiSelect', () => {
      factory();
      expect(findPolicyRuleMultiSelect().props()).toEqual(
        expect.objectContaining({ includeSelectAll: true }),
      );
    });

    it('can change scan type', () => {
      factory();
      findScanTypeSelect().vm.$emit('select', SCAN_FINDING);

      expect(wrapper.emitted('set-scan-type')).toEqual([[getDefaultRule(SCAN_FINDING)]]);
    });
  });

  describe('adding branch exceptions', () => {
    const exceptions = { branch_exceptions: ['main', 'test'] };

    it.each`
      namespaceType              | expectedResult
      ${NAMESPACE_TYPES.PROJECT} | ${true}
      ${NAMESPACE_TYPES.GROUP}   | ${true}
    `(
      'should select exceptions on project and group level',
      ({ namespaceType, expectedResult }) => {
        factory({
          provide: {
            namespaceType,
          },
        });

        expect(findBranchExceptionSelector().exists()).toBe(expectedResult);
      },
    );

    it('should select exceptions', () => {
      factory({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      findBranchExceptionSelector().vm.$emit('select', exceptions);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            ...licenseScanBuildRule(),
            ...exceptions,
          },
        ],
      ]);
    });

    it('should display saved exceptions', () => {
      factory({
        props: {
          initRule: {
            ...licenseScanBuildRule(),
            ...exceptions,
          },
        },
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findBranchExceptionSelector().props('selectedExceptions')).toEqual(
        exceptions.branch_exceptions,
      );
    });

    it('should remove selection from rule', () => {
      factory({
        props: {
          initRule: {
            ...licenseScanBuildRule(),
            ...exceptions,
          },
        },
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      findBranchExceptionSelector().vm.$emit('remove');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            ...licenseScanBuildRule(),
          },
        ],
      ]);
    });
  });

  describe('when editing any attribute of the rule', () => {
    it.each`
      attribute           | currentComponent             | newValue                                           | expected                                | event
      ${'branches'}       | ${findBranches}              | ${{ branches: [PROTECTED_BRANCHES_MOCK[0].name] }} | ${{ branches: UPDATED_RULE.branches }}  | ${'changed'}
      ${'license status'} | ${findPolicyRuleMultiSelect} | ${'Newly Detected'}                                | ${{ license_states: 'Newly Detected' }} | ${'input'}
      ${'licenses'}       | ${findDenyAllowList}         | ${[]}                                              | ${{ licenses: UPDATED_RULE.licenses }}  | ${'select-licenses'}
    `(
      'triggers a changed event by $currentComponent for $attribute with the updated rule',
      async ({ currentComponent, newValue, expected, event }) => {
        factory();
        await currentComponent().vm.$emit(event, newValue);

        expect(wrapper.emitted().changed).toEqual([[expect.objectContaining(expected)]]);
      },
    );
  });

  describe('allow deny list filter', () => {
    const LICENSES = [1, 2].map((id) => ({
      license: { text: `License_${id}`, value: `license_${id}` },
      exceptions: [],
    }));

    const MAPPED_LICENSES = mapComponentLicenseFormatToYaml(LICENSES);

    it('does not render deny allow list when removed', async () => {
      factory();

      await findDenyAllowList().vm.$emit('remove');

      expect(findDenyAllowList().exists()).toBe(false);
      expect(findScanFilterSelector().props('filters')).toEqual(
        LICENCE_FILTERS.filter((f) => f.value !== OVERRIDES),
      );
    });

    it('renders allow deny list filter', () => {
      factory();
      expect(findDenyAllowList().exists()).toBe(true);
    });

    it.each(['denied', 'allowed'])('renders selected deny list', (key) => {
      factory({
        props: {
          initRule: {
            ...licenseScanBuildRule(),
            licenses: { [key]: [] },
          },
        },
      });

      expect(findDenyAllowList().exists()).toBe(true);
    });

    it('can change list type', async () => {
      factory();

      await findScanFilterSelector().vm.$emit('select', ALLOW_DENY);

      expect(findDenyAllowList().exists()).toBe(true);

      await findDenyAllowList().vm.$emit('select-type', DENIED);

      expect(wrapper.emitted('changed')[1]).toEqual([
        { ...licenseScanBuildRule(), licenses: { [DENIED]: [] } },
      ]);
    });

    it('can remove allow deny list', async () => {
      const rule = licenseScanBuildRule();
      delete rule.licenses;

      factory();

      await findScanFilterSelector().vm.$emit('select', ALLOW_DENY);

      expect(findDenyAllowList().exists()).toBe(true);

      await findDenyAllowList().vm.$emit('remove');

      expect(findDenyAllowList().exists()).toBe(false);
      expect(wrapper.emitted('changed')[1]).toEqual([rule]);
    });

    it('selects licenses', async () => {
      factory();

      await findScanFilterSelector().vm.$emit('select', ALLOW_DENY);
      await findDenyAllowList().vm.$emit('select-licenses', LICENSES);

      expect(wrapper.emitted('changed')[1]).toEqual([
        {
          ...licenseScanBuildRule(),
          licenses: { [ALLOWED]: MAPPED_LICENSES },
        },
      ]);
    });

    it('renders selected licenses from allow deny list', () => {
      factory({
        props: {
          initRule: {
            ...licenseScanBuildRule(),
            licenses: { [DENIED]: MAPPED_LICENSES },
          },
        },
      });

      expect(findDenyAllowList().props('licenses')).toEqual([
        { license: { value: 'license_1', text: 'license_1' }, exceptions: [] },
        { license: { value: 'license_2', text: 'license_2' }, exceptions: [] },
      ]);
    });

    it('renders error state when types and licenses selected', () => {
      factory({
        props: {
          initRule: {
            ...licenseScanBuildRule(),
            license_types: [],
          },
        },
      });

      expect(findAlert().text()).toBe(
        'You can specify either a license state (allowlist or denylist) or a license type, not both.',
      );
      expect(findLicenseFilter().props('hasError')).toBe(true);
      expect(findDenyAllowList().props('hasError')).toBe(true);
    });

    it('does not show error when only licenses selected', () => {
      const rule = { ...licenseScanBuildRule() };
      delete rule.license_types;

      factory({
        props: {
          initRule: {
            ...rule,
            licenses: { [DENIED]: MAPPED_LICENSES },
          },
        },
      });

      expect(findAlert().exists()).toBe(false);
      expect(findLicenseFilter().exists()).toBe(false);
      expect(findDenyAllowList().props('hasError')).toBe(false);
    });
  });

  describe('updateOverrides', () => {
    const findLicenseOverridesList = () => wrapper.findComponent(LicenseOverridesList);

    beforeEach(() => {
      factory({
        props: {
          initRule: {
            ...licenseScanBuildRule(),
            [LICENSE_OVERRIDES]: [{ purl: 'pkg:pypi/urllib3', license: 'MIT', mode: 'patch' }],
          },
        },
        provide: { enabledExperiments: ['license_overrides'] },
      });
    });

    it('emits changed with the updated overrides when non-empty', async () => {
      const newOverrides = [{ purl: 'pkg:npm/lodash', license: 'MIT', mode: 'patch' }];
      await findLicenseOverridesList().vm.$emit('update', newOverrides);

      const emitted = wrapper.emitted('changed');
      expect(emitted[emitted.length - 1][0][LICENSE_OVERRIDES]).toEqual(newOverrides);
    });

    it('removes the license_overrides key when an empty array is saved', async () => {
      await findLicenseOverridesList().vm.$emit('update', []);

      const emitted = wrapper.emitted('changed');
      expect(emitted[emitted.length - 1][0]).not.toHaveProperty(LICENSE_OVERRIDES);
    });
  });
});
