import { nextTick } from 'vue';
import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ChangeLifecycleStepper from 'ee/groups/settings/work_items/custom_status/change_lifecycle/change_lifecycle_stepper.vue';

describe('ChangeLifecycleStepper', () => {
  let wrapper;

  const mockSteps = [
    { label: 'Step 1', description: 'First step' },
    { label: 'Step 2', description: 'Second step' },
    { label: 'Step 3', description: 'Third step' },
  ];

  const defaultProps = {
    steps: mockSteps,
    isValidStep: true,
  };

  // Finder methods
  const findStepItems = () => wrapper.findAll('.workflow-step');
  const findActiveStep = () => wrapper.find('.workflow-step.active');
  const findCompletedSteps = () => wrapper.findAll('.workflow-step.completed');
  const findStepContent = () => wrapper.findByTestId('step-content');
  const findNextButton = () => wrapper.findComponentByTestId('stepper-next');
  const findFinishButton = () => wrapper.findComponentByTestId('stepper-finish');
  const findCancelButton = () => wrapper.findComponentByTestId('stepper-cancel');

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ChangeLifecycleStepper, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlButton,
      },
    });
  };

  describe('Component Rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders all steps with correct labels', () => {
      expect(findStepItems()).toHaveLength(3);

      findStepItems().wrappers.forEach((step, index) => {
        expect(step.find('[data-testid="step-header"]').text()).toBe(mockSteps[index].label);
      });
    });

    it('renders first step as active by default', () => {
      expect(findActiveStep().exists()).toBe(true);
      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 1');
    });

    it('renders step content for active step', () => {
      expect(findStepContent().exists()).toBe(true);
    });

    it('shows cancel button by default', () => {
      expect(findCancelButton().text()).toBe('Cancel');
    });
  });

  describe('Initial Step', () => {
    it('starts at specified initial step', () => {
      createWrapper({ initialStep: 1 });

      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 2');
    });

    it('shows completed steps before initial step', () => {
      createWrapper({ initialStep: 2 });

      expect(findCompletedSteps()).toHaveLength(2);
      expect(findActiveStep().find('[data-testid="step-header"]').text()).toBe('Step 3');
    });
  });

  describe('Step Navigation', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows next button when not on last step', () => {
      expect(findNextButton().exists()).toBe(true);
      expect(findNextButton().text()).toBe('Next');
    });

    it('does not show finish button when not on last step', () => {
      expect(findFinishButton().exists()).toBe(false);
    });
  });

  describe('Final Step', () => {
    beforeEach(() => {
      createWrapper({ initialStep: 2 });
    });

    it('shows finish button on last step', () => {
      expect(findFinishButton().text()).toBe('Save');
    });

    it('does not show next button on last step', () => {
      expect(findNextButton().exists()).toBe(false);
    });
  });

  describe('Button Visibility Props', () => {
    it('hides next button when showNextButton is false', () => {
      createWrapper({ showNextButton: false });

      expect(findNextButton().exists()).toBe(false);
    });

    it('hides finish button when showFinishButton is false', () => {
      createWrapper({ initialStep: 2, showFinishButton: false });

      expect(findFinishButton().exists()).toBe(false);
    });

    it('hides cancel button when showCancelButton is false', () => {
      createWrapper({ showCancelButton: false });

      expect(findCancelButton().exists()).toBe(false);
    });

    it('shows loading on the finish button when is updating', () => {
      createWrapper({ isUpdating: true, initialStep: 2 });

      expect(findFinishButton().props('loading')).toBe(true);
    });
  });

  describe('Events', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits step-change event when progressing forward', async () => {
      findNextButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('step-change')).toHaveLength(1);
      expect(wrapper.emitted('step-change')[0][0]).toMatchObject({
        currentStep: 1,
        direction: 'next',
        step: mockSteps[1],
      });
    });

    it('emits validate-step event before progressing', async () => {
      await findNextButton().vm.$emit('click');

      expect(wrapper.emitted('validate-step')).toHaveLength(1);
      expect(wrapper.emitted('validate-step')[0][0]).toMatchObject({
        stepIndex: 0,
        step: mockSteps[0],
      });
    });

    it('emits finish event when finish button clicked', async () => {
      createWrapper({ initialStep: 2 });

      findFinishButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('finish')).toHaveLength(1);
      expect(wrapper.emitted('finish')[0][0]).toMatchObject({
        completedSteps: mockSteps,
        currentStep: 2,
      });
    });

    it('emits cancel event when cancel button clicked', async () => {
      await findCancelButton().vm.$emit('click');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });

  describe('Slots', () => {
    it('renders default content when no slot provided', () => {
      createWrapper();

      const defaultContent = wrapper.findByTestId('default-content');
      expect(defaultContent.exists()).toBe(true);
      expect(defaultContent.find('h2').text()).toBe('Step 1');
      expect(defaultContent.find('p').text()).toBe('First step');
    });
  });
});
