import { GlSprintf } from '@gitlab/ui';
import { trimText } from 'helpers/text_helper';
import DetailsDrawer from 'ee/security_orchestration/components/policy_drawer/scan_execution/details_drawer.vue';
import DrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import Tags from 'ee/security_orchestration/components/policy_drawer/scan_execution/humanized_actions/tags.vue';
import ToggleList from 'ee/security_orchestration/components/scope/toggle_list.vue';
import Variables from 'ee/security_orchestration/components/policy_drawer/scan_execution/humanized_actions/variables.vue';
import SkipCiConfiguration from 'ee/security_orchestration/components/policy_drawer/skip_ci_configuration.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockBranchExceptionsProjectScanExecutionPolicy,
  mockUnsupportedAttributeScanExecutionPolicy,
  mockProjectScanExecutionPolicy,
  mockNoActionsScanExecutionManifest,
  mockMultipleActionsScanExecutionManifest,
  mockCiVariablesWithTagsScanExecutionManifest,
  mockProjectScanExecutionWithConfigurationPolicy,
  mockScanExecutionPolicyManifestWithWrapper,
} from 'ee_jest/security_orchestration/mocks/mock_scan_execution_policy_data';
import { DEFAULT_SKIP_SI_CONFIGURATION } from 'ee/security_orchestration/components/constants';

describe('DetailsDrawer component', () => {
  let wrapper;
  const defaultPolicy = {
    policyScope: { projects: { excluding: [] } },
    yaml: 'test yaml',
  };

  const createComponent = (policy = {}, provide = {}) => {
    wrapper = shallowMountExtended(DetailsDrawer, {
      propsData: {
        policy: {
          ...defaultPolicy,
          ...policy,
        },
      },
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT, namespacePath: 'gitlab-org', ...provide },
      stubs: { GlSprintf },
    });
  };

  const findActions = () => wrapper.findByTestId('actions');
  const findDrawerLayout = () => wrapper.findComponent(DrawerLayout);
  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findRules = () => wrapper.findByTestId('rules');
  const findTags = () => wrapper.findComponent(Tags);
  const findToggleList = () => wrapper.findComponent(ToggleList);
  const findVariables = () => wrapper.findComponent(Variables);
  const findConfigurationRow = () => wrapper.findByTestId('policy-configuration');
  const findSkipCiConfiguration = () => wrapper.findComponent(SkipCiConfiguration);

  describe('template', () => {
    it('renders the drawer layout', () => {
      createComponent();
      expect(findDrawerLayout().exists()).toBe(true);
      expect(findDrawerLayout().props()).toMatchObject({
        description: '',
        policy: defaultPolicy,
        policyScope: defaultPolicy.policyScope,
        type: 'Scan execution',
      });
      expect(findConfigurationRow().exists()).toBe(true);
    });

    it('renders copy informing when there are no actions', () => {
      createComponent({
        ...mockProjectScanExecutionPolicy,
        yaml: mockNoActionsScanExecutionManifest,
      });
      expect(findActions().text()).toContain('No action');
    });

    it('renders actions information when there are multiple actions', () => {
      createComponent({
        ...mockProjectScanExecutionPolicy,
        yaml: mockMultipleActionsScanExecutionManifest,
      });
      expect(findActions().text()).not.toContain('No action');
      expect(trimText(findActions().text())).toContain(
        'Run Container scanning with the following options: Automatically selected runners With the default security job template Run a Secret detection scan with the following options: Automatically selected runners With the default security job template Run a SAST scan with the following options: Automatically selected runners With the default security job template',
      );
    });

    it('renders tags and variables', () => {
      createComponent({
        ...mockProjectScanExecutionPolicy,
        yaml: mockCiVariablesWithTagsScanExecutionManifest,
      });
      expect(findTags().exists()).toBe(true);
      expect(findTags().props('criteria')).toEqual({
        action: 'TAGS',
        message: 'On runners with tag:',
        tags: ['default'],
      });
      expect(findVariables().exists()).toBe(true);
      expect(findVariables().props('criteria')).toEqual({
        action: 'VARIABLES',
        message: 'With the following customized CI variables:',
        variables: [{ value: 'true', variable: 'SECRET_DETECTION_HISTORIC_SCAN' }],
      });
    });

    it('renders rule message and humanized rules', () => {
      createComponent(mockProjectScanExecutionPolicy);
      expect(findRules().text()).toContain('And scans to be performed:');
      expect(findRules().text()).toContain('Every time a pipeline runs for the main branch');
      expect(findToggleList().exists()).toBe(false);
    });

    it('renders rule branch exceptions', () => {
      createComponent(mockBranchExceptionsProjectScanExecutionPolicy);
      expect(findToggleList().exists()).toBe(true);
    });

    it('renders when unsupported attributes are provided', () => {
      createComponent(mockUnsupportedAttributeScanExecutionPolicy);
      expect(findGlSprintf().exists()).toBe(true);
    });
  });

  describe('empty policy', () => {
    it('renders layout if yaml is invalid', () => {
      createComponent();

      expect(findDrawerLayout().exists()).toBe(true);
      expect(findDrawerLayout().props('description')).toBe('');
    });
  });

  describe('configuration', () => {
    it('renders default configuration row if there is no configuration in policy', () => {
      createComponent(mockScanExecutionPolicyManifestWithWrapper);

      expect(findConfigurationRow().exists()).toBe(true);
      expect(findSkipCiConfiguration().props('configuration')).toEqual(
        DEFAULT_SKIP_SI_CONFIGURATION,
      );
    });

    it('renders configuration row when there is a configuration', () => {
      createComponent(mockProjectScanExecutionWithConfigurationPolicy);

      expect(findConfigurationRow().exists()).toBe(true);
      expect(findSkipCiConfiguration().props('configuration')).toEqual({ allowed: true });
    });
  });
});
