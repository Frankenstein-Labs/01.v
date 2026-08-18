import { GlToast } from '@gitlab/ui';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import App from './components/app.vue';

export default function init() {
  const el = document.querySelector('#js-secret-detection-configuration');

  if (!el) {
    return undefined;
  }

  const { projectFullPath } = el.dataset;

  return initVueApp({
    el,
    name: 'SecretDetectionConfigurationRoot',
    apolloProvider,
    // `$toast` was previously supplied by another bundle's global `Vue.use(GlToast)`.
    // Vue 3 apps do not inherit it, so the app installs what it depends on.
    plugins: [GlToast],
    provide: {
      projectFullPath,
    },
    component: App,
  });
}
