import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PanelFormGroup from 'ee/cd/components/shared/panel_form_group.vue';

describe('PanelFormGroup', () => {
  let wrapper;

  const findDescription = () => wrapper.findByTestId('description');
  const findStep = () => wrapper.findByTestId('step');
  const findTitle = () => wrapper.findByTestId('title');
  const findSlottedInput = () => wrapper.findByTestId('slotted-input');

  const createComponent = () => {
    wrapper = shallowMountExtended(PanelFormGroup, {
      propsData: {
        description: 'My description',
        step: '1',
        title: 'My title',
      },
      slots: {
        default: '<input data-testid="slotted-input" />',
      },
    });
  };

  it('renders the description', () => {
    createComponent();

    expect(findDescription().text()).toBe('My description');
  });

  it('renders the step', () => {
    createComponent();

    expect(findStep().text()).toBe('1');
  });

  it('renders the title', () => {
    createComponent();

    expect(findTitle().text()).toBe('My title');
  });

  it('renders the default slot content', () => {
    createComponent();

    expect(findSlottedInput().exists()).toBe(true);
  });
});
