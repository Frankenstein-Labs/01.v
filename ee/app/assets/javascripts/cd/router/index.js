import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import NestedRouteApp from '~/vue_shared/spa/components/router_view.vue';
import ApplicationsIndex from '../components/applications_index.vue';
import ApplicationsShow from '../components/applications_show.vue';
import EnvironmentsIndex from '../components/environments_index.vue';
import EnvironmentsShow from '../components/environments_show.vue';
import ServiceSidePanel from '../components/service_side_panel.vue';
import ReleaseSidePanel from '../components/release_side_panel.vue';
import NewReleasePanel from '../components/new_release_panel.vue';
import FlowEditor from '../components/flow_editor.vue';

Vue.use(VueRouter);

export const routes = [
  {
    component: NestedRouteApp,
    path: '/applications',
    meta: {
      text: s__('ContinuousDeployment|Applications'),
    },
    children: [
      {
        name: 'applications_index_route',
        path: '',
        component: ApplicationsIndex,
        meta: {
          title: s__('ContinuousDeployment|Applications'),
        },
      },
      {
        path: ':id(\\d+)',
        component: NestedRouteApp,
        meta: {
          useId: true,
          defaultRoute: 'applications_show_route',
        },
        children: [
          {
            name: 'applications_show_route',
            path: '',
            component: ApplicationsShow,
            props: (route) => ({ id: route.params.id }),
            children: [
              {
                name: 'service_detail_route',
                path: 'services/:serviceId(\\d+)',
                component: ServiceSidePanel,
                props: (route) => ({ serviceId: route.params.serviceId }),
              },
              {
                name: 'release_new_route',
                path: 'releases/new',
                component: NewReleasePanel,
                props: (route) => ({ applicationId: route.params.id }),
              },
              {
                name: 'release_detail_route',
                path: 'releases/:releaseId(\\d+)',
                component: ReleaseSidePanel,
                props: (route) => ({ releaseId: route.params.releaseId }),
              },
            ],
          },
          {
            name: 'flow_editor_route',
            path: 'flow',
            component: FlowEditor,
            props: (route) => ({ id: route.params.id }),
            meta: {
              text: s__('ContinuousDeployment|Flow editor'),
            },
          },
        ],
      },
    ],
  },
  {
    component: NestedRouteApp,
    path: '/environments',
    meta: {
      text: s__('ContinuousDeployment|Environments'),
    },
    children: [
      {
        name: 'environments_index_route',
        path: '',
        component: EnvironmentsIndex,
        meta: {
          title: s__('ContinuousDeployment|Environments'),
        },
      },
      {
        name: 'environments_show_route',
        path: ':id(\\d+)',
        component: EnvironmentsShow,
        meta: {
          useId: true,
        },
      },
    ],
  },
  { path: '*', redirect: '/applications' },
];

export const createRouter = (base) => {
  const baseTitle = document.title;

  const router = new VueRouter({
    base,
    mode: 'history',
    routes,
  });

  router.afterEach((to) => {
    const isItemPage = to.matched.some((route) => route.meta?.useId);

    if (!isItemPage && to.meta.title) {
      document.title = `${to.meta.title} · ${baseTitle}`;
    }
  });

  return router;
};
