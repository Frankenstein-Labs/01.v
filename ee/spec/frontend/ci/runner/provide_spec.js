import { runnersAppProvide } from 'ee/ci/runner/provide';

import { runnerInstallHelpPage } from 'jest/ci/runner/mock_data';
import { runnerDashboardPath } from 'ee_jest/ci/runner/mock_data';
import { ONLINE_CONTACT_TIMEOUT_SECS, STALE_TIMEOUT_SECS } from '~/ci/runner/constants';

const mockDataset = {
  runnerInstallHelpPage,
  onlineContactTimeoutSecs: ONLINE_CONTACT_TIMEOUT_SECS,
  staleTimeoutSecs: STALE_TIMEOUT_SECS,
  runnerDashboardPath,
};

describe('ee admin runners provide', () => {
  it('returns runnerDashboardPath', () => {
    expect(runnersAppProvide(mockDataset)).toMatchObject({
      runnerDashboardPath,
    });
  });
});
