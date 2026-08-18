import customApolloProvider from 'ee/usage_quotas/shared/provider';
import { getNamespaceStorageTabMetadata } from '~/usage_quotas/storage/namespace/tab_metadata';
import { mountUsageQuotasApp } from '~/usage_quotas/utils';
import { getImportTabMetadata } from '~/usage_quotas/import/tab_metadata';
import { getSeatTabMetadata } from './seats/tab_metadata';
import { getPipelineTabMetadata } from './pipelines/namespace/tab_metadata';
import { getGroupTransferTabMetadata } from './transfer/group_tab_metadata';
import { getPagesTabMetadata } from './pages/tab_metadata';

const usageQuotasTabsMetadata = [
  getSeatTabMetadata(),
  getPipelineTabMetadata(),
  getNamespaceStorageTabMetadata({ customApolloProvider }),
  getGroupTransferTabMetadata(),
  getPagesTabMetadata(),
  getImportTabMetadata(),
].filter(Boolean);

export default () => mountUsageQuotasApp(usageQuotasTabsMetadata);
