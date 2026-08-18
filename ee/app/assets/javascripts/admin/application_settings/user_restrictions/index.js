import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseRailsFormFields } from '~/lib/utils/forms';
import PrivateProfileRestrictions from './components/private_profile_restrictions.vue';

export const initPrivateProfileRestrictions = () => {
  const el = document.getElementById('js-admin-settings-user-private-profile-restrictions');

  if (!el) return false;

  const { defaultToPrivateProfiles, allowPrivateProfiles } = parseRailsFormFields(el);

  return initVueApp({
    el,
    name: 'PrivateProfileRestrictionsRoot',
    component: PrivateProfileRestrictions,
    props: {
      defaultToPrivateProfiles,
      allowPrivateProfiles,
    },
  });
};
