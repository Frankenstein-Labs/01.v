import { uploadMetricsSnapshot } from 'ee/metrics/details/metrics_snapshot';
import { domElementToBlob } from '~/lib/utils/screenshot_utils';
import { uploadImageToProject } from '~/api/projects_api';
import { useFakeDate } from 'helpers/fake_date';

jest.mock('~/lib/utils/screenshot_utils');
jest.mock('~/api/projects_api');

describe('uploadMetricsSnapshot', () => {
  useFakeDate('2024-08-01 11:00:00');

  const mockElement = document.createElement('div');
  const mockProjectId = 123;
  const mockBlobData = new Blob(['mock data']);
  const mockShareUrl = 'https://example.com/share/image.png';
  const metricProperties = {
    metricName: 'test.metric',
    metricType: 'Sum',
    filters: { dateRange: { value: '5m' } },
  };

  beforeEach(() => {
    domElementToBlob.mockResolvedValue(mockBlobData);
    uploadImageToProject.mockResolvedValue(mockShareUrl);
  });

  it('should upload a metrics snapshot', async () => {
    const result = await uploadMetricsSnapshot(mockElement, mockProjectId, metricProperties);

    expect(domElementToBlob).toHaveBeenCalledWith(mockElement);
    expect(uploadImageToProject).toHaveBeenCalledWith({
      blobData: mockBlobData,
      filename:
        'sum_metric_test.metric_thu-01-aug-2024-10-55-00-gmt_thu-01-aug-2024-11-00-00-gmt_snapshot.png',
      projectId: mockProjectId,
    });
    expect(result).toBe(mockShareUrl);
  });
});
