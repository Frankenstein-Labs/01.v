import { createAsyncTabContentWrapper } from '~/usage_quotas/components/async_tab_content_wrapper';
import { getTransferTabMetadata } from './utils';

export const getProjectTransferTabMetadata = () => {
  const ProjectTransferApp = () => {
    const component = import(
      /* webpackChunkName: 'uq_transfer_project' */ './components/project_transfer_app.vue'
    );
    return createAsyncTabContentWrapper(component);
  };
  return getTransferTabMetadata({ vueComponent: ProjectTransferApp });
};
