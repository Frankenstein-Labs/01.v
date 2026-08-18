import { GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FlowStep from 'ee/cd/components/flow_step.vue';

describe('FlowStep', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(FlowStep, {
      propsData: { category: 'deploy', state: 'SUCCESS', title: 'Deploy', ...props },
    });
  };

  const findBox = () => wrapper.findByTestId('flow-step-box');
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findTitle = () => wrapper.findComponentByTestId('flow-step-title');
  const findSubtitle = () => wrapper.findComponentByTestId('flow-step-subtitle');
  const boxClasses = () => findBox().classes();

  describe('icon', () => {
    it.each([
      ['trigger', 'rocket'],
      ['deploy', 'environment'],
      ['approve', 'approval'],
      ['wait', 'hourglass'],
    ])('renders the %2$s icon for the %1$s category', (category, icon) => {
      createComponent({ category });

      expect(findIcon().props('name')).toBe(icon);
    });

    it.each([
      ['a step type the view does not know, which the transform reports as null', null],
      ['a missing category', undefined],
    ])('falls back to a question mark for %s', (_scenario, category) => {
      createComponent({ category });

      expect(findIcon().props('name')).toBe('status_notfound');
    });
  });

  describe('state', () => {
    it.each([
      ['PENDING', 'gl-border-default'],
      ['AWAITING_APPROVAL', 'gl-border-feedback-warning'],
      ['RUNNING', 'gl-border-feedback-info'],
      ['SUCCESS', 'gl-border-feedback-success'],
      ['FAILED', 'gl-border-feedback-danger'],
      ['SKIPPED', 'gl-border-subtle'],
      ['CANCELLED', 'gl-border-subtle'],
    ])('applies the %s border', (state, expected) => {
      createComponent({ state });

      expect(boxClasses()).toContain(expected);
    });

    it('marks a state the view does not know with a dashed border, rather than passing it off as pending', () => {
      createComponent({ state: 'BRAND_NEW' });

      expect(boxClasses()).toContain('gl-border-dashed');
      expect(boxClasses()).not.toContain('gl-border-feedback-info');
      expect(findBox().attributes('title')).toBe('Unknown');
    });

    it('animates while in progress', () => {
      createComponent({ state: 'RUNNING' });

      expect(boxClasses()).toContain('flow-step-border-pulse');
    });

    it.each([['PENDING'], ['SUCCESS'], ['FAILED'], ['SKIPPED']])(
      'does not animate when %s',
      (state) => {
        createComponent({ state });

        expect(boxClasses()).not.toContain('flow-step-border-pulse');
      },
    );

    it.each([
      ['PENDING', 'Pending'],
      ['AWAITING_APPROVAL', 'Awaiting approval'],
      ['RUNNING', 'Running'],
      ['SUCCESS', 'Succeeded'],
      ['FAILED', 'Failed'],
      ['SKIPPED', 'Skipped'],
      ['CANCELLED', 'Cancelled'],
    ])('describes %s as "%s" in a tooltip', (state, label) => {
      createComponent({ state });

      expect(findBox().attributes('title')).toBe(label);
    });
  });

  describe('labels', () => {
    it('renders the title', () => {
      createComponent({ title: 'Canary 50%' });

      expect(findTitle().props('text')).toBe('Canary 50%');
    });

    it('omits the title when there is none', () => {
      createComponent({ title: '' });

      expect(findTitle().exists()).toBe(false);
    });

    it('renders the subtitle', () => {
      createComponent({ subtitle: 'prod-eu-west-1' });

      expect(findSubtitle().props('text')).toBe('prod-eu-west-1');
    });

    it('truncates both labels with a tooltip only when they overflow', () => {
      createComponent({ title: 'Canary 50%', subtitle: 'prod-eu-west-1' });

      expect(findTitle().props('withTooltip')).toBe(true);
      expect(findSubtitle().props('withTooltip')).toBe(true);
    });

    it('uses middle ellipses position for the subtitle', () => {
      createComponent({ subtitle: 'staging-eu-west-1' });

      expect(findSubtitle().props('position')).toBe('middle');
    });

    describe('when there is no subtitle', () => {
      beforeEach(() => {
        createComponent({ subtitle: '' });
      });

      it('reserves the line so steps in a row stay aligned', () => {
        expect(findSubtitle().props('text')).toBe('\u00A0');
      });

      it('hides the placeholder from assistive technology', () => {
        expect(findSubtitle().attributes('aria-hidden')).toBe('true');
      });
    });
  });

  describe('muted states', () => {
    it.each([['PENDING'], ['SKIPPED'], ['CANCELLED']])(
      'mutes the title and subtitle when %s, since no work is happening',
      (state) => {
        createComponent({ state, title: 'Canary 33%', subtitle: 'production' });

        expect(findTitle().classes()).toContain('gl-text-disabled');
        expect(findSubtitle().classes()).toContain('gl-text-disabled');
      },
    );

    it.each([['RUNNING'], ['SUCCESS'], ['FAILED'], ['AWAITING_APPROVAL']])(
      'leaves the labels readable when %s',
      (state) => {
        createComponent({ state, title: 'Canary 33%', subtitle: 'production' });

        expect(findTitle().classes()).toContain('gl-text-default');
        expect(findSubtitle().classes()).toContain('gl-text-subtle');
      },
    );
  });

  describe('connector anchor', () => {
    it('exposes the node id on the box the connectors measure', () => {
      createComponent({ nodeId: 'item-1-step-0' });

      expect(findBox().attributes('data-flow-node')).toBe('item-1-step-0');
    });
  });
});
