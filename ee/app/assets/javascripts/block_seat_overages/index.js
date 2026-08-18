import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import MinimalAccessProvisioningAlert from './components/minimal_access_provisioning_alert.vue';

export const initMinimalAccessProvisioningAlert = () => {
  const el = document.querySelector('#js-minimal-access-provisioning-alert');

  if (!el) return false;

  const {
    dismissPath,
    affectedUsersCount,
    purchaseSeatsLink,
    learnMoreLink,
    restrictedAccessLink,
  } = el.dataset;

  return initVueApp({
    el,
    name: 'MinimalAccessProvisioningAlertRoot',
    component: MinimalAccessProvisioningAlert,
    props: {
      dismissPath,
      affectedUsersCount: parseInt(affectedUsersCount, 10),
      purchaseSeatsLink,
      learnMoreLink,
      restrictedAccessLink,
    },
  });
};
