import { shallowMount } from '@vue/test-utils';
import PagesDeployments from 'ee/usage_quotas/pages/components/app.vue';
import PagesDeploymentsStats from 'ee/usage_quotas/pages/components/stats.vue';
import ProjectList from 'ee/usage_quotas/pages/components/project_list.vue';

describe('PagesDeployments', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(PagesDeployments);
  });

  it('renders the component', () => {
    expect(wrapper.exists()).toBe(true);
  });

  it('passes the heading to the stats component', () => {
    const statsComponent = wrapper.findComponent(PagesDeploymentsStats);
    expect(statsComponent.props('title')).toBe('Parallel deployments');
  });

  it('renders the PagesDeploymentStats component', () => {
    const statsComponent = wrapper.findComponent(PagesDeploymentsStats);
    expect(statsComponent.exists()).toBe(true);
  });

  it('renders the ProjectList component', () => {
    const projectListComponent = wrapper.findComponent(ProjectList);
    expect(projectListComponent.exists()).toBe(true);
  });
});
