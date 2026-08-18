import VirtualRegistriesApp from 'ee/packages_and_registries/virtual_registries/pages/index.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initSimpleApp('#js-vue-virtual-registries', VirtualRegistriesApp, {
  withApolloProvider: true,
  name: 'VirtualRegistriesRoot',
});
