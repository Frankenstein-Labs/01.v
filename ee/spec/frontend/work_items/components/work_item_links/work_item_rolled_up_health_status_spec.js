import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import WorkItemRolledUpHealthStatus from 'ee/work_items/components/work_item_links/work_item_rolled_up_health_status.vue';

import { mockRolledUpHealthStatus } from '../../mock_data';

describe('WorkItem Rolled up health data spec', () => {
  let wrapper;

  const createComponent = ({
    rolledUpHealthStatus = mockRolledUpHealthStatus,
    healthStatus = null,
  } = {}) => {
    wrapper = shallowMountExtended(WorkItemRolledUpHealthStatus, {
      propsData: {
        rolledUpHealthStatus,
        healthStatus,
      },
    });
  };

  const findWrapper = () => wrapper.findByTestId('rolled-up-health-status-wrapper');
  const findElement = (dataTestid) => wrapper.findByTestId(dataTestid);

  it('does not render rolled up health status when the count of each status is 0', () => {
    /** we are modifying the rolledup health status to make sure all of the status count is 0 */
    createComponent({
      rolledUpHealthStatus: mockRolledUpHealthStatus.map((healthStatus) => ({
        ...healthStatus,
        count: 0,
      })),
    });

    expect(findWrapper().exists()).toBe(false);
  });

  it('renders the rolled up health status when atleast one of the status count is greater than 0', () => {
    /** we are modifying the rolledup health status to make sure only one of the status count is 0 */
    createComponent({
      rolledUpHealthStatus: mockRolledUpHealthStatus.map((healthStatus, index) => ({
        ...healthStatus,
        count: index === 0 ? 1 : 0,
      })),
    });

    expect(findWrapper().exists()).toBe(true);
  });

  describe('health status', () => {
    it.each`
      healthStatusType    | healthStatusCount | label                | countDataTestId            | labelDataTestId
      ${'onTrack'}        | ${0}              | ${'items on track'}  | ${'on-track-count'}        | ${'on-track-info'}
      ${'onTrack'}        | ${1}              | ${'item on track'}   | ${'on-track-count'}        | ${'on-track-info'}
      ${'onTrack'}        | ${10}             | ${'items on track'}  | ${'on-track-count'}        | ${'on-track-info'}
      ${'atRisk'}         | ${0}              | ${'items at risk'}   | ${'at-risk-count'}         | ${'at-risk-info'}
      ${'atRisk'}         | ${1}              | ${'item at risk'}    | ${'at-risk-count'}         | ${'at-risk-info'}
      ${'atRisk'}         | ${10}             | ${'items at risk'}   | ${'at-risk-count'}         | ${'at-risk-info'}
      ${'needsAttention'} | ${0}              | ${'need attention'}  | ${'needs-attention-count'} | ${'needs-attention-info'}
      ${'needsAttention'} | ${1}              | ${'needs attention'} | ${'needs-attention-count'} | ${'needs-attention-info'}
      ${'needsAttention'} | ${10}             | ${'need attention'}  | ${'needs-attention-count'} | ${'needs-attention-info'}
    `(
      'displays the correct values for $healthStatusType when count is $healthStatusCount',
      ({ healthStatusType, healthStatusCount, label, countDataTestId, labelDataTestId }) => {
        createComponent({
          rolledUpHealthStatus: mockRolledUpHealthStatus.map((healthStatus) => ({
            ...healthStatus,
            count:
              healthStatus.healthStatus === healthStatusType
                ? healthStatusCount
                : healthStatus.count,
          })),
        });

        expect(findElement(countDataTestId).text()).toBe(`${healthStatusCount}`);
        expect(findElement(labelDataTestId).text()).toContain(label);
      },
    );
  });
});
