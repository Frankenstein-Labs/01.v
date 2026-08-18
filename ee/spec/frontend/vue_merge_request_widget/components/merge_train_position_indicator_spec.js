import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import MergeTrainPositionIndicator from 'ee/vue_merge_request_widget/components/merge_train_position_indicator.vue';
import { STATUS_OPEN, STATUS_MERGED } from '~/issues/constants';
import { trimText } from 'helpers/text_helper';

describe('MergeTrainPositionIndicator', () => {
  let wrapper;
  let mockToast;

  const findLink = () => wrapper.findComponent(GlLink);

  const createComponent = (props) => {
    wrapper = shallowMount(MergeTrainPositionIndicator, {
      propsData: {
        mergeTrainsPath: 'namespace/project/-/merge_trains',
        ...props,
      },
      mocks: {
        $toast: {
          show: mockToast,
        },
      },
    });
  };

  it('should show message when position is higher than 1', () => {
    createComponent({
      mergeTrainCar: {
        id: 'gid://gitlab/MergeTrains::Car/1',
        index: 3,
      },
      mergeTrainsCount: 5,
    });

    expect(trimText(wrapper.text())).toBe(
      'This merge request is #4 of 5 in queue. View merge train.',
    );
    expect(findLink().attributes('href')).toBe('namespace/project/-/merge_trains');
  });

  it('should show message when the position is 1', () => {
    createComponent(
      { mergeTrainCar: { id: 'gid://gitlab/MergeTrains::Car/1', index: 0 }, mergeTrainsCount: 0 },
      true,
    );

    expect(trimText(wrapper.text())).toBe(
      'A new merge train has started and this merge request is first in the queue. View merge train.',
    );
    expect(findLink().attributes('href')).toBe('namespace/project/-/merge_trains');
  });

  it('should not render when merge request is not in train', () => {
    createComponent(
      {
        mergeTrainCar: null,
        mergeTrainsCount: 1,
      },
      true,
    );

    expect(wrapper.text()).toBe('');
  });

  describe('when car status changes in the train', () => {
    const mockCar = { id: 'gid://gitlab/MergeTrains::Car/1' };

    beforeEach(() => {
      mockToast = jest.fn();
    });

    it.each`
      currentCar | oldCar     | toastShown | mrState
      ${mockCar} | ${null}    | ${false}   | ${STATUS_OPEN}
      ${null}    | ${null}    | ${false}   | ${STATUS_OPEN}
      ${null}    | ${mockCar} | ${true}    | ${STATUS_OPEN}
      ${null}    | ${mockCar} | ${false}   | ${STATUS_MERGED}
    `(
      'toast message is shown: $toastShown',
      async ({ currentCar, oldCar, toastShown, mrState }) => {
        createComponent({ mergeTrainCar: oldCar, mergeRequestState: mrState });

        expect(mockToast).not.toHaveBeenCalled();

        await wrapper.setProps({ mergeTrainCar: currentCar });

        if (toastShown) {
          expect(mockToast).toHaveBeenCalledTimes(1);
          expect(mockToast).toHaveBeenCalledWith(
            'This merge request was removed from the merge train.',
          );
        } else {
          expect(mockToast).not.toHaveBeenCalled();
        }
      },
    );
  });
});
