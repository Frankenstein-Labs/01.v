import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RiskScoreGroupBy from 'ee/security_dashboard/components/shared/risk_score_group_by.vue';

describe('OverTimeGroupBy', () => {
  let wrapper;

  const createComponent = (props = { value: 'severity' }) => {
    wrapper = shallowMountExtended(RiskScoreGroupBy, {
      propsData: {
        ...props,
      },
    });
  };

  const findNoGroupingButton = () => wrapper.findComponentByTestId('default-button');
  const findProjectButton = () => wrapper.findComponentByTestId('project-button');

  it('renders no grouping group by button', () => {
    createComponent();
    expect(findNoGroupingButton().text()).toBe('No grouping');
  });

  it('renders project group by button', () => {
    createComponent();
    expect(findProjectButton().text()).toBe('Project');
  });

  it.each([
    ['default', findNoGroupingButton, findProjectButton],
    ['project', findProjectButton, findNoGroupingButton],
  ])(
    'when %p value is passed, set correct button as selected',
    (value, selectedFn, unselectedFn) => {
      createComponent({ value });

      expect(selectedFn().props('selected')).toBe(true);
      expect(unselectedFn().props('selected')).toBe(false);
    },
  );

  it.each([
    ['default', findNoGroupingButton],
    ['project', findProjectButton],
  ])('when %p button is clicked, emit correct event', (value, findFn) => {
    createComponent({ value });
    findFn().vm.$emit('click');
    expect(wrapper.emitted('input')).toMatchObject([[value]]);
  });
});
