import { shallowMount } from '@vue/test-utils';
import StageFieldActions from 'ee/analytics/cycle_analytics/vsa_settings/components/stage_field_actions.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

describe('StageFieldActions', () => {
  function createComponent({ index = 0, canRemove = false }) {
    return extendedWrapper(
      shallowMount(StageFieldActions, {
        propsData: {
          index,
          canRemove,
        },
      }),
    );
  }

  let wrapper = null;
  const findHideBtn = (index = 0) => wrapper.findComponentByTestId(`stage-action-hide-${index}`);
  const findRemoveBtn = (index = 0) =>
    wrapper.findComponentByTestId(`stage-action-remove-${index}`);

  beforeEach(() => {
    wrapper = createComponent({});
  });

  it('will render the hide action', () => {
    expect(findHideBtn().exists()).toBe(true);
  });

  it('does not render the remove action', () => {
    expect(findRemoveBtn().exists()).toBe(false);
  });

  it('emits `hide` when the hide button is clicked', () => {
    findHideBtn().vm.$emit('click');
    expect(wrapper.emitted('hide')[0]).toEqual([0]);
  });

  describe('when canRemove=true', () => {
    beforeEach(() => {
      wrapper = createComponent({ canRemove: true });
    });

    it('will render the remove action', () => {
      expect(findRemoveBtn().exists()).toBe(true);
    });

    it('does not render the hide action', () => {
      expect(findHideBtn().exists()).toBe(false);
    });

    it('emits `remove` when the remove button is clicked', () => {
      findRemoveBtn().vm.$emit('click');
      expect(wrapper.emitted('remove')[0]).toEqual([0]);
    });
  });
});
