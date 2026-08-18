import Vue from 'vue';
import VueRouter from 'vue-router';
import { joinPaths } from '~/lib/utils/url_utility';
import BaseTab from 'ee/on_demand_scans/components/tabs/base_tab.vue';

Vue.use(VueRouter);

export const createRouter = (base) =>
  new VueRouter({
    mode: 'hash',
    base: joinPaths(gon.relative_url_root || '', base),
    routes: [
      {
        path: '/:tabId',
        name: 'tab',
        component: BaseTab,
      },
    ],
  });
