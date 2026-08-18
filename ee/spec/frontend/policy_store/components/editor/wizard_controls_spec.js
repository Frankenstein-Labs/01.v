import { GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import WizardControls from 'ee/policy_store/components/editor/wizard_controls.vue';

describe('WizardControls', () => {
  let wrapper;

  const buildSteps = (statuses) =>
    statuses.map((status, index) => ({
      id: `step-${index}`,
      number: index + 1,
      label: `Step ${index + 1}`,
      status,
      isLast: index === statuses.length - 1,
    }));

  const createComponent = ({
    statuses = ['current', 'upcoming', 'upcoming'],
    mode = 'enforce',
  } = {}) => {
    wrapper = shallowMountExtended(WizardControls, {
      propsData: { steps: buildSteps(statuses), mode },
      // The pill lives in the listbox's toggle slot; the default stub would swallow it.
      // Only the toggle slot renders: the list-item slot needs an `item` scope the
      // stub cannot supply.
      stubs: {
        GlCollapsibleListbox: stubComponent(GlCollapsibleListbox, {
          template: '<div><slot name="toggle"></slot></div>',
        }),
      },
    });
  };

  const findSteps = () => wrapper.findByTestId('wizard-steps');
  const findModeSelector = () => wrapper.findComponent(GlCollapsibleListbox);
  const findModeToggle = () => wrapper.findComponentByTestId('mode-toggle');
  const findModeReservation = () => wrapper.findByTestId('mode-reservation');

  it('renders every step label', () => {
    createComponent();

    ['Step 1', 'Step 2', 'Step 3'].forEach((label) => {
      expect(findSteps().text()).toContain(label);
    });
  });

  it('renders a connector between steps but not after the last', () => {
    createComponent();

    expect(findSteps().findAll('[aria-hidden="true"]')).toHaveLength(2);
  });

  it('marks only the current step with aria-current', () => {
    createComponent({ statuses: ['complete', 'current', 'upcoming'] });

    const current = findSteps().findAll('[aria-current="step"]');
    expect(current).toHaveLength(1);
    expect(current.at(0).text()).toContain('Step 2');
  });

  it('replaces the number with a check once a step is complete', () => {
    createComponent({ statuses: ['complete', 'current', 'upcoming'] });

    expect(findSteps().findComponent(GlIcon).props('name')).toBe('check');
  });

  it('shows the selected enforcement mode on the pill', () => {
    createComponent({ mode: 'warn' });

    expect(findModeSelector().props('selected')).toBe('warn');
    expect(findModeToggle().text()).toContain('Warn');
    expect(findModeToggle().findComponent(GlIcon).props('name')).toBe('status-alert');
  });

  it('labels the dropdown with an enforcement mode header', () => {
    createComponent();

    expect(findModeSelector().props('headerText')).toBe('Enforcement mode');
  });

  it.each([
    ['enforce', '!gl-bg-feedback-danger'],
    ['warn', '!gl-bg-feedback-warning'],
    ['audit', '!gl-bg-feedback-neutral'],
  ])('tints the %s pill without resizing its reserved container', (mode, tint) => {
    createComponent({ mode });

    expect(findModeToggle().classes()).toContain(tint);
    // The wrapper reserves a fixed width so a longer or shorter mode label
    // cannot shift the sibling step indicator.
    expect(findModeReservation().classes()).toContain('gl-w-31');
  });

  it('describes every mode in the dropdown items', () => {
    createComponent();

    findModeSelector()
      .props('items')
      .forEach((item) => {
        expect(item.description).toEqual(expect.any(String));
      });
  });

  it('re-emits a mode selection', () => {
    createComponent();

    findModeSelector().vm.$emit('select', 'audit');

    expect(wrapper.emitted('select-mode')).toEqual([['audit']]);
  });
});
