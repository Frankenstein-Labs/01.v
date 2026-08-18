import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ActionSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/action_section.vue';
import CodeBlockFilePath from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_file_path.vue';
import VariablesOverrideList from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/variables_override_list.vue';
import {
  DEPRECATED_INJECT,
  INJECT,
  OVERRIDE,
  SCHEDULE,
  SUFFIX_NEVER,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { mockWithoutRefPipelineExecutionObject } from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import getProjectId from 'ee/security_orchestration/graphql/queries/get_project_id.query.graphql';

jest.mock('ee/api');

describe('ActionSection', () => {
  let wrapper;
  let requestHandler;

  const project = {
    id: 'gid://gitlab/Project/29',
    fullPath: 'project-path',
    repository: {
      rootRef: 'spooky-stuff',
    },
  };

  const projectId = 29;
  const ref = 'main';
  const filePath = 'path/to/ci/file.yml';
  const fullPath = 'GitLab.org/GitLab';

  const defaultProjectId = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: projectId,
      },
    },
  });
  const defaultAction = mockWithoutRefPipelineExecutionObject.content;

  const defaultProps = {
    action: defaultAction,
    strategy: mockWithoutRefPipelineExecutionObject.pipeline_config_strategy,
  };

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getProjectId, handler]]);
  };

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ActionSection, {
      apolloProvider: createMockApolloProvider(defaultProjectId),
      propsData: {
        ...defaultProps,
        ...propsData,
      },
      provide: {
        ...provide,
      },
    });
  };

  const findCodeBlockFilePath = () => wrapper.findComponent(CodeBlockFilePath);
  const findVariablesOverrideList = () => wrapper.findComponent(VariablesOverrideList);

  describe('rendering', () => {
    it('renders code block file path component correctly', async () => {
      factory();
      await waitForPromises();
      await nextTick();

      expect(findCodeBlockFilePath().exists()).toBe(true);
      expect(findVariablesOverrideList().exists()).toBe(true);
      expect(requestHandler).toHaveBeenCalledTimes(1);

      expect(findCodeBlockFilePath().props()).toEqual(
        expect.objectContaining({
          filePath: '.pipeline-execution.yml',
          strategy: INJECT,
          selectedRef: '',
          selectedProject: { fullPath, id: 29 },
          doesFileExist: true,
        }),
      );
    });

    it('should render linked file mode when project fullPath exist', async () => {
      factory({ propsData: { action: { include: [{ project: fullPath }] } } });
      await waitForPromises();
      expect(requestHandler).toHaveBeenCalledTimes(1);
      expect(findCodeBlockFilePath().props('selectedProject')).toEqual({
        id: 29,
        fullPath,
      });
    });

    it('should render linked file mode when ref is selected', () => {
      factory({ propsData: { action: { include: [{ ref: 'ref' }] } } });

      expect(requestHandler).not.toHaveBeenCalled();
      expect(findCodeBlockFilePath().props('selectedProject')).toEqual(null);
      expect(findCodeBlockFilePath().props('selectedRef')).toBe('ref');
    });
  });

  describe('changing linked file parameters', () => {
    beforeEach(() => {
      factory();
    });

    it('selects ref', () => {
      findCodeBlockFilePath().vm.$emit('select-ref', ref);
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: [{ ...defaultAction.include[0], ref }] }],
      ]);
    });

    it('updates file path', () => {
      findCodeBlockFilePath().vm.$emit('update-file-path', filePath);
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: [{ ...defaultAction.include[0], file: filePath }] }],
      ]);
    });

    it('updates suffix strategy', () => {
      findCodeBlockFilePath().vm.$emit('update-suffix', SUFFIX_NEVER);
      expect(wrapper.emitted('changed')).toEqual([['suffix', SUFFIX_NEVER]]);
    });

    it('updates project', async () => {
      findCodeBlockFilePath().vm.$emit('select-project', project);
      await nextTick();
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: [{ ...defaultAction.include[0], project: project.fullPath }] }],
      ]);
    });

    it.each([OVERRIDE, DEPRECATED_INJECT, INJECT])(
      'updates strategy when the value is %o',
      async ({ strategy }) => {
        await findCodeBlockFilePath().vm.$emit('select-strategy', strategy);
        expect(wrapper.emitted('update-strategy')).toEqual([[strategy]]);
      },
    );

    it('clears project on deselect', async () => {
      findCodeBlockFilePath().vm.$emit('select-project', undefined);
      await nextTick();
      expect(wrapper.emitted('changed')).toEqual([
        ['content', { include: [{ file: defaultAction.include[0].file }] }],
      ]);
    });
  });

  describe('file validation', () => {
    describe('updating validation status', () => {
      it('updates a failed validation to a successful one', async () => {
        factory({ propsData: { doesFileExist: false } });
        await waitForPromises();
        expect(requestHandler).toHaveBeenCalledTimes(1);
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(false);
        await wrapper.setProps({ doesFileExist: true });
        expect(findCodeBlockFilePath().props('doesFileExist')).toBe(true);
      });

      it('removes file path if removed by user', () => {
        const { file, ...actionWithoutFile } = defaultAction.include[0];
        factory();
        findCodeBlockFilePath().vm.$emit('update-file-path', '');
        expect(wrapper.emitted('changed')).toEqual([['content', { include: [actionWithoutFile] }]]);
      });
    });
  });

  describe('suffix rendering', () => {
    it('renders correct suffix strategy', () => {
      factory({ propsData: { suffix: SUFFIX_NEVER } });

      expect(findCodeBlockFilePath().props('suffix')).toBe(SUFFIX_NEVER);
    });
  });

  describe('variable override', () => {
    const variablesOverride = { allowed: true, exceptions: ['test'] };

    it('renders override list option', () => {
      factory();

      expect(findVariablesOverrideList().exists()).toBe(true);
    });

    it('renders existing override variables options', () => {
      factory({
        propsData: { variablesOverride },
      });

      expect(findVariablesOverrideList().props('variablesOverride')).toEqual(variablesOverride);
    });

    it('emits variables override change', async () => {
      factory();
      await findVariablesOverrideList().vm.$emit('select', variablesOverride);

      expect(wrapper.emitted('changed')).toEqual([['variables_override', variablesOverride]]);
    });
  });

  describe('scheduled policy', () => {
    it('does not render variables override', () => {
      factory({
        propsData: { strategy: SCHEDULE },
      });

      expect(findVariablesOverrideList().exists()).toBe(false);
    });
  });
});
