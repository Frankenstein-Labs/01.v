import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VerificationStep from 'ee/users/identity_verification/components/verification_step.vue';

describe('VerificationStep', () => {
  let wrapper;

  const StepComponent = {
    name: 'step-component',
    template: '<p>Step</p>',
  };

  const DEFAULT_PROPS = {
    title: 'The Verification Step',
    completed: false,
    isActive: false,
  };

  const createComponent = ({ props, provide } = { props: {}, provide: {} }) => {
    wrapper = shallowMountExtended(VerificationStep, {
      propsData: { ...DEFAULT_PROPS, ...props },
      provide,
      slots: { default: StepComponent },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findTitle = () => wrapper.findByText(DEFAULT_PROPS.title);
  const findStep = () => wrapper.findComponent(StepComponent);
  const findSubhead = () => wrapper.findByTestId('subhead');

  describe('Default: completed: false, inactive: false', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays the passed provided title', () => {
      expect(findTitle().exists()).toBe(true);
    });

    it('does not display completed icon', () => {
      expect(findIcon().exists()).toBe(false);
    });

    it('does not render the default child component', () => {
      expect(findStep().exists()).toBe(false);
    });
  });

  describe('completed prop is true', () => {
    beforeEach(() => {
      createComponent({ props: { completed: true } });
    });

    it('displays completed badge', () => {
      expect(findIcon().exists()).toBe(true);
      expect(findIcon().props()).toMatchObject({ name: 'check' });
    });
  });

  describe('isActive prop is true', () => {
    beforeEach(() => {
      createComponent({ props: { isActive: true } });
    });

    it('renders the default child component', () => {
      expect(findStep().exists()).toBe(true);
    });
  });

  describe('when there are multiple steps', () => {
    beforeEach(() => {
      createComponent({ props: { completed: true } });
    });

    it('renders the step help text correctly', () => {
      createComponent({ props: { totalSteps: 3, stepIndex: 1 } });

      expect(wrapper.text()).toContain('Step 2 of 3');
    });
  });

  describe('subhead prop', () => {
    it('renders subhead when provided and not completed', () => {
      const subhead = 'This is a subheading';
      createComponent({ props: { subhead } });

      expect(findSubhead().exists()).toBe(true);
      expect(findSubhead().text()).toBe(subhead);
    });

    it('does not render subhead when completed', () => {
      const subhead = 'This is a subheading';
      createComponent({ props: { subhead, completed: true } });

      expect(findSubhead().exists()).toBe(false);
    });

    it('does not render subhead when not provided', () => {
      createComponent();

      expect(findSubhead().exists()).toBe(false);
    });
  });
});
