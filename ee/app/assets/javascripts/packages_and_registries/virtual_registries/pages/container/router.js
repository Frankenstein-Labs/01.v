import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import SpaRouterView from '~/vue_shared/spa/components/router_view.vue';
import UpstreamShow from 'ee/packages_and_registries/virtual_registries/pages/common/upstream/show.vue';
import RegistriesNewPage from '../common/registry/new.vue';
import RegistriesEdit from '../common/registry/edit.vue';
import UpstreamsEditPage from '../common/upstream/edit.vue';
import RegistriesShowPage from '../common/registry/show.vue';
import RegistriesAndUpstreams from './registries_and_upstreams.vue';
import {
  CONTAINER_REGISTRIES_INDEX,
  CONTAINER_REGISTRIES_EDIT,
  CONTAINER_REGISTRIES_SHOW,
  CONTAINER_UPSTREAMS_INDEX,
  CONTAINER_UPSTREAMS_EDIT,
  CONTAINER_UPSTREAMS_SHOW,
} from './routes';
import { updateDocumentTitle } from './utils';

Vue.use(VueRouter);

export default function createRouter(base) {
  const router = new VueRouter({
    base,
    mode: 'history',
    routes: [
      { path: '/', redirect: { name: CONTAINER_REGISTRIES_INDEX } },
      {
        path: '/',
        component: SpaRouterView,
        children: [
          {
            path: 'registries',
            component: SpaRouterView,
            meta: {
              text: s__('VirtualRegistries|Container registries'),
              defaultRoute: CONTAINER_REGISTRIES_INDEX,
            },
            children: [
              {
                name: CONTAINER_REGISTRIES_INDEX,
                path: '',
                component: RegistriesAndUpstreams,
              },
              {
                name: 'REGISTRY_NEW',
                path: 'new',
                component: RegistriesNewPage,
                meta: {
                  text: s__('VirtualRegistries|New registry'),
                },
                beforeEnter(to, from, next) {
                  if (window.gon?.abilities?.createVirtualRegistry) {
                    next();
                  } else {
                    next({
                      name: CONTAINER_REGISTRIES_INDEX,
                    });
                  }
                },
              },
              {
                path: ':id(\\d+)',
                component: SpaRouterView,
                meta: {
                  useId: true,
                  defaultRoute: CONTAINER_REGISTRIES_SHOW,
                },
                children: [
                  {
                    name: CONTAINER_REGISTRIES_SHOW,
                    path: '',
                    component: RegistriesShowPage,
                    props: true,
                  },
                  {
                    name: CONTAINER_REGISTRIES_EDIT,
                    path: 'edit',
                    component: RegistriesEdit,
                    props: true,
                    meta: {
                      text: s__('VirtualRegistries|Edit registry'),
                    },
                    beforeEnter(to, from, next) {
                      if (window.gon?.abilities?.updateVirtualRegistry) {
                        next();
                      } else {
                        next({
                          name: CONTAINER_REGISTRIES_INDEX,
                        });
                      }
                    },
                  },
                ],
              },
            ],
          },
          {
            path: 'upstreams',
            component: SpaRouterView,
            meta: {
              text: s__('VirtualRegistries|Container upstreams'),
              defaultRoute: CONTAINER_UPSTREAMS_INDEX,
            },
            children: [
              {
                name: CONTAINER_UPSTREAMS_INDEX,
                path: '',
                component: RegistriesAndUpstreams,
              },
              {
                path: ':id(\\d+)',
                component: SpaRouterView,
                meta: {
                  useId: true,
                  defaultRoute: CONTAINER_UPSTREAMS_SHOW,
                },
                children: [
                  {
                    name: CONTAINER_UPSTREAMS_SHOW,
                    path: '',
                    component: UpstreamShow,
                    props: true,
                  },
                  {
                    name: CONTAINER_UPSTREAMS_EDIT,
                    path: 'edit',
                    component: UpstreamsEditPage,
                    props: true,
                    meta: {
                      text: s__('VirtualRegistries|Edit upstream'),
                    },
                    beforeEnter(to, from, next) {
                      if (window.gon?.abilities?.updateVirtualRegistry) {
                        next();
                      } else {
                        next({
                          name: CONTAINER_UPSTREAMS_INDEX,
                        });
                      }
                    },
                  },
                ],
              },
            ],
          },
        ],
      },
      { path: '*', redirect: { name: CONTAINER_REGISTRIES_INDEX } },
    ],
  });

  router.afterEach(updateDocumentTitle());

  return router;
}
