import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  APPROVAL_POLICY_TYPE,
  PIPELINE_EXECUTION_POLICY_TYPE,
  POLICY_TYPE_COMPONENT_OPTIONS,
  SCAN_EXECUTION_POLICY_TYPE,
  VULNERABILITY_MANAGEMENT_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import { SECURITY_POLICY_ACTIONS } from 'ee/security_orchestration/components/policy_editor/constants';
import { goToPolicyMR } from 'ee/security_orchestration/components/policy_editor/utils';
import getSecurityPolicyProjectSub from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import EditorWrapper from 'ee/security_orchestration/components/policy_editor/editor_wrapper.vue';
import PipelineExecutionPolicyEditor from 'ee/security_orchestration/components/policy_editor/pipeline_execution/editor_component.vue';
import ScanExecutionPolicyEditor from 'ee/security_orchestration/components/policy_editor/scan_execution/editor_component.vue';
import ScanResultPolicyEditor from 'ee/security_orchestration/components/policy_editor/scan_result/editor_component.vue';
import VulnerabilityManagementPolicyEditor from 'ee/security_orchestration/components/policy_editor/vulnerability_management/editor_component.vue';
import {
  mockDastScanExecutionManifest,
  mockDastScanExecutionObject,
} from '../../mocks/mock_scan_execution_policy_data';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  goToPolicyMR: jest.fn().mockResolvedValue(),
}));

Vue.use(VueApollo);

