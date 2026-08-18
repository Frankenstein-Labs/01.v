import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import LicenseFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/license_filter.vue';
import { UNKNOWN_LICENSE } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { licenseScanBuildRule } from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';

describe('LicenseFilter', () => {
  let wrapper;

  const licenseRule = { ...licenseScanBuildRule(), license_types: [] };
  delete licenseRule.licenses;

  const DEFAULT_PROPS = { initRule: licenseRule };
  const APACHE_LICENSE = 'Apache 2.0 License';
  const MIT_LICENSE = 'MIT License';
  const UPDATED_RULE = (licenses) => ({
    ...licenseRule,
    branches: [],
    match_on_inclusion: false,
    license_types: licenses,
    license_states: ['newly_detected', 'detected'],
  });
  const parsedSoftwareLicenses = [APACHE_LICENSE, MIT_LICENSE].map((l) => ({ text: l, value: l }));
  const allLicenses = [...parsedSoftwareLicenses, UNKNOWN_LICENSE];

  const createComponent = ({ props = DEFAULT_PROPS, provide = {} } = {}) => {
    wrapper = shallowMountExtended(LicenseFilter, {
      propsData: {
        initRule: licenseRule,
        ...props,
      },
      provide: {
        parsedSoftwareLicenses,
        ...provide,
      },
      stubs: {
        SectionLayout,
      },
    });
  };

  const findMatchTypeListBox = () => wrapper.findComponentByTestId('match-type-select');
  const findLicenseTypeListBox = () => wrapper.findComponentByTestId('license-type-select');
  const findSectionLayout = () => wrapper.findComponent(SectionLayout);

  describe('default rule', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits a "changed" event when the matchType is updated', async () => {
      const matchType = false;
      await findMatchTypeListBox().vm.$emit('select', matchType);
      expect(wrapper.emitted('changed')).toStrictEqual([
        [{ match_on_inclusion_license: matchType }],
      ]);
    });

    describe('license type list box', () => {
      it('displays the default toggle text', () => {
        expect(findLicenseTypeListBox()).toBeDefined();
        expect(findLicenseTypeListBox().props('toggleText')).toBe('Select license types');
      });

      it('emits a "changed" event when the licenseType is updated', async () => {
        await findLicenseTypeListBox().vm.$emit('select', MIT_LICENSE);
        expect(wrapper.emitted('changed')).toStrictEqual([[{ license_types: MIT_LICENSE }]]);
      });

      it('displays all licenses', () => {
        expect(findLicenseTypeListBox().props('items')).toStrictEqual(allLicenses);
      });

      it('filters the licenses when searching', async () => {
        const listBox = findLicenseTypeListBox();
        await listBox.vm.$emit('search', APACHE_LICENSE);
        expect(listBox.props('items')).toStrictEqual([
          { value: APACHE_LICENSE, text: APACHE_LICENSE },
        ]);
      });
    });

    describe('updated rule', () => {
      it('displays the toggle text properly with a single license selected', () => {
        createComponent({ props: { initRule: UPDATED_RULE([MIT_LICENSE]) } });
        const listBox = findLicenseTypeListBox();
        expect(listBox.props('toggleText')).toBe(MIT_LICENSE);
      });

      it('displays the toggle text properly with multiple licenses selected', () => {
        createComponent({ props: { initRule: UPDATED_RULE([MIT_LICENSE, APACHE_LICENSE]) } });
        const listBox = findLicenseTypeListBox();
        expect(listBox.props('toggleText')).toBe('2 licenses');
      });

      it('falls back to the default toggle text when the selected license is not in the list', () => {
        createComponent({ props: { initRule: UPDATED_RULE(['non-existent-license']) } });
        const listBox = findLicenseTypeListBox();
        expect(listBox.props('toggleText')).toBe('Select license types');
      });
    });

    describe('multiple actions', () => {
      beforeEach(() => {
        createComponent();
      });

      it('can select single licence types', () => {
        findLicenseTypeListBox().vm.$emit('select', parsedSoftwareLicenses[0].value);
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ license_types: parsedSoftwareLicenses[0].value })],
        ]);
      });

      it('can select single all licence types', () => {
        findLicenseTypeListBox().vm.$emit('select-all');
        expect(wrapper.emitted('changed')).toEqual([
          [expect.objectContaining({ license_types: allLicenses.map(({ value }) => value) })],
        ]);
      });

      it('can clear all selected licence types', () => {
        createComponent();

        findLicenseTypeListBox().vm.$emit('select-all');
        findLicenseTypeListBox().vm.$emit('reset');

        expect(wrapper.emitted('changed')[1]).toEqual([
          expect.objectContaining({ license_types: [] }),
        ]);
      });
    });

    describe('removes filter', () => {
      it('remove filter types', () => {
        createComponent();

        findSectionLayout().vm.$emit('remove');

        expect(wrapper.emitted('remove')).toHaveLength(1);
      });
    });

    describe('error state', () => {
      it('renders error state', () => {
        createComponent({
          props: {
            hasError: true,
          },
        });

        expect(findSectionLayout().classes()).toContain('gl-border-red-400');
      });
    });
  });
});
