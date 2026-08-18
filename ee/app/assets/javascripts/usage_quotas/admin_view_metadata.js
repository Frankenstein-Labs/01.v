import { getPipelineTabMetadata } from 'ee/usage_quotas/pipelines/admin/pipeline_tab_metadata';
import { mountUsageQuotasApp } from '~/usage_quotas/utils';

export const usageQuotasTabsMetadata = [getPipelineTabMetadata()].filter(Boolean);

export default () => mountUsageQuotasApp(usageQuotasTabsMetadata);
