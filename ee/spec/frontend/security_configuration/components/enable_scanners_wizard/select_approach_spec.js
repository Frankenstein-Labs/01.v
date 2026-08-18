import { GlCard, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EnableScannersSelectApproach from 'ee/security_configuration/components/enable_scanners_wizard/select_approach.vue';
import {
  APPROACH_QUICK,
  APPROACH_ADVANCED,
} from 'ee/security_configuration/components/enable_scanners_wizard/constants';

describe('EnableScannersSelectApproach', () => {
  let wrapper;
  let enableScanners;

  const createComponent = ({ approach = APPROACH_QUICK } = {}) => {
    enableScanners = { approach };
    wrapper = shallowMountExtended(EnableScannersSelectApproach, {
      provide: { enableScanners },
      stubs: { GlCard },
    });
  };

  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findCards = () => wrapper.findAllComponents(GlCard);
  const findRadios = () => wrapper.findAllComponents(GlFormRadio);

  it('renders the quick setup and advanced setup options as cards with radio buttons', () => {
    createComponent();

    expect(findCards()).toHaveLength(2);
    expect(findCards().at(0).text()).toContain('Quick setup');
    expect(findCards().at(1).text()).toContain('Advanced setup');

    expect(findRadios()).toHaveLength(2);
    expect(findRadios().at(0).attributes('value')).toBe(APPROACH_QUICK);
    expect(findRadios().at(1).attributes('value')).toBe(APPROACH_ADVANCED);
  });

  it.each([APPROACH_QUICK, APPROACH_ADVANCED])(
    'sets the selected approach to %s on click',
    (approach) => {
      createComponent({ approach: null });

      findRadioGroup().vm.$emit('input', approach);

      expect(enableScanners.approach).toBe(approach);
    },
  );
});
