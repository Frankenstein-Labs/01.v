import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RunnerFormFields from '~/ci/runner/components/runner_form_fields.vue';

const mockMaintenanceNote = 'A note.';

describe('RunnerFormFields', () => {
  let wrapper;

  const findTextarea = (name) => wrapper.find(`textarea[name="${name}"]`);

  const createComponent = ({ value } = {}) => {
    wrapper = mountExtended(RunnerFormFields, {
      propsData: {
        value,
      },
      provide: {
        glFeatures: {
          runnerMaintenanceNote: true,
        },
      },
    });
  };

  it('updates runner maintenance note', async () => {
    createComponent({ value: {} });
    await waitForPromises();

    expect(wrapper.emitted('input')).toBe(undefined);

    findTextarea('maintenance-note').setValue(mockMaintenanceNote);
    await waitForPromises();

    expect(wrapper.emitted('input')[0][0]).toEqual({
      maintenanceNote: mockMaintenanceNote,
    });
  });
});
