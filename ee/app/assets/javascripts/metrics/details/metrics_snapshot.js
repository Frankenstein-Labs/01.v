import { domElementToBlob } from '~/lib/utils/screenshot_utils';
import { uploadImageToProject } from '~/api/projects_api';
import { getAbsoluteDateRange, getTimeframe } from 'ee/metrics/details/utils';
import { slugify } from '~/lib/utils/text_utility';

export async function uploadMetricsSnapshot(element, projectId, metricProperties) {
  const timeFrame = getTimeframe(getAbsoluteDateRange(metricProperties.filters.dateRange));

  // e.g. sum_metric_calls_tue-24-sep-2024-12-18-53-gmt_tue-24-sep-2024-13-18-53-gmt_snapshot.png
  const filename = slugify(
    `${metricProperties.metricType.toLowerCase()}_metric_${metricProperties.metricName}_${timeFrame.join('_')}_snapshot.png`,
  );
  const blobData = await domElementToBlob(element);

  return uploadImageToProject({
    blobData,
    filename,
    projectId,
  });
}
