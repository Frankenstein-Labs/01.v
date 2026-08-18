import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ReviewWorkplanEmptyState from 'ee/work_items/components/ai_widget/review_workplan_empty_state.vue';

describe('ReviewWorkplanEmptyState', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ReviewWorkplanEmptyState);
  };

  const findHeader = () => wrapper.findByTestId('workplan-header');
  const findDescription = () => wrapper.findByTestId('workplan-description');
  const findReviewButton = () => wrapper.findComponentByTestId('review-workplan-button');

  beforeEach(() => {
    createComponent();
  });

  it('shows the "found" copy', () => {
    expect(findHeader().text()).toBe('Workplan found');
    expect(findDescription().text()).toBe('A workplan has already been started for this item.');
  });

  describe('when the review button is clicked', () => {
    beforeEach(() => {
      findReviewButton().vm.$emit('click');
    });

    it('emits review-workplan', () => {
      expect(wrapper.emitted('review-workplan')).toHaveLength(1);
    });
  });
});
