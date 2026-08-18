import { GlToggle } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import * as urlUtils from '~/lib/utils/url_utility';
import waitForPromises from 'helpers/wait_for_promises';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { verify } from '../utils';
import { mockPipelineExecutionSkipCiManifest } from './mocks';
import { createMockApolloProvider } from './apollo_util';

describe('Skip ci for pipeline execution policy', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {}, glFeatures = {} } = {}) => {
    wrapper = mountExtended(App, {
      apolloProvider: createMockApolloProvider(),
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        existingPolicy: null,
        glFeatures,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
      },
    });
  };

  const findSkipCiSelectorToggle = () => wrapper.findComponent(GlToggle);
  const findSkipCiSelector = () => wrapper.findComponent(SkipCiSelector);

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('pipeline_execution_policy');
  });

  describe('allow skip ci', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('allows to skip ci configuration for pipeline execution', async () => {
      const verifyRuleMode = () => {
        expect(findSkipCiSelector().exists()).toBe(true);
      };

      expect(findSkipCiSelector().props('skipCiConfiguration')).toEqual({
        allowed: false,
      });

      await findSkipCiSelectorToggle().vm.$emit('change', false);

      await verify({
        manifest: mockPipelineExecutionSkipCiManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });
});
