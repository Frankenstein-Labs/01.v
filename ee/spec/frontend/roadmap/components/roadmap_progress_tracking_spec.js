import { GlFormGroup, GlFormRadioGroup, GlToggle } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoadmapProgressTracking from 'ee/roadmap/components/roadmap_progress_tracking.vue';
import { PROGRESS_WEIGHT, PROGRESS_COUNT, PROGRESS_TRACKING_OPTIONS } from 'ee/roadmap/constants';

describe('RoadmapProgressTracking', () => {
  let wrapper;

  const createComponent = ({ isProgressTrackingActive = true } = {}) => {
    wrapper = shallowMountExtended(RoadmapProgressTracking, {
      propsData: {
        progressTracking: PROGRESS_WEIGHT,
        isProgressTrackingActive,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findToggle = () => wrapper.findComponent(GlToggle);

  beforeEach(() => {
    createComponent();
  });

  describe('template', () => {
    it('renders form group', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(findFormGroup().attributes('label')).toBe('Progress tracking');
    });

    it.each`
      isProgressTrackingActive
      ${true}
      ${false}
    `(
      'displays radio form group depending on isProgressTrackingActive',
      ({ isProgressTrackingActive }) => {
        createComponent({ isProgressTrackingActive });

        expect(findFormRadioGroup().exists()).toBe(isProgressTrackingActive);
        if (isProgressTrackingActive) {
          expect(findFormRadioGroup().props('options')).toEqual(PROGRESS_TRACKING_OPTIONS);
        }
      },
    );
  });

  it('emits `set-progress-tracking` event when radio button is clicked', () => {
    createComponent();
    findFormRadioGroup().vm.$emit('change', PROGRESS_COUNT);

    expect(wrapper.emitted('set-progress-tracking')).toEqual([
      [{ progressTracking: PROGRESS_COUNT }],
    ]);
  });

  it('emits `set-progress-tracking` event when progress tracking visibility is toggled', () => {
    createComponent();
    findToggle().vm.$emit('change');

    expect(wrapper.emitted('set-progress-tracking')).toEqual([
      [{ isProgressTrackingActive: false }],
    ]);
  });
});
