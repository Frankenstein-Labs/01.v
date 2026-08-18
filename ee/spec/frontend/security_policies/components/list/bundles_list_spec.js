import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlSearchBoxByType, GlTableLite } from '@gitlab/ui';
import BundlesList from 'ee/security_policies/components/list/bundles_list.vue';

describe('BundlesList', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(BundlesList);
  };

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findSearch = () => wrapper.findComponent(GlSearchBoxByType);

  it('renders the bundles table', () => {
    createComponent();

    expect(findTable().exists()).toBe(true);
  });

  it('renders all 5 mock bundles by default', () => {
    createComponent();

    expect(findTable().props('items')).toHaveLength(5);
  });

  it('renders search box', () => {
    createComponent();

    expect(findSearch().exists()).toBe(true);
  });

  it('renders 4 summary stat tiles', () => {
    createComponent();

    expect(wrapper.text()).toContain('Applied bundles');
    expect(wrapper.text()).toContain('Policies under management');
    expect(wrapper.text()).toContain('Frameworks covered');
    expect(wrapper.text()).toContain('Needs attention');
  });

  it('shows total policy count across all bundles', () => {
    createComponent();

    expect(wrapper.vm.totalPolicies).toBeGreaterThan(0);
  });

  it('filters bundles by search query', async () => {
    createComponent();

    wrapper.vm.searchQuery = 'Dependency Firewall';
    await nextTick();

    expect(findTable().props('items')).toHaveLength(1);
    expect(findTable().props('items')[0].name).toContain('Dependency Firewall');
  });

  it('shows all bundles when search is cleared', async () => {
    createComponent();

    wrapper.vm.searchQuery = 'AI';
    await nextTick();
    wrapper.vm.searchQuery = '';
    await nextTick();

    expect(findTable().props('items')).toHaveLength(5);
  });

  it('all bundles have GitLab as source', () => {
    createComponent();

    expect(
      findTable()
        .props('items')
        .every((b) => b.source === 'GitLab'),
    ).toBe(true);
  });

  it('all bundles have active status', () => {
    createComponent();

    expect(
      findTable()
        .props('items')
        .every((b) => b.status === 'active'),
    ).toBe(true);
  });
});
