import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PanelFormField from 'ee/cd/components/shared/panel_form_field.vue';

const GlFormGroupStub = {
  name: 'GlFormGroupStub',
  props: ['label', 'labelFor', 'state', 'invalidFeedback'],
  template: '<div><slot name="label"></slot><slot></slot><slot name="description"></slot></div>',
};

describe('PanelFormField', () => {
  let wrapper;

  const findFormGroup = () => wrapper.findComponent(GlFormGroupStub);
  const findSlottedInput = () => wrapper.findByTestId('slotted-input');
  const findLabel = () => wrapper.findByTestId('label');
  const findHelpText = () => wrapper.findByTestId('help-text');

  const createComponent = ({ props = {}, slots = {} } = {}) => {
    wrapper = shallowMountExtended(PanelFormField, {
      propsData: {
        label: 'My label',
        ...props,
      },
      slots: {
        default: '<input data-testid="slotted-input" />',
        ...slots,
      },
      stubs: {
        GlFormGroup: GlFormGroupStub,
      },
    });
  };

  it('renders the correct label', () => {
    createComponent();

    expect(findLabel().text()).toBe('My label');
  });

  it('renders the default slot content', () => {
    createComponent();

    expect(findSlottedInput().exists()).toBe(true);
  });

  it('renders the additional text alongside the label when provided', () => {
    createComponent({ props: { additionalText: 'Additional details' } });

    expect(findLabel().text()).toContain('Additional details');
  });

  it('associates the label with the field via the `id`', () => {
    createComponent({ props: { id: 'my-field' } });

    expect(findFormGroup().props('labelFor')).toBe('my-field');
  });

  it('passes the state and invalid feedback to the form group', () => {
    createComponent({ props: { state: false, invalidFeedback: 'Too long' } });

    expect(findFormGroup().props('state')).toBe(false);
    expect(findFormGroup().props('invalidFeedback')).toBe('Too long');
  });

  describe('help text', () => {
    it('renders when provided', () => {
      createComponent({ props: { helpText: 'Some help' } });

      expect(findHelpText().text()).toBe('Some help');
    });

    it('does not render when not provided', () => {
      createComponent();
      expect(findHelpText().exists()).toBe(false);
    });
  });
});
