import { shallowMount } from '@vue/test-utils';
import StageFieldMove from 'ee/analytics/cycle_analytics/vsa_settings/components/stage_field_move.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';

const stageCount = 3;

describe('StageFieldActions', () => {
  function createComponent({ index = 0 }) {
    return extendedWrapper(
      shallowMount(StageFieldMove, {
        propsData: {
          index,
          stageCount,
        },
      }),
    );
  }

  let wrapper = null;
  const findMoveDownBtn = (index = 0) =>
    wrapper.findComponentByTestId(`stage-action-move-down-${index}`);
  const findMoveUpBtn = (index = 0) =>
    wrapper.findComponentByTestId(`stage-action-move-up-${index}`);

  beforeEach(() => {
    wrapper = createComponent({});
  });

  it('will render the move up action', () => {
    expect(findMoveUpBtn().exists()).toBe(true);
  });

  it('will render the move down action', () => {
    expect(findMoveDownBtn().exists()).toBe(true);
  });

  it('disables the move up button', () => {
    expect(findMoveUpBtn().props('disabled')).toBe(true);
  });

  it('when the down button is clicked will emit a `move` event', () => {
    findMoveDownBtn().vm.$emit('click');
    expect(wrapper.emitted('move')[0]).toEqual([{ direction: 'DOWN', index: 0 }]);
  });

  it('when the up button is clicked will emit a `move` event', () => {
    findMoveUpBtn().vm.$emit('click');
    expect(wrapper.emitted('move')[0]).toEqual([{ direction: 'UP', index: 0 }]);
  });

  describe('when the current index is the same as the total number of stages', () => {
    beforeEach(() => {
      wrapper = createComponent({ index: 2 });
    });

    it('disables the move down button', () => {
      expect(findMoveDownBtn(2).props('disabled')).toBe(true);
    });
  });
});
