import { GlLink } from '@gitlab/ui';
import PipelineExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/details_drawer.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import VariablesOverrideConfiguration from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/variables_override_configuration.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER,
} from 'ee/security_orchestration/components/constants';
import {
  mockProjectPipelineExecutionPolicy,
  mockProjectPipelineExecutionWithConfigurationPolicy,
  mockProjectPipelineExecutionSchedulePolicy,
  mockSnoozePipelineExecutionSchedulePolicy,
  mockProjectPipelineExecutionWithVariablesOverride,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';

const addType = (policy, type = PIPELINE_EXECUTION_POLICY_TYPE_HEADER) => ({
  ...policy,
  policyType: type,
});

const mockWithTypeProjectPipelineExecutionPolicy = addType(mockProjectPipelineExecutionPolicy);
const mockWithTypeProjectPipelineExecutionWithConfigurationPolicy = addType(
  mockProjectPipelineExecutionWithConfigurationPolicy,
);
const mockWithTypeProjectPipelineExecutionSchedulePolicy = addType(
  mockProjectPipelineExecutionSchedulePolicy,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER,
);
const mockWithTypeSnoozePipelineExecutionSchedulePolicy = addType(
  mockSnoozePipelineExecutionSchedulePolicy,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER,
);

describe('PipelineExecutionDrawer', () => {
  let wrapper;

  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findSchedule = () => wrapper.findByTestId('schedule-summary');
  const findSummaryHeader = () => wrapper.findByTestId('summary-header');
  const findSummaryFields = () => wrapper.findAllByTestId('summary-fields');
  const findProjectSummary = () => wrapper.findByTestId('project');
  const findFileSummary = () => wrapper.findByTestId('file');
  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);
  const findLink = (parent) => parent.findComponent(GlLink);
  const findConfigurationRow = () => wrapper.findByTestId('policy-configuration');
  const findSnoozeSummary = () => wrapper.findByTestId('snooze-summary');
  const findVariablesOverrideConfiguration = () =>
    wrapper.findComponent(VariablesOverrideConfiguration);

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(PipelineExecutionDrawer, {
      propsData,
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT, ...provide },
      stubs: {
        PolicyDrawerLayout,
      },
    });
  };

  describe('pipeline execution policy', () => {
    it('renders layout if yaml is invalid', () => {
      createComponent({ propsData: { policy: {} } });

      expect(findPolicyDrawerLayout().exists()).toBe(true);
      expect(findPolicyDrawerLayout().props()).toMatchObject({ description: '', type: '' });
    });

    it('renders the policy drawer layout component', () => {
      createComponent({ propsData: { policy: mockWithTypeProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props()).toMatchObject({
        policy: mockWithTypeProjectPipelineExecutionPolicy,
        type: PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
      });
    });

    it('passes the description to the PolicyDrawerLayout component', () => {
      createComponent({ propsData: { policy: mockWithTypeProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props('description')).toBe(
        'This policy enforces pipeline execution with configuration from external file',
      );
    });

    it('does not render schedule section', () => {
      createComponent({ propsData: { policy: mockWithTypeProjectPipelineExecutionPolicy } });
      expect(findSchedule().exists()).toBe(false);
    });
  });

  describe('pipeline execution schedule policy', () => {
    it('renders the policy drawer layout component', () => {
      createComponent({
        propsData: { policy: mockWithTypeProjectPipelineExecutionSchedulePolicy },
      });
      expect(findPolicyDrawerLayout().props()).toMatchObject({
        policy: mockWithTypeProjectPipelineExecutionSchedulePolicy,
        type: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER,
      });
    });

    it('renders schedules', () => {
      createComponent({
        propsData: { policy: mockWithTypeProjectPipelineExecutionSchedulePolicy },
      });
      expect(findSchedule().exists()).toBe(true);
      expect(findSchedule().text()).toBe(
        'Schedule the following pipeline execution policy to run for default branch daily at 00:00 and run for 1 hour in timezone Etc/UTC.',
      );
    });

    it('does not render the snooze info if it does not exist', () => {
      createComponent({
        propsData: { policy: mockWithTypeProjectPipelineExecutionSchedulePolicy },
      });
      expect(findSnoozeSummary().exists()).toBe(false);
    });

    it('renders the snooze info if it exists', () => {
      createComponent({ propsData: { policy: mockWithTypeSnoozePipelineExecutionSchedulePolicy } });
      expect(findSnoozeSummary().exists()).toBe(true);
    });
  });

  describe('summary', () => {
    it('renders paragraph policy summary as text', () => {
      createComponent({ propsData: { policy: mockWithTypeProjectPipelineExecutionPolicy } });

      expect(findSummary().exists()).toBe(true);
      expect(findConfigurationRow().exists()).toBe(true);
      expect(findSummaryFields()).toHaveLength(1);
      const text = trimText(findSummaryFields().at(0).text());
      expect(text).toContain('Project : gitlab-policies/js6');
      expect(text).toContain('Reference : main');
      expect(text).toContain('Path : pipeline_execution_jobs.yml');
      expect(findSummaryHeader().text()).toBe('Enforce the following pipeline execution policy:');
    });

    it('renders the policy summary as a link for the project field', () => {
      createComponent({ propsData: { policy: mockWithTypeProjectPipelineExecutionPolicy } });

      const link = findLink(findProjectSummary());
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe('/gitlab-policies/js6');
      expect(link.text()).toBe('gitlab-policies/js6');
    });

    it('renders the policy summary as a link for the file field', () => {
      createComponent({ propsData: { policy: mockWithTypeProjectPipelineExecutionPolicy } });

      const link = findLink(findFileSummary());
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(
        '/path/to/project/-/blob/main/pipeline_execution_jobs.yml',
      );
      expect(link.text()).toBe('pipeline_execution_jobs.yml');
    });
  });

  describe('configuration', () => {
    it('renders default configuration row if there is no configuration in policy', () => {
      createComponent({
        propsData: { policy: mockWithTypeProjectPipelineExecutionPolicy },
      });

      expect(findConfigurationRow().exists()).toBe(true);
    });

    it('renders configuration row when there is a configuration', () => {
      createComponent({
        propsData: { policy: mockWithTypeProjectPipelineExecutionWithConfigurationPolicy },
      });

      expect(findConfigurationRow().exists()).toBe(true);
    });
  });

  describe('variables override', () => {
    it('does not render override list when there is no variables_override', () => {
      createComponent({
        propsData: { policy: mockProjectPipelineExecutionPolicy },
      });

      expect(findVariablesOverrideConfiguration().exists()).toBe(false);
    });

    it('renders override list when it is present in the policy', () => {
      createComponent({
        propsData: { policy: mockProjectPipelineExecutionWithVariablesOverride },
      });
      expect(findVariablesOverrideConfiguration().exists()).toBe(true);
      expect(findVariablesOverrideConfiguration().props('variablesOverride')).toEqual({
        allowed: false,
        exceptions: ['DAST_BROWSER_DEVTOOLS_LOG', 'DAST_BROWSER_DEVTOOLS'],
      });
    });
  });
});
