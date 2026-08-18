import Vue from 'vue';
import VueRouter from 'vue-router';
import store from 'ee/insights/stores';
import { joinPaths } from '~/lib/utils/url_utility';
import Insights from './components/insights.vue';

Vue.use(VueRouter);

export default function createRouter(base) {
  const router = new VueRouter({
    mode: 'hash',
    base: joinPaths(gon.relative_url_root || '', base),
    routes: [
      {
        name: 'insights',
        path: '/:tabId',
        /**
         * Vue router 4 does not support declaring routes without
         * a defined component or children. Because we are
         * not using `<router-view>` in the Insights app, this
         * still has to be declared and will have no impact on the
         * app.
         */
        component: Insights,
      },
    ],
  });

  router.beforeEach((to, from, next) => {
    const page = to.path.substr(1);

    store.dispatch('insights/setActiveTab', page);

    next();
  });

  return router;
}
