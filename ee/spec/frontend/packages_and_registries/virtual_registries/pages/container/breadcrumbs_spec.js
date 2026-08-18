import { shallowMount } from '@vue/test-utils';
import SpaBreadcrumbs from '~/vue_shared/spa/components/spa_breadcrumbs.vue';
import ContainerVirtualRegistriesBreadcrumbs from 'ee/packages_and_registries/virtual_registries/pages/container/breadcrumbs.vue';

describe('ContainerVirtualRegistriesBreadcrumbs', () => {
  let wrapper;

  const defaultProps = {
    staticBreadcrumbs: [
      { text: 'Home', href: '/' },
      { text: 'Registries', href: '/registries' },
    ],
  };

  const findSpaBreadcrumbs = () => wrapper.findComponent(SpaBreadcrumbs);

  const createComponent = () => {
    wrapper = shallowMount(ContainerVirtualRegistriesBreadcrumbs, {
      propsData: defaultProps,
    });
  };

  it('renders spa breadcrumbs component', () => {
    createComponent();

    expect(findSpaBreadcrumbs().props('allStaticBreadcrumbs')).toEqual(
      defaultProps.staticBreadcrumbs,
    );
  });
});
