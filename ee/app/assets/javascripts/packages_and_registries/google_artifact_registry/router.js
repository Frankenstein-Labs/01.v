import Vue from 'vue';
import VueRouter from 'vue-router';
import { __ } from '~/locale';
import Details from './pages/details.vue';
import List from './pages/list.vue';

Vue.use(VueRouter);

export default function createRouter(base, breadCrumbState) {
  const router = new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        name: 'list',
        path: '/',
        component: List,
        meta: {
          nameGenerator: () => __('Google Artifact Registry'),
          root: true,
        },
      },
      {
        name: 'details',
        path: '/projects/:projectId/locations/:location/repositories/:repository/dockerImages/:image',
        component: Details,
        meta: {
          nameGenerator: () => breadCrumbState.name,
        },
      },
    ],
  });

  return router;
}
