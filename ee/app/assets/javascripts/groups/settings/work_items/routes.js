import { getSettingsConfig } from 'ee/work_items/constants';
import ChangeLifecycleSteps from './custom_status/change_lifecycle/change_lifecycle_steps.vue';
import WorkItemSettingsHome from './work_item_settings_home.vue';

const getConfig = (isRootGroup, isSaas) => {
  if (isRootGroup && isSaas) {
    return getSettingsConfig('root');
  }
  if (isRootGroup && !isSaas) {
    return {
      ...getSettingsConfig('root'),
      showTypeCustomizationToggle: false,
      workItemTypeSettingsPermissions: ['enable', 'disable'],
    };
  }
  return {
    ...getSettingsConfig('subgroup'),
    showWorkItemTypesSettings: false,
    showEnabledWorkItemTypesSettings: true,
    showCustomFieldsSettings: false,
    showCustomStatusSettings: false,
  };
};

export const getRoutes = (fullPath, isRootGroup, isSaas) => {
  return [
    {
      path: '/',
      name: 'workItemSettingsHome',
      component: WorkItemSettingsHome,
      props: {
        fullPath,
        config: getConfig(isRootGroup, isSaas),
      },
    },
    {
      path: `/lifecycle/:workItemType`,
      name: 'changeLifecycle',
      component: ChangeLifecycleSteps,
      props: { fullPath },
    },
  ];
};
