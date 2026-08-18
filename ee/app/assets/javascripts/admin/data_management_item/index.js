import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import AdminDataManagementItemApp from 'ee/admin/data_management_item/components/app.vue';

export const initAdminDataManagementItem = () => {
  const el = document.getElementById('js-admin-data-management-item');

  if (!el) return null;

  const { modelId } = el.dataset;

  const modelTypeData = convertObjectPropsToCamelCase(JSON.parse(el.dataset.modelTypeData));

  return initVueApp({
    el,
    name: 'AdminDataManagementItemAppRoot',
    component: AdminDataManagementItemApp,
    props: {
      modelTypeData,
      modelId,
    },
  });
};