describe('EditorWrapper component', () => {
  let wrapper;
  const getSecurityPolicyProjectSubscriptionErrorAsDataHandlerMock = jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectCreated: {
        project: null,
        status: null,
        errors: ['There was an error', 'error reason'],
      },
    },
  });

  const getSecurityPolicyProjectSubscriptionHandlerMock = jest.fn().mockResolvedValue({
    data: {
      securityPolicyProjectCreated: {
        project: {
          name: 'New security policy project',
          fullPath: 'path/to/new-project',
          id: '01',
          branch: {
            rootRef: 'main',
          },
        },
        status: null,
        errors: [],
      },
    },
  });

  const defaultProjectPath = 'path/to/project';

  const findErrorAlert = () => wrapper.findComponentByTestId('error-alert');
  const findPipelineExecutionPolicyEditor = () =>
    wrapper.findComponent(PipelineExecutionPolicyEditor);
  const findScanExecutionPolicyEditor = () => wrapper.findComponent(ScanExecutionPolicyEditor);
  const findScanResultPolicyEditor = () => wrapper.findComponent(ScanResultPolicyEditor);
  const findVulnerabilityManagementPolicyEditor = () =>
    wrapper.findComponent(VulnerabilityManagementPolicyEditor);

  const factory = ({
    propsData = {},
    provide = {},
    subscriptionMock = getSecurityPolicyProjectSubscriptionHandlerMock,
  } = {}) => {
    wrapper = shallowMountExtended(EditorWrapper, {
      propsData: {
        selectedPolicy: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution,
        ...propsData,
      },
      provide: {
        namespacePath: defaultProjectPath,
        policyType: undefined,
        ...provide,
      },
      apolloProvider: createMockApollo([[getSecurityPolicyProjectSub, subscriptionMock]]),
    });
  };

  describe('when there is no existingPolicy', () => {
    describe('project-level', () => {
      beforeEach(factory);

      it.each`
        component        | findComponent
        ${'error alert'} | ${findErrorAlert}
      `('does not display the $component', ({ findComponent }) => {
        expect(findComponent().exists()).toBe(false);
      });

      it('renders the policy editor component', () => {
        expect(findScanExecutionPolicyEditor().props('existingPolicy')).toBe(null);
      });

      it('shows an alert when "error" is emitted from the component', async () => {
        const errorMessage = 'test';
        await findScanExecutionPolicyEditor().vm.$emit('error', errorMessage);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe(errorMessage);
      });

      it('shows an alert with details when multiline "error" is emitted from the component', async () => {
        const errorMessages = 'title\ndetail1';
        await findScanExecutionPolicyEditor().vm.$emit('error', errorMessages);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('title');
        expect(alert.text()).toBe('detail1');
      });

      it.each`
        policyType                                               | findComponent                              | selectedPolicyType
        ${POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution}       | ${findPipelineExecutionPolicyEditor}       | ${PIPELINE_EXECUTION_POLICY_TYPE}
        ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution}           | ${findScanExecutionPolicyEditor}           | ${SCAN_EXECUTION_POLICY_TYPE}
        ${POLICY_TYPE_COMPONENT_OPTIONS.approval}                | ${findScanResultPolicyEditor}              | ${APPROVAL_POLICY_TYPE}
        ${POLICY_TYPE_COMPONENT_OPTIONS.vulnerabilityManagement} | ${findVulnerabilityManagementPolicyEditor} | ${VULNERABILITY_MANAGEMENT_POLICY_TYPE}
      `(
        'renders the policy editor of type $policyType when selected',
        ({ findComponent, policyType, selectedPolicyType }) => {
          factory({ propsData: { selectedPolicy: policyType } });
          const component = findComponent();
          expect(component.exists()).toBe(true);
          expect(component.props('isEditing')).toBe(false);
          expect(component.props('selectedPolicyType')).toBe(selectedPolicyType);
        },
      );
    });
  });

  describe('when there is existingPolicy attached', () => {
    beforeEach(() => {
      factory({
        provide: {
          existingPolicy: mockDastScanExecutionObject,
        },
        subscriptionMock: getSecurityPolicyProjectSubscriptionHandlerMock,
      });
    });

    it('renders the policy editor for editing', () => {
      expect(findScanExecutionPolicyEditor().props('isEditing')).toBe(true);
    });
  });

  describe('subscription', () => {
    it('subscribes to the newlyCreatedPolicyProject subscription', () => {
      factory();
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).toHaveBeenCalledTimes(1);
    });

    it('updates the project when the subscription fulfills with a project', async () => {
      factory({
        provide: {
          namespacePath: 'path/to/namespace',
        },
      });
      await waitForPromises();
      expect(findScanExecutionPolicyEditor().props('errorMessages')).toBe(undefined);
      expect(goToPolicyMR).not.toHaveBeenCalled();
    });

    it('shows the errors when the subscription fails to create due to an SPP already existing with the same name, but not linked', async () => {
      factory({
        subscriptionMock: getSecurityPolicyProjectSubscriptionErrorAsDataHandlerMock,
      });
      await waitForPromises();
      const alert = findErrorAlert();
      expect(alert.exists()).toBe(true);
      expect(alert.props('title')).toBe('There was an error');
      expect(alert.text()).toBe('error reason');
    });

    it('shows the errors when the subscription fails due to a configuration issue', async () => {
      const getSecurityPolicyProjectSubscriptionErrorHandlerMock = jest
        .fn()
        .mockRejectedValue({ message: 'error' });
      factory({
        subscriptionMock: getSecurityPolicyProjectSubscriptionErrorHandlerMock,
      });
      await waitForPromises();
      const alert = findErrorAlert();

      expect(alert.exists()).toBe(true);
      expect(alert.props('title')).toBe('error');
      expect(alert.text()).toBe('');
    });

    it('uses the new security policy project if creating a policy fails the first time', async () => {
      goToPolicyMR.mockRejectedValueOnce([{}]);
      factory();
      await waitForPromises();
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).toHaveBeenCalledTimes(1);
      findScanExecutionPolicyEditor().vm.$emit('save', {
        action: SECURITY_POLICY_ACTIONS.APPEND,
        policy: mockDastScanExecutionManifest,
      });
      await waitForPromises();
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).toHaveBeenCalledTimes(1);
      expect(goToPolicyMR).toHaveBeenCalledTimes(1);
      findScanExecutionPolicyEditor().vm.$emit('save', {
        action: SECURITY_POLICY_ACTIONS.APPEND,
        policy: mockDastScanExecutionManifest,
      });
      await waitForPromises();
      expect(getSecurityPolicyProjectSubscriptionHandlerMock).toHaveBeenCalledTimes(1);
      expect(goToPolicyMR).toHaveBeenCalledTimes(2);
      expect(goToPolicyMR).toHaveBeenCalledWith({
        action: SECURITY_POLICY_ACTIONS.APPEND,
        assignedPolicyProject: {
          branch: 'main',
          fullPath: 'path/to/new-project',
          id: '01',
          name: 'New security policy project',
        },
        extraMergeRequestInput: null,
        name: mockDastScanExecutionObject.name,
        namespacePath: defaultProjectPath,
        yamlEditorValue: mockDastScanExecutionManifest,
      });
    });
  });

  describe('creating an MR with the policy changes', () => {
    describe('without an assigned policy project', () => {
      it('does not make the request to create the MR without an assigned policy project', async () => {
        await factory({
          subscriptionMock: getSecurityPolicyProjectSubscriptionErrorAsDataHandlerMock,
        });
        findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(goToPolicyMR).not.toHaveBeenCalled();
      });
    });

    describe('existing policy', () => {
      it.each`
        status                            | action
        ${'to update an existing policy'} | ${SECURITY_POLICY_ACTIONS.REPLACE}
        ${'to delete an existing policy'} | ${SECURITY_POLICY_ACTIONS.REMOVE}
      `('makes the request to "goToPolicyMR" $status', async ({ action }) => {
        factory({
          provide: {
            existingPolicy: mockDastScanExecutionObject,
          },
          subscriptionMock: getSecurityPolicyProjectSubscriptionHandlerMock,
        });
        findScanExecutionPolicyEditor().vm.$emit('save', {
          action,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(goToPolicyMR).toHaveBeenCalledTimes(1);
        expect(goToPolicyMR).toHaveBeenCalledWith({
          action,
          assignedPolicyProject: {
            name: 'New security policy project',
            fullPath: 'path/to/new-project',
            id: '01',
            branch: 'main',
          },
          extraMergeRequestInput: null,
          name: mockDastScanExecutionObject.name,
          namespacePath: defaultProjectPath,
          yamlEditorValue: mockDastScanExecutionManifest,
        });
      });
    });

    describe('compliance framework migration', () => {
      it('passes extra merge request input to goToPolicyMR', async () => {
        factory({
          provide: {
            existingPolicy: mockDastScanExecutionObject,
          },
          subscriptionMock: getSecurityPolicyProjectSubscriptionHandlerMock,
        });
        const extraMergeRequestInput = {
          title: 'test',
          description: 'test',
        };
        findScanExecutionPolicyEditor().vm.$emit('save', {
          action: undefined,
          policy: mockDastScanExecutionManifest,
          extraMergeRequestInput,
        });
        await waitForPromises();
        expect(goToPolicyMR).toHaveBeenCalledTimes(1);
        expect(goToPolicyMR).toHaveBeenCalledWith(
          expect.objectContaining({ extraMergeRequestInput }),
        );
      });
    });

    describe('error handling', () => {
      const createError = (cause) => ({ message: 'There was an error', cause });
      const approverCause = { field: 'actions' };
      const branchesCause = { field: 'branches' };
      const unknownCause = { field: 'unknown' };

      it('passes down an error with the cause of `approvers_ids` and does not display an error', async () => {
        const error = createError([approverCause]);
        goToPolicyMR.mockRejectedValue(error);
        factory();
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
          isRuleMode: true,
        });
        await waitForPromises();
        await nextTick();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['action', '0', 'actions', [approverCause]],
        ]);
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('passes down an error with the cause of `action` and does not display an error', async () => {
        const error = createError([approverCause]);
        goToPolicyMR.mockRejectedValue(error);
        factory();
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
          isRuleMode: true,
        });
        await waitForPromises();
        await nextTick();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['action', '0', 'actions', [approverCause]],
        ]);
        expect(findErrorAlert().exists()).toBe(false);
      });

      it('passes errors with the cause of `branches` and displays an error', async () => {
        const branchesError = {
          message:
            "Invalid policy YAML\n property '/approval_policy/5/rules/0/branches' is missing required keys: branches ",
          cause: { field: 'branches' },
        };
        goToPolicyMR.mockRejectedValue(branchesError);
        factory();
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['rules', '0', 'branches'],
        ]);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('Invalid policy YAML');
        expect(alert.text()).toBe(
          "property '/approval_policy/5/rules/0/branches' is missing required keys: branches",
        );
      });

      it('does not pass down an error with an unknown cause and displays an error', async () => {
        goToPolicyMR.mockRejectedValue(createError([unknownCause]));
        factory();
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([]);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('There was an error');
        expect(alert.text()).toBe('');
      });

      it('clears errorSources when a new save is initiated after a previous failure', async () => {
        const timeWindowError = {
          message:
            "Invalid policy\nSchedule time window value exceeds the maximum allowed duration of approximately 30 days\nproperty '/pipeline_execution_schedule_policy/0/schedules/0/time_window/value' is invalid",
          cause: [{ field: 'time_window', index: 0 }],
        };
        goToPolicyMR.mockRejectedValueOnce(timeWindowError);
        factory();

        findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await waitForPromises();

        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['schedules', '0', 'time_window'],
        ]);

        findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
        });
        await nextTick();

        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([]);
      });

      it('handles mixed errors', async () => {
        const error = createError([approverCause, branchesCause, unknownCause]);
        goToPolicyMR.mockRejectedValue(error);
        factory();
        await findScanExecutionPolicyEditor().vm.$emit('save', {
          action: SECURITY_POLICY_ACTIONS.APPEND,
          policy: mockDastScanExecutionManifest,
          isRuleMode: true,
        });
        await waitForPromises();
        expect(findScanExecutionPolicyEditor().props('errorSources')).toEqual([
          ['action', '0', 'actions', [approverCause]],
        ]);
        const alert = findErrorAlert();
        expect(alert.exists()).toBe(true);
        expect(alert.props('title')).toBe('There was an error');
        expect(alert.text()).toBe('');
      });
    });
  });
});
