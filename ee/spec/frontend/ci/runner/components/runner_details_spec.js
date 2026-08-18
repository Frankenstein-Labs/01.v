import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import RunnerDetails from '~/ci/runner/components/runner_details.vue';
import RunnerDetail from '~/ci/runner/components/runner_detail.vue';
import RunnerMaintenanceNoteDetail from 'ee_component/ci/runner/components/runner_maintenance_note_detail.vue';

import { runnerData } from 'jest/ci/runner/mock_data';

const mockRunner = runnerData.data.runner;

describe('RunnerDetails', () => {
  let wrapper;

  const findRunnerMaintenanceNoteDetail = () => wrapper.findComponent(RunnerMaintenanceNoteDetail);

  const createComponent = ({ props = {}, mountFn = shallowMountExtended, ...options } = {}) => {
    wrapper = mountFn(RunnerDetails, {
      propsData: {
        runnerId: mockRunner.id,
        ...props,
      },
      ...options,
    });
  };

  describe('Maintenance Note', () => {
    const mockNoteHtml = 'Note.';

    beforeEach(() => {
      createComponent({
        props: {
          runner: {
            ...mockRunner,
            maintenanceNoteHtml: mockNoteHtml,
          },
        },
        stubs: {
          RunnerDetail,
          RunnerMaintenanceNoteDetail,
        },
        provide: {
          glFeatures: {
            runnerMaintenanceNote: true,
          },
        },
      });
    });

    it('displays note', () => {
      expect(findRunnerMaintenanceNoteDetail().props('runner')).toEqual({
        ...mockRunner,
        maintenanceNoteHtml: mockNoteHtml,
      });

      expect(findRunnerMaintenanceNoteDetail().text()).toContain(mockNoteHtml);
    });
  });
});
