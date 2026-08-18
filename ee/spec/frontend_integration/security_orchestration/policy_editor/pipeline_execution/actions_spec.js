import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import CodeBlockFilePath from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_file_path.vue';
import { OVERRIDE } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import ActionSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/action_section.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { findYamlPreview, verify } from '../utils';
import {
  mockPipelineExecutionActionManifest,
  mockPipelineExecutionOverrideActionManifest,
} from './mocks';
import { createMockApolloProvider } from './apollo_util';

describe('Pipeline execution policy actions', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = mountExtended(App, {
      apolloProvider: createMockApolloProvider(),
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

  const findActionSection = () => wrapper.findComponent(ActionSection);
  const findCodeBlockFilePath = () => wrapper.findComponent(CodeBlockFilePath);

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('pipeline_execution_policy');
  });

  afterEach(() => {
    window.gon = {};
  });

  beforeEach(() => {
    createWrapper();
  });

  describe('initial state', () => {
    it('should render initial state', () => {
      expect(findActionSection().exists()).toBe(true);
      expect(findYamlPreview(wrapper).text()).toBe(mockPipelineExecutionActionManifest.trim());
    });
  });

  describe('Project CI', () => {
    it('should select strategy to override project CI', async () => {
      const verifyRuleMode = () => {
        expect(findActionSection().exists()).toBe(true);
      };

      await findCodeBlockFilePath().vm.$emit('select-strategy', OVERRIDE);

      await verify({
        manifest: mockPipelineExecutionOverrideActionManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });
});
