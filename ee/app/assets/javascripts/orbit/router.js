import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import OrbitMainPage from './components/orbit_main_page.vue';
import OrbitSchemaPage from './components/orbit_schema_page.vue';
import OrbitSettingsPage from './components/orbit_settings_page.vue';

export default function createRouter(base) {
  return new VueRouter({
    mode: 'history',
    base,
    routes: [
      {
        path: '/',
        redirect: { name: 'explore' },
      },
      {
        name: 'explore',
        path: '/explore',
        component: OrbitMainPage,
        meta: { name: s__('Orbit|Explore') },
      },
      {
        name: 'schema',
        path: '/schema',
        component: OrbitSchemaPage,
        meta: { name: s__('Orbit|Schema') },
      },
      {
        name: 'configuration',
        path: '/configuration',
        component: OrbitSettingsPage,
        meta: { name: s__('Orbit|Configuration') },
      },
    ],
  });
}
