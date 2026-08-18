import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import FilterDropdowns from 'ee/analytics/productivity_analytics/components/filter_dropdowns.vue';
import { getStoreConfig } from 'ee/analytics/productivity_analytics/store';
import ProjectsDropdownFilter from '~/analytics/shared/components/projects_dropdown_filter.vue';
import resetStore from '../helpers';

Vue.use(Vuex);

describe('FilterDropdowns component', () => {
  let wrapper;
  let mockStore;

  const filtersActionSpies = {
    setProjectPath: jest.fn(),
  };

  const groupId = 1;
  const groupNamespace = 'gitlab-org';
  const projectPath = 'gitlab-org/gitlab-test';
  const projectId = 'gid://gitlab/Project/1';

  const createWrapper = (propsData = {}) => {
    const {
      modules: { filters, ...modules },
      ...storeConfig
    } = getStoreConfig();
    mockStore = new Vuex.Store({
      ...storeConfig,
      modules: {
        filters: {
          ...filters,
          state: {
            ...filters.state,
            groupNamespace,
          },
          actions: {
            ...filters.actions,
            ...filtersActionSpies,
          },
        },
        ...modules,
      },
    });

    wrapper = shallowMount(FilterDropdowns, {
      store: mockStore,
      propsData,
    });
  };

  const findProjectsDropdownFilter = () => wrapper.findComponent(ProjectsDropdownFilter);

  afterEach(() => {
    resetStore(mockStore);
  });

  describe('template', () => {
    describe('without a group selected', () => {
      beforeEach(() => {
        createWrapper({ group: { id: null } });
      });

      it('does not render the projects dropdown', () => {
        expect(findProjectsDropdownFilter().exists()).toBe(false);
      });
    });

    describe('with a group selected', () => {
      beforeEach(() => {
        createWrapper({ group: { id: groupId } });
      });

      it('renders the projects dropdown', () => {
        expect(findProjectsDropdownFilter().exists()).toBe(true);
      });
    });
  });

  describe('events', () => {
    describe('with group selected', () => {
      beforeEach(() => {
        createWrapper({ group: { id: groupId } });
      });

      describe('when project is selected', () => {
        beforeEach(() => {
          const selectedProject = [{ id: projectId, fullPath: `${projectPath}` }];
          findProjectsDropdownFilter().vm.$emit('selected', selectedProject);
        });

        it('invokes setProjectPath action', () => {
          const { calls } = filtersActionSpies.setProjectPath.mock;
          expect(calls[calls.length - 1][1]).toBe(projectPath);
        });

        it('emits the "project-selected" event', () => {
          expect(wrapper.emitted()['project-selected'][0][0]).toEqual({
            groupNamespace,
            groupId,
            projectNamespace: projectPath,
            projectId,
          });
        });
      });

      describe('when project is deselected', () => {
        beforeEach(() => {
          findProjectsDropdownFilter().vm.$emit('selected', []);
        });

        it('invokes setProjectPath action with null', () => {
          const { calls } = filtersActionSpies.setProjectPath.mock;
          expect(calls[calls.length - 1][1]).toBe(null);
        });

        it('emits the "project-selected" event', () => {
          expect(wrapper.emitted()['project-selected'][0][0]).toEqual({
            groupNamespace,
            groupId,
            projectNamespace: null,
            projectId: null,
          });
        });
      });
    });
  });
});
