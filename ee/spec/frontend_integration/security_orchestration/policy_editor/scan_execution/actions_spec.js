import * as urlUtils from '~/lib/utils/url_utility';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import GroupDastProfileSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/group_dast_profile_selector.vue';
import ProjectDastProfileSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/project_dast_profile_selector.vue';
import RunnerTagsList from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/runner_tags_list.vue';
import CiVariablesSelectors from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/ci_variables_selectors.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  REPORT_TYPE_SAST,
  REPORT_TYPE_SAST_IAC,
  REPORT_TYPE_DAST,
  REPORT_TYPE_SECRET_DETECTION,
} from '~/vue_shared/security_reports/constants';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { navigateToCustomMode, verify } from '../utils';
import {
  createScanActionScanExecutionManifest,
  mockDastActionScanExecutionManifest,
  mockGroupDastActionScanExecutionManifest,
  mockActionsVariablesScanExecutionManifest,
} from './mocks';

describe('Scan execution policy actions', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        existingPolicy: null,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
      },
    });
  };

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('scan_execution_policy');
  });

  afterEach(() => {
    window.gon = {};
  });

  const findCiVariablesSelectors = () => wrapper.findComponent(CiVariablesSelectors);
  const findDisabledActionSection = () => wrapper.findComponentByTestId('disabled-action');
  const findGroupDastProfileSelector = () => wrapper.findComponent(GroupDastProfileSelector);
  const findProjectDastProfileSelector = () => wrapper.findComponent(ProjectDastProfileSelector);
  const findRunnerTagsList = () => wrapper.findComponent(RunnerTagsList);
  const findScanFilterButton = () => wrapper.findComponentByTestId('add-variable-button');
  const findScanTypeSelector = () => wrapper.findComponentByTestId('scan-type-selector');

  describe('non-dast scanners', () => {
    beforeEach(async () => {
      await createWrapper();
      await navigateToCustomMode(wrapper);
    });

    it.each`
      scanType
      ${REPORT_TYPE_SAST}
      ${REPORT_TYPE_SAST_IAC}
      ${REPORT_TYPE_SECRET_DETECTION}
    `(`selects $scanType as action`, async ({ scanType }) => {
      const verifyRuleMode = () => {
        expect(findScanTypeSelector().exists()).toBe(true);
        expect(findRunnerTagsList().exists()).toBe(true);
        expect(findDisabledActionSection().props('disabled')).toBe(false);
      };

      await findScanTypeSelector().vm.$emit('select', scanType);

      await verify({
        manifest: createScanActionScanExecutionManifest(scanType, true),
        verifyRuleMode,
        wrapper,
      });
    });
  });

  describe('dast scanner', () => {
    it.each`
      namespaceType              | findDastSelector                  | manifest
      ${NAMESPACE_TYPES.PROJECT} | ${findProjectDastProfileSelector} | ${mockDastActionScanExecutionManifest}
      ${NAMESPACE_TYPES.GROUP}   | ${findGroupDastProfileSelector}   | ${mockGroupDastActionScanExecutionManifest}
    `(
      'selects secret detection dast as action',
      async ({ namespaceType, findDastSelector, manifest }) => {
        await createWrapper({ provide: { namespaceType } });
        await navigateToCustomMode(wrapper);

        const verifyRuleMode = () => {
          expect(findScanTypeSelector().exists()).toBe(true);
          expect(findDastSelector().exists()).toBe(true);
          expect(findRunnerTagsList().exists()).toBe(true);
          expect(findDisabledActionSection().props('disabled')).toBe(false);
        };

        await findScanTypeSelector().vm.$emit('select', REPORT_TYPE_DAST);

        await verify({ manifest, verifyRuleMode, wrapper });
      },
    );
  });

  describe('actions filters', () => {
    beforeEach(async () => {
      await createWrapper();
      await navigateToCustomMode(wrapper);
    });

    it('selects variables filter', async () => {
      const verifyRuleMode = () => {
        expect(findScanTypeSelector().exists()).toBe(true);
        expect(findRunnerTagsList().exists()).toBe(true);
        expect(findCiVariablesSelectors().exists()).toBe(true);
        expect(findDisabledActionSection().props('disabled')).toBe(false);
      };

      await findScanTypeSelector().vm.$emit('select', REPORT_TYPE_SECRET_DETECTION);
      await findScanFilterButton().vm.$emit('click');
      await findCiVariablesSelectors().vm.$emit('input', { variables: { a: 'b' } });
      await verify({
        manifest: mockActionsVariablesScanExecutionManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });
});
