import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import createDefaultClient from '~/lib/graphql';
import RolePromotionRequestsApp from './components/app.vue';

/**
 * Mounts RolePromotionRequestsApp
 * @param {HTMLElement} [el] element to mount the app on
 */
export default (el) => {
  if (!el) {
    return null;
  }

  const data = convertObjectPropsToCamelCase(el.dataset);
  const paths = convertObjectPropsToCamelCase(JSON.parse(data.paths));

  Vue.use(VueApollo);
  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  return initVueApp({
    el,
    name: 'PromotionRequestsAppWrapper',
    provide: {
      paths,
    },
    apolloProvider,
    component: RolePromotionRequestsApp,
  });
};
