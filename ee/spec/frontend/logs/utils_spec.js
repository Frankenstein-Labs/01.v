import { createIssueUrlWithLogDetails } from 'ee/logs/utils';
import setWindowLocation from 'helpers/set_window_location_helper';

describe('createIssueUrlWithLogDetails', () => {
  const mockLog = {
    trace_id: 'trace123',
    fingerprint: 'fp456',
    severity_number: 5,
    service_name: 'test-service',
    timestamp: '2023-05-20T12:34:56Z',
    body: 'This is a test log message',
  };

  const mockCreateIssueUrl = 'https://example.com/create-issue';

  beforeEach(() => {
    setWindowLocation('https://test.com/logs?fingerprint=1234');
  });

  it('should create a URL with correct log details', () => {
    const result = createIssueUrlWithLogDetails({
      log: mockLog,
      createIssueUrl: mockCreateIssueUrl,
    });

    const url = new URL(result);
    const observabilityLogDetails = JSON.parse(url.searchParams.get('observability_log_details'));

    expect(url.origin + url.pathname).toBe(mockCreateIssueUrl);
    expect(observabilityLogDetails).toEqual({
      fullUrl: 'https://test.com/logs?fingerprint=1234',
      traceId: 'trace123',
      fingerprint: 'fp456',
      severityNumber: 5,
      service: 'test-service',
      timestamp: '2023-05-20T12:34:56Z',
      body: 'This is a test log message',
    });

    expect(url.searchParams.get('issue[confidential]')).toBe('true');
  });

  it('should truncate log body if it exceeds LOG_BODY_LIMIT', () => {
    const longBody = 'a'.repeat(2000);
    const logWithLongBody = { ...mockLog, body: longBody };

    const result = createIssueUrlWithLogDetails({
      log: logWithLongBody,
      createIssueUrl: mockCreateIssueUrl,
    });

    const url = new URL(result);
    const observabilityLogDetails = JSON.parse(url.searchParams.get('observability_log_details'));

    const EXPECTED_LOG_BODY_LIMIT = 1000;
    const EXPECTED_SUFFIX = `[...]`;

    expect(observabilityLogDetails.body).toHaveLength(EXPECTED_LOG_BODY_LIMIT);
    expect(observabilityLogDetails.body).toBe(
      `${'a'.repeat(EXPECTED_LOG_BODY_LIMIT - EXPECTED_SUFFIX.length)}${EXPECTED_SUFFIX}`,
    );
  });
});
