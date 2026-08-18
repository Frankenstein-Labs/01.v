import { createAsyncTabContentWrapper } from '~/usage_quotas/components/async_tab_content_wrapper';
import { getTransferTabMetadata } from './utils';

export const getGroupTransferTabMetadata = () => {
  const GroupTransferApp = () => {
    const component = import(
      /* webpackChunkName: 'uq_transfer_group' */ './components/group_transfer_app.vue'
    );
    return createAsyncTabContentWrapper(component);
  };
  return getTransferTabMetadata({ vueComponent: GroupTransferApp });
};
