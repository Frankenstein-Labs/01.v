import { GlModal } from '@gitlab/ui';
import * as urlUtils from '~/lib/utils/url_utility';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import { goToPolicyMR } from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { DEFAULT_PROVIDE } from './mocks/mocks';
import { createMockApolloProvider } from './pipeline_execution/apollo_util';
import { mockPipelineExecutionObject } from './pipeline_execution/mocks';
import { mockScanExecutionObject } from './scan_execution/mocks';
import { mockScanResultObject } from './scan_result/mocks';
import { mockVulnerabilityManagementObject } from './vulnerability_management/mocks';

jest.mock('ee/security_orchestration/components/policy_editor/utils', () => ({
  ...jest.requireActual('ee/security_orchestration/components/policy_editor/utils'),
  goToPolicyMR: jest.fn().mockResolvedValue(),
}));

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  getParameterByName: jest.fn(),
}));

jest.mock('~/lib/logger');

describe('Policy Editor', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(App, {
      apolloProvider: createMockApolloProvider([
        [getSppLinkedProjectsGroups, mockLinkedSppItemsResponse()],
      ]),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        glFeatures,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
      },
    });
  };

  const findDeletePolicyModal = () => wrapper.findAllComponents(GlModal).at(-1);
  const findSavePolicyButton = () => wrapper.findComponentByTestId('save-policy');

  describe.each`
    type                          | optionType                   | existingPolicy
    ${'merge request approval'}   | ${'approval'}                | ${mockScanResultObject}
    ${'pipeline execution'}       | ${'pipelineExecution'}       | ${mockPipelineExecutionObject}
    ${'scan execution'}           | ${'scanExecution'}           | ${mockScanExecutionObject}
    ${'vulnerability management'} | ${'vulnerabilityManagement'} | ${mockVulnerabilityManagementObject}
  `('$type policy', ({ existingPolicy, optionType }) => {
    beforeAll(() => {
      jest
        .spyOn(urlUtils, 'getParameterByName')
        .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS[optionType].urlParameter);
    });

    it('saves a policy', async () => {
      await createWrapper({ provide: { ...DEFAULT_PROVIDE, existingPolicy } });
      await findSavePolicyButton().vm.$emit('click');
      await waitForPromises();
      expect(goToPolicyMR).toHaveBeenCalledTimes(1);
      expect(goToPolicyMR).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'REPLACE',
          assignedPolicyProject: {
            name: 'New project',
            fullPath: 'path/to/new-project',
            id: '01',
            branch: 'main',
          },
          extraMergeRequestInput: null,
          namespacePath: DEFAULT_PROVIDE.namespacePath,
        }),
      );
    });

    it('deletes a policy', async () => {
      await createWrapper({ provide: { ...DEFAULT_PROVIDE, existingPolicy } });
      await findDeletePolicyModal().vm.$emit('secondary');
      await waitForPromises();
      expect(goToPolicyMR).toHaveBeenCalledTimes(1);
      expect(goToPolicyMR).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'REMOVE',
          assignedPolicyProject: {
            name: 'New project',
            fullPath: 'path/to/new-project',
            id: '01',
            branch: 'main',
          },
          extraMergeRequestInput: null,
          namespacePath: DEFAULT_PROVIDE.namespacePath,
        }),
      );
    });
  });
});
