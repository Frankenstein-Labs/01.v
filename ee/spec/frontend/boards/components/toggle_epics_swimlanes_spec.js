import { GlToggle } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import ToggleEpicsSwimlanes from 'ee/boards/components/toggle_epics_swimlanes.vue';

describe('ToggleEpicsSwimlanes', () => {
  let wrapper;

  const findToggle = () => wrapper.findComponent(GlToggle);

  const createComponent = ({ isSwimlanesOn = false } = {}) => {
    wrapper = shallowMountExtended(ToggleEpicsSwimlanes, {
      propsData: {
        isSwimlanesOn,
      },
      stubs: {
        GlToggle,
      },
    });
  };

  it('maintains state when props are changed', async () => {
    createComponent({ isSwimlanesOn: true });

    expect(findToggle().props('value')).toBe(true);

    wrapper.setProps({ isSwimlanesOn: false });
    await nextTick();
    expect(findToggle().props('value')).toBe(false);
  });
});
