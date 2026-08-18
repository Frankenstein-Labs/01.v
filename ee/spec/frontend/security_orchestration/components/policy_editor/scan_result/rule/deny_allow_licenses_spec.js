import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DenyAllowLicenses from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_licenses.vue';
import { UNKNOWN_LICENSE } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

describe('DenyAllowLicenses', () => {
  let wrapper;

  const LICENSE = { text: 'License', value: 'license' };

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(DenyAllowLicenses, {
      propsData: {
        allLicenses: [UNKNOWN_LICENSE],
        ...propsData,
      },
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);

  describe('default rendering', () => {
    it('renders default list with unknown license', () => {
      createComponent();

      expect(findListBox().props('items')).toEqual([
        { options: [UNKNOWN_LICENSE], text: 'Licenses' },
      ]);
      expect(findListBox().props('toggleText')).toBe('Choose or enter a license');
    });

    it('selects a license', () => {
      createComponent();

      findListBox().vm.$emit('select', UNKNOWN_LICENSE.value);

      expect(wrapper.emitted('select')).toEqual([[UNKNOWN_LICENSE]]);
    });

    it('renders selected license', () => {
      createComponent({
        propsData: { selected: LICENSE },
      });

      expect(findListBox().props('selected')).toEqual('license');
    });
  });

  describe('already selected licenses', () => {
    it('does not render licenses already selected in other dropdowns', () => {
      createComponent({
        propsData: {
          allLicenses: [UNKNOWN_LICENSE, LICENSE],
          alreadySelectedLicenses: [UNKNOWN_LICENSE],
        },
      });

      expect(findListBox().props('items')).toEqual([{ options: [LICENSE], text: 'Licenses' }]);
    });

    it('does not render selected licenses twice', () => {
      createComponent({
        propsData: {
          allLicenses: [UNKNOWN_LICENSE, LICENSE],
          selected: UNKNOWN_LICENSE,
        },
      });

      expect(findListBox().props('items')).toEqual([
        { text: 'Selected', options: [UNKNOWN_LICENSE] },
        { text: 'Licenses', options: [LICENSE] },
      ]);
    });

    it('searches through unselected licenses', async () => {
      createComponent({
        propsData: {
          allLicenses: [UNKNOWN_LICENSE, LICENSE],
        },
      });

      await findListBox().vm.$emit('search', 'unkn');

      expect(findListBox().props('items')).toEqual([
        { text: 'Licenses', options: [UNKNOWN_LICENSE] },
      ]);
    });

    it.each`
      title                   | licenses
      ${'without duplicates'} | ${[UNKNOWN_LICENSE, LICENSE]}
      ${'with duplicates'}    | ${[UNKNOWN_LICENSE, LICENSE, { text: 'License', value: 'license_1' }]}
    `('only renders selected section when all licenses selected $title', ({ licenses }) => {
      createComponent({
        propsData: {
          allLicenses: [UNKNOWN_LICENSE, LICENSE],
          selected: UNKNOWN_LICENSE,
          alreadySelectedLicenses: licenses,
        },
      });

      expect(findListBox().props('items')).toEqual([
        { text: 'Selected', options: [UNKNOWN_LICENSE] },
      ]);
    });
  });

  describe('custom license entry', () => {
    it('offers a custom license option when the search term matches no known license', async () => {
      createComponent({
        propsData: { allLicenses: [UNKNOWN_LICENSE, LICENSE] },
      });

      await findListBox().vm.$emit('search', 'Acme Internal License v2');

      expect(findListBox().props('items')).toEqual([
        {
          text: 'Custom license',
          options: [{ value: 'Acme Internal License v2', text: 'Add "Acme Internal License v2"' }],
        },
      ]);
    });

    it('emits the typed value as a license when the custom option is selected', async () => {
      createComponent({
        propsData: { allLicenses: [UNKNOWN_LICENSE, LICENSE] },
      });

      await findListBox().vm.$emit('search', 'Acme Internal License v2');
      findListBox().vm.$emit('select', 'Acme Internal License v2');

      expect(wrapper.emitted('select')).toEqual([
        [{ value: 'Acme Internal License v2', text: 'Acme Internal License v2' }],
      ]);
    });

    it('does not offer a custom option when the term matches an existing license name', async () => {
      createComponent({
        propsData: { allLicenses: [UNKNOWN_LICENSE, LICENSE] },
      });

      await findListBox().vm.$emit('search', LICENSE.text);

      expect(findListBox().props('items')).toEqual([{ text: 'Licenses', options: [LICENSE] }]);
    });

    it('does not offer a custom option when the term is already selected in another dropdown', async () => {
      createComponent({
        propsData: {
          allLicenses: [UNKNOWN_LICENSE, LICENSE],
          alreadySelectedLicenses: [
            { value: 'Acme Internal License v2', text: 'Acme Internal License v2' },
          ],
        },
      });

      await findListBox().vm.$emit('search', 'Acme Internal License v2');

      expect(findListBox().props('items')).toEqual([]);
    });
  });
});
