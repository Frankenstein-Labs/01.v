import { mountExtended } from 'helpers/vue_test_utils_helper';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import * as urlUtils from '~/lib/utils/url_utility';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { createMockApolloProvider } from './apollo_util';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  mergeUrlParams: jest.fn(),
}));

describe('Policy Editor', () => {
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
        glFeatures: {
          ...glFeatures,
        },
        ...provide,
      },
    });
  };

  const findSelectPipelineExecutionPolicyButton = () =>
    wrapper.findComponentByTestId('select-policy-pipeline_execution_policy');

  describe('rendering', () => {
    beforeEach(() => {
      createWrapper();
      findSelectPipelineExecutionPolicyButton().vm.$emit('click');
    });

    it('redirects to editor page with correct type', () => {
      expect(urlUtils.mergeUrlParams).toHaveBeenCalledWith(
        { type: 'pipeline_execution_policy' },
        'http://test.host/',
      );
    });
  });
});
