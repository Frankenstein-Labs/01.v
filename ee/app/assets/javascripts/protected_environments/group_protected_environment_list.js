import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import GroupProtectedEnvironment from './group_protected_environment.vue';

export const initGroupProtectedEnvironmentList = () => {
  const envs = document.querySelectorAll('.js-group-protected-environment');

  envs.forEach((el) => {
    const { accessLevels: levels, project, environment } = el.dataset;

    try {
      const accessLevels = JSON.parse(levels);
      return initVueApp({
        el,
        name: 'GroupProtectedEnvironmentRoot',
        component: GroupProtectedEnvironment,
        props: {
          accessLevels,
          environment,
          project,
        },
      });
    } catch (e) {
      Sentry.captureException(e);
    }

    return null;
  });
};
