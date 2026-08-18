import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import BlobHeader from 'ee/blob/components/blob_header.vue';
import CeBlobHeader from '~/blob/components/blob_header.vue';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import duoWorkflowActionQuery from 'ee/repository/queries/duo_workflow_action.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/graphql_shared/utils', () => ({
  getIdFromGraphQLId: jest.fn().mockReturnValue(123),
}));

jest.mock('~/sentry/sentry_browser_wrapper', () => ({
  captureException: jest.fn(),
}));

Vue.use(VueApollo);

describe('EE Blob Header', () => {
  let wrapper;

  const testBlob = {
    path: 'test/Jenkinsfile',
    rawPath: '/raw/test/Jenkinsfile',
    externalStorageUrl: null,
    fileType: 'jenkinsfile',
  };
  const testProps = {
    blob: testBlob,
    projectPath: 'group/project',
    currentRef: 'main',
  };

  let mockApolloProvider;

  const createComponent = (
    props = {},
    duoWorkflowData = null,
    apolloProvider = null,
    glFeatures = {},
    // eslint-disable-next-line max-params
  ) => {
    wrapper = shallowMount(BlobHeader, {
      propsData: {
        ...testProps,
        ...props,
      },
      apolloProvider,
      provide: {
        glFeatures,
      },
      data() {
        return { duoWorkflowData };
      },
    });
  };

  afterEach(() => {
    mockApolloProvider = null;
  });

  const findCeBlobHeader = () => wrapper.findComponent(CeBlobHeader);
  const findDuoWorkflowAction = () => wrapper.findComponent(DuoWorkflowAction);

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes all props to CE component', () => {
      // Exclude props from the CE props comparison
      const { projectPath, currentRef, ...propsToCheck } = testProps;
      expect(findCeBlobHeader().props()).toMatchObject(propsToCheck);
    });

    it('does not render DuoWorkflowAction by default', () => {
      expect(findDuoWorkflowAction().exists()).toBe(false);
    });
  });

  describe('with GraphQL data', () => {
    const createMockData = (showAction = true) => ({
      showDuoWorkflowAction: showAction,
    });

    it('renders DuoWorkflowAction with legacy convert_to_gl_ci/v1 when feature flag is off', async () => {
      createComponent({}, createMockData(true));

      await nextTick();

      const duoWorkflowAction = findDuoWorkflowAction();
      expect(duoWorkflowAction.props()).toMatchObject({
        projectPath: 'group/project',
        hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
        goal: 'test/Jenkinsfile',
        workflowDefinition: 'convert_to_gl_ci/v1',
        agentPrivileges: [1, 2, 3, 5],
        sourceBranch: 'main',
        additionalContext: [
          {
            Category: 'agent_user_environment',
            Content: JSON.stringify({
              source_branch: 'main',
            }),
            Metadata: '{}',
          },
        ],
      });
      expect(duoWorkflowAction.text()).toBe('Convert to GitLab CI/CD');
    });

    it('passes the correct source prop', async () => {
      createComponent({}, createMockData(true));

      await nextTick();

      expect(findDuoWorkflowAction().props('source')).toBe('convert_platform_ci_pipeline');
    });

    it('renders DuoWorkflowAction with developer/v1 and a built conversion goal when feature flag is on', async () => {
      createComponent({}, createMockData(true), null, { duoConvertCiUseDeveloperFlow: true });

      await nextTick();

      const duoWorkflowAction = findDuoWorkflowAction();
      const props = duoWorkflowAction.props();

      expect(props.workflowDefinition).toBe('developer/v1');

      expect(props.goal).toContain(
        'Convert the Jenkins CI pipeline configuration at `test/Jenkinsfile`',
      );
      expect(props.goal).toContain('glab ci lint');
      expect(props.goal).toContain('`include:`');
      expect(props.goal).toContain('Convert Jenkins CI to GitLab CI');

      expect(props.goal).toContain('1. ');
      expect(props.goal).toContain('2. ');
      expect(props.goal).toContain('3. ');
      expect(props.goal).toContain('4. ');

      expect(props).toMatchObject({
        hoverMessage: 'Convert Jenkins to GitLab CI/CD using Duo',
        agentPrivileges: [1, 2, 3, 5],
        sourceBranch: 'main',
        additionalContext: [
          {
            Category: 'agent_user_environment',
            Content: JSON.stringify({
              source_branch: 'main',
            }),
            Metadata: '{}',
          },
        ],
      });
    });

    it('does not render DuoWorkflowAction when showDuoWorkflowAction is false', () => {
      createComponent({}, createMockData(false));

      expect(findDuoWorkflowAction().exists()).toBe(false);
    });

    it('does not render DuoWorkflowAction with incomplete data', () => {
      createComponent({}, {});
      expect(findDuoWorkflowAction().exists()).toBe(false);
    });

    it('should capture exceptions in Sentry', async () => {
      const error = new Error('GraphQL error');

      mockApolloProvider = createMockApollo([
        [duoWorkflowActionQuery, jest.fn().mockRejectedValue(error)],
      ]);

      createComponent({}, null, mockApolloProvider);

      await waitForPromises();

      expect(captureException).toHaveBeenCalledWith(error, {
        tags: {
          vue_component: 'BlobHeader',
        },
      });
    });
  });

  describe('slot passing', () => {
    it('passes slots to CE component', () => {
      const prependContent = 'Prepend content';
      const actionsContent = 'Actions content';

      wrapper = shallowMount(BlobHeader, {
        propsData: testProps,
        slots: {
          prepend: `<div>${prependContent}</div>`,
          actions: `<div>${actionsContent}</div>`,
        },
      });

      expect(wrapper.html()).toContain(prependContent);
      expect(wrapper.html()).toContain(actionsContent);
    });
  });
});
