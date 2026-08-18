import { GlDisclosureDropdown, GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import inlineFindingsDropdown from 'ee/diffs/components/inline_findings_dropdown.vue';

import {
  singularCodeQualityFinding,
  singularSastFinding,
  singularSastFindingDetected,
  singularSastFindingDismissed,
  dropdownIcon,
} from 'jest/diffs/mock_data/inline_findings';

let wrapper;
const findIcon = () => wrapper.findComponentByTestId('toggle-icon');
const findGlDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
const findDismissedBadge = () => wrapper.findComponent(GlBadge);

const MOCKED_ITEMS = [
  {
    name: '1 Code Quality finding detected',
    items: singularCodeQualityFinding,
  },
  {
    name: '1 SAST finding detected',
    items: singularSastFinding,
  },
];

const payload = {
  items: MOCKED_ITEMS,

  iconId: dropdownIcon.id,
  iconKey: dropdownIcon.key,
  iconName: dropdownIcon.name,
  iconClass: dropdownIcon.class,
};

const createComponent = ({ propsData = payload, stubs = {} } = {}) => {
  wrapper = shallowMountExtended(inlineFindingsDropdown, {
    propsData,
    stubs,
  });
};

describe('inlineFindingsDropdown', () => {
  it('renders gl-disclosure-dropdown with correct props', () => {
    createComponent();
    expect(wrapper.exists()).toBe(true);
    expect(findGlDisclosureDropdown().props('items')).toEqual(MOCKED_ITEMS);
  });

  it('emits mouseenter and mouseleave events on toggle hover', () => {
    createComponent();

    findIcon().vm.$emit('mouseenter');
    findIcon().vm.$emit('mouseleave');

    expect(wrapper.emitted('mouseenter')).toHaveLength(1);
    expect(wrapper.emitted('mouseleave')).toHaveLength(1);
  });

  it('renders dismissed badge when status is dismissed', () => {
    createComponent({
      propsData: {
        items: [
          {
            name: '1 SAST finding detected',
            items: singularSastFindingDismissed,
          },
        ],
        iconId: dropdownIcon.id,
        iconKey: dropdownIcon.key,
        iconName: dropdownIcon.name,
        iconClass: dropdownIcon.class,
      },
      stubs: {
        GlDisclosureDropdown,
      },
    });

    expect(findDismissedBadge().exists()).toBe(true);
  });

  it('does not render dismissed badge when status is detected', () => {
    createComponent({
      propsData: {
        items: [
          {
            name: '1 SAST finding detected',
            items: singularSastFindingDetected,
          },
        ],
        iconId: dropdownIcon.id,
        iconKey: dropdownIcon.key,
        iconName: dropdownIcon.name,
        iconClass: dropdownIcon.class,
      },
    });

    expect(findDismissedBadge().exists()).toBe(false);
  });
});
