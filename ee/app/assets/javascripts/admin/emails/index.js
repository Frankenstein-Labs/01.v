import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import AdminEmailsForm from './components/admin_emails_form.vue';

export const initAdminEmailsForm = () => {
  const el = document.getElementById('js-admin-emails-form');

  if (!el) {
    return null;
  }

  const { adminEmailPath, adminEmailsAreCurrentlyRateLimited } = el.dataset;

  return initVueApp({
    el,
    name: 'AdminEmailsFormRoot',
    provide: {
      adminEmailPath,
      adminEmailsAreCurrentlyRateLimited,
    },
    component: AdminEmailsForm,
  });
};
