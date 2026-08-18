import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import QrtlyReconciliationAlert from 'ee/billings/qrtly_reconciliation/components/qrtly_reconciliation_alert.vue';

export const initQrtlyReconciliationAlert = (selector = '#js-qrtly-reconciliation-alert') => {
  const el = document.querySelector(selector);

  if (!el) {
    return false;
  }

  const { reconciliationDate, cookieKey, usesNamespacePlan } = el.dataset;

  return initVueApp({
    el,
    name: 'QrtlyReconciliationAlertRoot',
    component: QrtlyReconciliationAlert,
    props: {
      date: new Date(reconciliationDate),
      cookieKey,
      usesNamespacePlan,
    },
  });
};
