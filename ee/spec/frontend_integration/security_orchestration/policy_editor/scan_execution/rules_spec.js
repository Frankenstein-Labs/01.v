import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import BaseRuleComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/base_rule_component.vue';
import ScheduleRuleComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/schedule_rule_component.vue';
import { SCAN_EXECUTION_SCHEDULE_RULE } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import BranchTypeSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/branch_type_selector.vue';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { navigateToCustomMode, verify } from '../utils';
import { mockScheduleScanExecutionManifest, mockAllBranchesScanExecutionManifest } from './mocks';

describe('Scan execution policy rules', () => {
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
      },
    });
  };

  const findScheduleRuleTypeDropDown = () => wrapper.findComponentByTestId('rule-component-type');

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('scan_execution_policy');
  });

  afterEach(() => {
    window.gon = {};
  });

  const findBaseRuleComponent = () => wrapper.findComponent(BaseRuleComponent);
  const findBranchTypeSelector = () => wrapper.findComponent(BranchTypeSelector);
  const findScheduleRuleComponent = () => wrapper.findComponent(ScheduleRuleComponent);
  const findDisabledRuleSection = () => wrapper.findComponentByTestId('disabled-rule');

  describe('pipeline', () => {
    beforeEach(async () => {
      await createWrapper();
      await navigateToCustomMode(wrapper);
    });

    it('parses pipeline rule', async () => {
      const verifyRuleMode = () => {
        expect(findBaseRuleComponent().exists()).toBe(true);
        expect(findScheduleRuleComponent().exists()).toBe(false);
        expect(findDisabledRuleSection().props('disabled')).toBe(false);
      };

      await findBranchTypeSelector().vm.$emit('set-branch-type', 'all');
      await verify({
        manifest: mockAllBranchesScanExecutionManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });

  describe('schedule rule', () => {
    beforeEach(async () => {
      await createWrapper();
      await navigateToCustomMode(wrapper);
    });

    it('parses schedule rule', async () => {
      const verifyRuleMode = () => {
        expect(findScheduleRuleComponent().exists()).toBe(true);
        expect(findDisabledRuleSection().props('disabled')).toBe(false);
      };

      await findScheduleRuleTypeDropDown().vm.$emit('select', SCAN_EXECUTION_SCHEDULE_RULE);

      await verify({
        manifest: mockScheduleScanExecutionManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });
});
