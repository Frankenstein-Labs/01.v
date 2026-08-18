import Vue from 'vue';
import VueRouter from 'vue-router';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import AdminDataManagementApp from 'ee/admin/data_management/components/app.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { formatListboxItems } from 'ee/admin/data_management/filters';
import {
  FILTERED_SEARCH_TOKEN_OPTIONS,
  SORT_OPTIONS_ARRAY,
} from 'ee/admin/data_management/constants';
import { createRouter } from 'ee/admin/data_management/router';

Vue.use(VueRouter);

export const initAdminDataManagementApp = () => {
  const el = document.getElementById('js-admin-data-management');

  if (!el) return null;

  const { initialModelTypeName, modelTypes, basePath } = el.dataset;

  const parsedModelTypes = convertObjectPropsToCamelCase(JSON.parse(modelTypes), { deep: true });

  return initVueApp({
    el,
    name: 'AdminDataManagementAppRoot',
    router: createRouter(basePath),
    provide: {
      basePath,
      listboxItems: formatListboxItems(parsedModelTypes),
      filteredSearchTokens: FILTERED_SEARCH_TOKEN_OPTIONS,
      sortOptions: SORT_OPTIONS_ARRAY,
    },
    component: AdminDataManagementApp,
    props: {
      initialModelTypeName,
      modelTypes: parsedModelTypes,
    },
  });
};
