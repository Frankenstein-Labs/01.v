import { shallowMount } from '@vue/test-utils';
import { GlLink, GlSprintf, GlFormGroup, GlFormCheckbox, GlPopover } from '@gitlab/ui';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import DuoExperimentBetaFeaturesForm from 'ee/ai/settings/components/duo_experiment_beta_features_form.vue';

const MOCK_DATA = {
  experimentBetaHelpPath: '/help/policy/development_stages_support',
  testingAgreementPath: `/handbook/legal/testing-agreement/`,
};

describe('DuoExperimentBetaFeaturesForm', () => {
  let wrapper;

  const createComponent = (props = {}, provide = {}) => {
    return shallowMount(DuoExperimentBetaFeaturesForm, {
      propsData: {
        disabledCheckbox: false,
        experimentFeaturesEnabled: false,
        ...props,
      },
      provide: {
        areExperimentSettingsAllowed: true,
        ...provide,
      },
      stubs: {
        GlLink,
        GlSprintf,
        GlFormGroup,
        GlFormCheckbox,
        GlPopover,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findFormCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findAgentsHeader = () => wrapper.find('[data-testid="features-subsection-header"]');
  const findAgentsDescription = () =>
    wrapper.find('[data-testid="features-subsection-description"]');

  describe('when areExperimentSettingsAllowed is false', () => {
    it('does not render the form group', () => {
      wrapper = createComponent(
        {},
        {
          areExperimentSettingsAllowed: false,
        },
      );
      expect(findFormGroup().exists()).toBe(false);
    });
  });

  describe('when areExperimentSettingsAllowed is true', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    describe('section header and description', () => {
      it('renders the preview section header', () => {
        expect(findAgentsHeader().text()).toBe('Feature preview');
      });
      it('renders the preview section description', () => {
        expect(findAgentsDescription().text()).toBe(
          'Access AI features prior to general availability.',
        );
      });
    });

    it('renders the checkbox with correct label', () => {
      expect(findFormCheckbox().exists()).toBe(true);
      expect(findFormCheckbox().text()).toContain(
        'Turn on experiment and beta GitLab Duo features',
      );
    });

    it('sets initial checkbox state based on experimentFeaturesEnabled prop when unselected', () => {
      expect(findFormCheckbox().props('checked')).toBe(false);
    });

    it('emits change event when checkbox is clicked', () => {
      findFormCheckbox().vm.$emit('change');
      expect(wrapper.emitted('change')).toEqual([[false]]);
    });

    it('does not show popover when disabledCheckbox prop is false', () => {
      expect(findPopover().exists()).toBe(false);
    });

    it('renders correct links', () => {
      const testingAgreementLink = wrapper.findComponent(PromoPageLink);
      expect(testingAgreementLink.props('path')).toBe(MOCK_DATA.testingAgreementPath);
    });
  });

  describe('when areExperimentSettingsAllowed is true and disabledCheckbox is true', () => {
    beforeEach(() => {
      wrapper = createComponent({ disabledCheckbox: true });
    });

    it('disables checkbox', () => {
      expect(findFormCheckbox().props('disabled')).toBe(true);
    });

    it('shows popover', () => {
      expect(findPopover().exists()).toBe(true);
    });
  });
});
