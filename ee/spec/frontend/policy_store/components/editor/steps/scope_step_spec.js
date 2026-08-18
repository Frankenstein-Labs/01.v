import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormRadioGroup, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ScopeStep from 'ee/policy_store/components/editor/steps/scope_step.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';

Vue.use(VueApollo);

describe('ScopeStep', () => {
  let wrapper;
  let requestHandler;

  const projectsResponse = (count) => ({
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        projects: {
          count,
          nodes: [
            {
              id: 'gid://gitlab/Project/1',
              name: 'webapp',
              fullPath: 'group/webapp',
              repository: { rootRef: 'main', __typename: 'Repository' },
              group: { id: 'gid://gitlab/Group/1', __typename: 'Group' },
              __typename: 'Project',
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
            __typename: 'PageInfo',
          },
          __typename: 'ProjectConnection',
        },
        __typename: 'Group',
      },
    },
  });

  const createComponent = ({ propsData = {}, count = 42 } = {}) => {
    requestHandler = jest.fn().mockResolvedValue(projectsResponse(count));
    const apolloProvider = createMockApollo([[getGroupProjects, requestHandler]]);

    wrapper = shallowMountExtended(ScopeStep, {
      apolloProvider,
      propsData,
      provide: { namespacePath: 'group/path' },
    });
  };

  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findProjectDropdowns = () => wrapper.findAllComponents(GroupProjectsDropdown);
  const findAddExclusion = () => wrapper.findComponentByTestId('add-exclusion');
  const findAffectedCount = () => wrapper.findByTestId('affected-count');
  const findViewProjects = () => wrapper.findComponentByTestId('view-projects');
  const findModal = () => wrapper.findComponent(GlModal);

  it('defaults to all projects with no project dropdown shown', () => {
    createComponent();

    expect(findRadioGroup().props('checked')).toBe('all');
    expect(findProjectDropdowns()).toHaveLength(0);
  });

  it('queries group projects in all projects mode', async () => {
    createComponent();
    await waitForPromises();

    expect(requestHandler).toHaveBeenCalledTimes(1);
  });

  it('does not query group projects in specific mode', async () => {
    createComponent({ propsData: { scope: { mode: 'specific', projects: [], exclusions: [] } } });
    await waitForPromises();

    expect(requestHandler).not.toHaveBeenCalled();
  });

  it('shows the project selector when specific projects is chosen', async () => {
    createComponent();

    await findRadioGroup().vm.$emit('change', 'specific');

    expect(findProjectDropdowns()).toHaveLength(1);
    expect(findProjectDropdowns().at(0).props('state')).toBe(true);
    expect(wrapper.emitted('update')[0][0].mode).toBe('specific');
  });

  it('reveals an exclusion selector when Add exclusion is clicked', async () => {
    createComponent();

    await findAddExclusion().vm.$emit('click');

    expect(findAddExclusion().exists()).toBe(false);
    expect(findProjectDropdowns()).toHaveLength(1);
    expect(findProjectDropdowns().at(0).props('state')).toBe(true);
  });

  it('shows the group project count as the affected count for all projects', async () => {
    createComponent({ count: 42 });
    await waitForPromises();

    expect(findAffectedCount().text()).toBe('42 projects affected');
  });

  it('emits the selected projects and exclusions when the selection changes', async () => {
    createComponent();
    await findRadioGroup().vm.$emit('change', 'specific');

    await findProjectDropdowns()
      .at(0)
      .vm.$emit('select', [{ id: 1 }, { id: 2 }]);

    expect(wrapper.emitted('update').at(-1)[0]).toEqual({
      mode: 'specific',
      projects: [{ id: 1 }, { id: 2 }],
      exclusions: [],
    });
  });

  it('seeds the affected count and project ids from an existing scope', () => {
    createComponent({
      propsData: {
        scope: { mode: 'specific', projects: [{ id: 1 }, { id: 2 }], exclusions: [] },
      },
    });

    expect(findAffectedCount().text()).toBe('2 projects affected');
    expect(findProjectDropdowns().at(0).props('selected')).toEqual([1, 2]);
  });

  it('opens the affected projects modal listing the selected projects', async () => {
    createComponent();
    await findRadioGroup().vm.$emit('change', 'specific');
    await findProjectDropdowns()
      .at(0)
      .vm.$emit('select', [{ id: 1, fullPath: 'group/webapp' }]);

    await findViewProjects().vm.$emit('click');

    expect(findModal().props('visible')).toBe(true);
    expect(findModal().text()).toContain('group/webapp');
  });
});
