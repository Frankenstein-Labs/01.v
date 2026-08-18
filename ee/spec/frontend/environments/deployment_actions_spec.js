import Vue from 'vue';
import VueApollo from 'vue-apollo';
import DeploymentActions from '~/environments/environment_details/components/deployment_actions.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import EnvironmentApprovalComponent from 'ee_component/environments/components/environment_approval.vue';
import createMockApollo from 'helpers/mock_apollo_helper';

describe('~/environments/environment_details/components/deployment_actions.vue', () => {
  Vue.use(VueApollo);
  let wrapper;

  const emptyApprovalEnvironmentData = {
    isApprovalActionAvailable: false,
  };

  const approvalEnvironmentData = {
    isApprovalActionAvailable: true,
    deploymentIid: '12',
    environment: {
      name: 'production',
      tier: 'prod',
      requiredApprovalCount: 1,
    },
  };

  const deploymentWebPath = '/path/to/deployment';

  const mockSetEnvironmentToRollback = jest.fn();
  const mockResolvers = {
    Mutation: {
      setEnvironmentToRollback: mockSetEnvironmentToRollback,
    },
  };
  const createWrapper = ({ actions, rollback, approvalEnvironment, status }) => {
    const mockApollo = createMockApollo([], mockResolvers);
    return mountExtended(DeploymentActions, {
      apolloProvider: mockApollo,
      provide: {
        projectPath: 'fullProjectPath',
      },
      propsData: {
        actions,
        rollback,
        approvalEnvironment,
        deploymentWebPath,
        status,
      },
    });
  };

  describe('environment-approval', () => {
    describe('when there is no environment approval data available', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          actions: [],
          approvalEnvironment: emptyApprovalEnvironmentData,
          status: 'failed',
        });
      });

      it('should not show environment-approval component', () => {
        const environmentApproval = wrapper.findComponent(EnvironmentApprovalComponent);

        expect(environmentApproval.exists()).toBe(false);
      });
    });

    describe('when there is environment approval data available', () => {
      beforeEach(() => {
        wrapper = createWrapper({
          actions: [],
          approvalEnvironment: approvalEnvironmentData,
          status: 'running',
        });
      });

      it('should render environment-approval component with correct props', () => {
        const environmentApproval = wrapper.findComponent(EnvironmentApprovalComponent);

        expect(environmentApproval.props()).toEqual({
          deploymentWebPath,
          requiredApprovalCount: 1,
          showText: false,
          size: 'medium',
          status: 'running',
        });
      });
    });
  });
});
