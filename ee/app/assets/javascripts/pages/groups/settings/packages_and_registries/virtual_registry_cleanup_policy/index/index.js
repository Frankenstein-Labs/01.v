import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import VirtualRegistriesCleanupPolicyForm from 'ee/packages_and_registries/settings/group/components/virtual_registries_cleanup_policy_form.vue';

initSimpleApp('#js-virtual-registries-cleanup-policy-form', VirtualRegistriesCleanupPolicyForm, {
  withApolloProvider: true,
  name: 'VirtualRegistriesCleanupPolicyForm',
});
