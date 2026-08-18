import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import ProjectToken from 'ee/usage_quotas/code_suggestions/tokens/project_token.vue';
import { mockNoProjects, mockProjects } from 'ee_jest/usage_quotas/code_suggestions/mock_data';
import createMockApollo from 'helpers/mock_apollo_helper';
import getNamespaceProjects from 'ee/graphql_shared/queries/get_namespace_projects.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

Vue.use(VueApollo);

jest.mock('~/alert');

describe('ProjectToken', () => {
  let wrapper;

  const defaultConfig = { fullPath: 'group-path' };
  const error = new Error('Something went wrong');
  const search = 'project';
  const value = { data: 'gid://gitlab/Project/20', operator: '=' };

  const loadingHandler = jest.fn().mockResolvedValue(new Promise(() => {}));
  const noProjectsHandler = jest.fn().mockResolvedValue(mockNoProjects);
  const projectsHandler = jest.fn().mockResolvedValue(mockProjects);
  const errorProjectsHandler = jest.fn().mockRejectedValue(error);

  const createMockApolloProvider = (handler) => createMockApollo([[getNamespaceProjects, handler]]);

  const findBaseToken = () => wrapper.findComponent(BaseToken);
  const triggerFetchProjects = (searchTerm = '') => {
    findBaseToken().vm.$emit('fetch-suggestions', searchTerm);
    return waitForPromises();
  };

  const createComponent = ({ props = {}, handler = noProjectsHandler } = {}) => {
    wrapper = shallowMount(ProjectToken, {
      propsData: {
        active: false,
        config: {
          ...defaultConfig,
        },
        value,
        ...props,
      },
      apolloProvider: createMockApolloProvider(handler),
      stubs: {},
      provide: {
        portalName: 'fake target',
        alignSuggestions: function fakeAlignSuggestions() {},
        suggestionsListClass: () => 'custom-class',
        termsAsTokens: () => false,
      },
    });
  };

  describe('when rendering', () => {
    it('passes the correct props', () => {
      createComponent();

      expect(findBaseToken().props()).toMatchObject({ config: defaultConfig, value });
    });
  });

  describe('when fetching the projects', () => {
    beforeEach(async () => {
      createComponent({ handler: loadingHandler });
      await triggerFetchProjects(search);
      return nextTick();
    });

    it('sets loading state', () => {
      expect(findBaseToken().props('suggestionsLoading')).toBe(true);
    });

    describe('when the request is successful', () => {
      describe('with no projects', () => {
        beforeEach(() => {
          createComponent({ handler: noProjectsHandler });
          return triggerFetchProjects(search);
        });

        it('fetches the projects', () => {
          expect(noProjectsHandler).toHaveBeenNthCalledWith(1, {
            fullPath: defaultConfig.fullPath,
            search,
          });
        });

        it('passes the correct props', () => {
          expect(findBaseToken().props()).toMatchObject({ config: defaultConfig, suggestions: [] });
        });
      });

      describe('with projects', () => {
        const {
          data: {
            group: {
              projects: { nodes },
            },
          },
        } = mockProjects;

        beforeEach(() => {
          createComponent({ handler: projectsHandler });
          return triggerFetchProjects();
        });

        it('fetches the projects', () => {
          expect(projectsHandler).toHaveBeenNthCalledWith(1, {
            fullPath: defaultConfig.fullPath,
            search: '',
          });
        });

        it('passes the correct props', () => {
          expect(findBaseToken().props('suggestions')).toEqual(nodes);
        });

        it('finds the correct value from the activeToken', () => {
          const [project] = nodes;

          expect(findBaseToken().props('getActiveTokenValue')(nodes, project.id)).toBe(project);
        });
      });
    });

    describe('when the request fails', () => {
      beforeEach(() => {
        createComponent({ handler: errorProjectsHandler });
        return triggerFetchProjects();
      });

      it('calls `createAlert`', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'There was a problem fetching projects.',
        });
      });

      it('sets `loading` to false when request completes', () => {
        expect(findBaseToken().props('suggestionsLoading')).toBe(false);
      });
    });
  });
});
