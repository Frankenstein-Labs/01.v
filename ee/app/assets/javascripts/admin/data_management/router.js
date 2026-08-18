import VueRouter from 'vue-router';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';

export function createRouter(basePath) {
  return new VueRouter({
    routes: [
      {
        name: 'root',
        path: '/:modelName?',
        component: AdminDataManagementApp,
      },
    ],
    mode: 'history',
    base: basePath,
  });
}
