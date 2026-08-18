import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import RunnerDetail from '~/ci/runner/components/runner_detail.vue';

import RunnerMaintenanceNoteDetail from 'ee_component/ci/runner/components/runner_maintenance_note_detail.vue';

describe('RunnerMaintenanceNoteDetail', () => {
  let wrapper;

  const findRunnerDetail = () => wrapper.findComponent(RunnerDetail);

  const createComponent = ({ props = {}, mountFn = shallowMountExtended, ...options } = {}) => {
    wrapper = mountFn(RunnerMaintenanceNoteDetail, {
      propsData: {
        runner: {
          userPermissions: { updateRunner: true },
        },
        ...props,
      },
      provide: {
        glFeatures: { runnerMaintenanceNote: true },
      },
      ...options,
    });
  };

  describe('when runner_maintenance_note is enabled and user can edit the runner, note is present', () => {
    it('note is present', () => {
      createComponent();

      expect(findRunnerDetail().exists()).toBe(true);
    });

    it('note is shown', () => {
      const value = 'Note.';

      createComponent({
        props: {
          value,
        },
      });

      expect(findRunnerDetail().props('label')).toBe('Maintenance note');
      expect(findRunnerDetail().text()).toBe(value);
    });

    it('note shows empty state', () => {
      const value = null;

      createComponent({
        props: {
          value,
        },
        mountFn: mountExtended,
      });

      expect(findRunnerDetail().props('label')).toBe('Maintenance note');
      expect(findRunnerDetail().find('dd').text()).toBe('None');
    });
  });

  describe('when runner_maintenance_note is disabled', () => {
    const provide = {
      glFeatures: { runnerMaintenanceNote: false },
    };

    it('note is not present', () => {
      createComponent({
        provide,
      });

      expect(findRunnerDetail().exists()).toBe(false);
    });
  });

  describe('when user cannot update runner', () => {
    it('note is not present', () => {
      createComponent({
        props: {
          runner: {
            userPermissions: { updateRunner: false },
          },
        },
      });

      expect(findRunnerDetail().exists()).toBe(false);
    });
  });
});
