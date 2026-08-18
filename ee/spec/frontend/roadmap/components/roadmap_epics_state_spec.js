import { GlFormRadioGroup } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoadmapEpicsState from 'ee/roadmap/components/roadmap_epics_state.vue';
import { STATUS_ALL, STATUS_CLOSED, STATUS_OPEN } from '~/issues/constants';

describe('RoadmapEpicsState', () => {
  let wrapper;

  const availableStates = [
    { text: 'Show all epics', value: STATUS_ALL },
    { text: 'Show open epics', value: STATUS_OPEN },
    { text: 'Show closed epics', value: STATUS_CLOSED },
  ];

  const createComponent = (epicsState = STATUS_ALL) => {
    wrapper = shallowMountExtended(RoadmapEpicsState, {
      propsData: {
        epicsState,
      },
    });
  };

  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  it('renders radio form group with correct checked option', () => {
    createComponent();

    expect(findFormRadioGroup().props('options')).toEqual(availableStates);
    expect(findFormRadioGroup().attributes('checked')).toBe(STATUS_ALL);
  });

  it('emits `set-epics-state` event when radio option is changed', () => {
    createComponent(STATUS_OPEN);
    findFormRadioGroup().vm.$emit('change', STATUS_CLOSED);

    expect(wrapper.emitted('set-epics-state')).toEqual([[{ epicsState: STATUS_CLOSED }]]);
  });

  it('does not emit `set-epics-state` event when radio option is the same', () => {
    createComponent(STATUS_OPEN);
    findFormRadioGroup().vm.$emit('change', STATUS_OPEN);

    expect(wrapper.emitted('set-epics-state')).toBeUndefined();
  });
});
