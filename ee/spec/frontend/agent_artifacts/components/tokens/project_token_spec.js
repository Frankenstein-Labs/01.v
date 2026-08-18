import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ProjectToken from 'ee/agent_artifacts/components/tokens/project_token.vue';
import getAgentArtifactsProjects from 'ee/agent_artifacts/graphql/queries/get_agent_artifacts_projects.query.graphql';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/alert');

const mockProjectsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      projects: {
        nodes: [
          {
            id: 'gid://gitlab/Project/1',
            name: 'Security Scanner',
            fullPath: 'gitlab-org/security-scanner',
          },
          {
            id: 'gid://gitlab/Project/2',
            name: 'Frontend App',
            fullPath: 'gitlab-org/frontend-app',
          },
        ],
      },
    },
  },
};

describe('ProjectToken', () => {
  let wrapper;
  let queryHandler;

  const createComponent = ({
    queryResponse = mockProjectsResponse,
    propsData = {},
    provide = {},
  } = {}) => {
    const apolloProvider = createMockApollo();

    if (queryResponse instanceof Error) {
      queryHandler = jest.fn().mockRejectedValue(queryResponse);
    } else {
      queryHandler = jest.fn().mockResolvedValue(queryResponse);
    }

    apolloProvider.defaultClient.setRequestHandler(getAgentArtifactsProjects, queryHandler);

    wrapper = mount(ProjectToken, {
      propsData: {
        config: {
          type: 'project',
          icon: 'project',
          title: 'Project',
          skipIdPrefix: true,
        },
        value: {},
        active: false,
        cursorPosition: 'start',
        ...propsData,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        suggestionsListClass: () => 'custom-class',
        termsAsTokens: () => false,
        groupFullPath: 'gitlab-org',
        ...provide,
      },
      apolloProvider,
      stubs: {
        Portal: true,
      },
    });
  };

  const findBaseToken = () => wrapper.findComponent(BaseToken);
  const findSuggestions = () => wrapper.findAllComponents(GlFilteredSearchSuggestion);

  describe('when component is initially rendered', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders BaseToken component', () => {
      expect(findBaseToken().exists()).toBe(true);
    });
  });

  describe('when fetching projects', () => {
    beforeEach(() => {
      createComponent({ propsData: { active: true } });
    });

    it('calls query with correct variables', async () => {
      findBaseToken().vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org',
        search: '',
      });
    });

    it('calls query with search term when provided', async () => {
      findBaseToken().vm.$emit('fetch-suggestions', 'security');
      await waitForPromises();

      expect(queryHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org',
        search: 'security',
      });
    });

    it('displays project suggestions', async () => {
      findBaseToken().vm.$emit('fetch-suggestions');
      await waitForPromises();

      const suggestions = findSuggestions();
      expect(suggestions).toHaveLength(2);
      expect(suggestions.at(0).text()).toBe('gitlab-org/security-scanner');
      expect(suggestions.at(1).text()).toBe('gitlab-org/frontend-app');
    });
  });

  describe('when fetch fails', () => {
    beforeEach(() => {
      createComponent({
        queryResponse: new Error('GraphQL error'),
        propsData: { active: true },
      });
    });

    it('shows error alert', async () => {
      findBaseToken().vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to load projects.',
      });
    });

    it('displays no suggestions on error', async () => {
      findBaseToken().vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(findSuggestions()).toHaveLength(0);
    });
  });

  describe('when group has no projects', () => {
    beforeEach(() => {
      createComponent({
        queryResponse: {
          data: {
            group: null,
          },
        },
        propsData: { active: true },
      });
    });

    it('displays no suggestions', async () => {
      findBaseToken().vm.$emit('fetch-suggestions');
      await waitForPromises();

      expect(findSuggestions()).toHaveLength(0);
    });
  });

  describe('selected token display', () => {
    beforeEach(async () => {
      createComponent({
        propsData: {
          active: false,
          value: { data: 'gitlab-org/security-scanner' },
        },
      });
      await waitForPromises();
    });

    it('displays the project fullPath when skipIdPrefix is true', () => {
      expect(wrapper.text()).toContain('gitlab-org/security-scanner');
    });
  });
});
