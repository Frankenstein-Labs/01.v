import { GlModal } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import LicenseOverridesModal from 'ee/security_orchestration/components/policy_editor/scan_result/rule/license_overrides_modal.vue';
import {
  MAX_LICENSE_OVERRIDES,
  OVERRIDE_MODE_PATCH,
  OVERRIDE_MODE_OVERWRITE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

const VALID_PURL = 'pkg:pypi/urllib3';
const INVALID_PURL = 'not-a-purl';

describe('LicenseOverridesModal', () => {
  let wrapper;

  const mockOverrides = [
    { purl: 'pkg:pypi/urllib3', license: 'MIT License', mode: OVERRIDE_MODE_PATCH },
    { purl: 'pkg:gem/rails', license: 'Apache-2.0', mode: OVERRIDE_MODE_OVERWRITE },
  ];

  const mockLicenses = [
    { value: 'MIT', text: 'MIT License' },
    { value: 'Apache-2.0', text: 'Apache License 2.0' },
    { value: 'GPL-3.0', text: 'GNU General Public License v3.0' },
  ];

  const createComponent = ({ props = {} } = {}) => {
    wrapper = mountExtended(LicenseOverridesModal, {
      propsData: {
        overrides: [],
        ...props,
      },
      provide: {
        parsedSoftwareLicenses: mockLicenses,
      },
      stubs: {
        GlModal: stubComponent(GlModal, { template: RENDER_ALL_SLOTS_TEMPLATE }),
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findAddButton = () => wrapper.findByTestId('add-override-btn');

  describe('show()', () => {
    it('initializes with one empty row when no overrides exist', () => {
      createComponent();
      wrapper.vm.show();

      expect(wrapper.vm.localOverrides).toHaveLength(1);
      expect(wrapper.vm.localOverrides[0].purl).toBe('');
      expect(wrapper.vm.localOverrides[0].license).toBe('');
      expect(wrapper.vm.localOverrides[0].mode).toBe(OVERRIDE_MODE_PATCH);
    });

    it('initializes with cloned overrides when overrides exist', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      expect(wrapper.vm.localOverrides).toHaveLength(2);
      expect(wrapper.vm.localOverrides[0].purl).toBe('pkg:pypi/urllib3');
      expect(wrapper.vm.localOverrides[1].license).toBe('Apache-2.0');
    });

    it('does not mutate the original overrides prop', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      wrapper.vm.localOverrides[0].purl = 'pkg:npm/changed';

      expect(mockOverrides[0].purl).toBe('pkg:pypi/urllib3');
    });
  });

  describe('rendering', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
    });

    it('renders the modal', () => {
      expect(findModal().exists()).toBe(true);
    });

    it('passes correct primary action props', () => {
      expect(findModal().props('actionPrimary').text).toBe('Save');
    });

    it('passes correct cancel action props', () => {
      expect(findModal().props('actionCancel').text).toBe('Cancel');
    });
  });

  describe('addRow', () => {
    it('adds a new empty row when add button is clicked', async () => {
      createComponent();
      wrapper.vm.show();
      await nextTick();

      const initialLength = wrapper.vm.localOverrides.length;
      await findAddButton().trigger('click');

      expect(wrapper.vm.localOverrides).toHaveLength(initialLength + 1);
      expect(wrapper.vm.localOverrides[initialLength].purl).toBe('');
    });

    it('disables the add button when the maximum number of overrides is reached', async () => {
      createComponent();
      wrapper.vm.show();
      wrapper.vm.localOverrides = Array.from({ length: MAX_LICENSE_OVERRIDES }, (_, i) => ({
        id: `override_${i}`,
        purl: `pkg:npm/package-${i}`,
        license: 'MIT',
        mode: 'patch',
      }));
      await nextTick();

      expect(findAddButton().attributes('aria-disabled')).toBe('true');
    });

    it('enables the add button below the maximum', async () => {
      createComponent();
      wrapper.vm.show();
      await nextTick();

      expect(findAddButton().attributes('aria-disabled')).toBeUndefined();
    });
  });

  describe('removeRow', () => {
    it('removes the row at the given index', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      wrapper.vm.removeRow(0);

      expect(wrapper.vm.localOverrides).toHaveLength(1);
      expect(wrapper.vm.localOverrides[0].purl).toBe('pkg:gem/rails');
    });
  });

  describe('onSave', () => {
    it('emits save with valid overrides only (filters empty rows)', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      wrapper.vm.addRow();
      wrapper.vm.onSave();

      const emitted = wrapper.emitted('save');
      expect(emitted).toHaveLength(1);
      expect(emitted[0][0]).toEqual([
        { purl: 'pkg:pypi/urllib3', license: 'MIT License', mode: OVERRIDE_MODE_PATCH },
        { purl: 'pkg:gem/rails', license: 'Apache-2.0', mode: OVERRIDE_MODE_OVERWRITE },
      ]);
    });

    it('defaults mode to patch when not set', () => {
      createComponent();
      wrapper.vm.show();

      wrapper.vm.localOverrides = [{ id: '1', purl: 'pkg:npm/foo', license: 'MIT', mode: '' }];
      wrapper.vm.onSave();

      const emitted = wrapper.emitted('save');
      expect(emitted[0][0][0].mode).toBe(OVERRIDE_MODE_PATCH);
    });

    it('strips internal id field from emitted overrides', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();
      wrapper.vm.onSave();

      const emitted = wrapper.emitted('save')[0][0];
      emitted.forEach((override) => {
        expect(override).not.toHaveProperty('id');
      });
    });

    it('does not emit save when duplicate purls exist', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      wrapper.vm.localOverrides[1].purl = 'pkg:pypi/urllib3';
      wrapper.vm.onSave();

      expect(wrapper.emitted('save')).toBeUndefined();
    });

    it('does not emit save when a purl has an invalid format', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      wrapper.vm.localOverrides[0].purl = INVALID_PURL;
      wrapper.vm.onSave();

      expect(wrapper.emitted('save')).toBeUndefined();
    });
  });

  describe('duplicate purl validation', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();
    });

    it('detects no duplicates when all purls are unique', () => {
      expect(wrapper.vm.duplicatePurls.size).toBe(0);
    });

    it('detects duplicate when two rows share the same purl', () => {
      wrapper.vm.localOverrides[1].purl = 'pkg:pypi/urllib3';

      expect(wrapper.vm.duplicatePurls.has('pkg:pypi/urllib3')).toBe(true);
    });

    it('does not flag empty purls as duplicates', () => {
      wrapper.vm.localOverrides[0].purl = '';
      wrapper.vm.localOverrides[1].purl = '';

      expect(wrapper.vm.duplicatePurls.size).toBe(0);
    });

    it('disables the save button when duplicates exist', async () => {
      wrapper.vm.localOverrides[1].purl = 'pkg:pypi/urllib3';
      await nextTick();

      expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
    });

    it('enables the save button when duplicates are resolved', async () => {
      wrapper.vm.localOverrides[1].purl = 'pkg:pypi/urllib3';
      await nextTick();

      wrapper.vm.localOverrides[1].purl = 'pkg:npm/lodash';
      await nextTick();

      expect(findModal().props('actionPrimary').attributes.disabled).toBe(false);
    });

    it('returns false from isPurlDuplicate for the duplicate purl', () => {
      wrapper.vm.localOverrides[1].purl = 'pkg:pypi/urllib3';

      expect(wrapper.vm.isPurlDuplicate('pkg:pypi/urllib3')).toBe(true);
    });

    it('returns false from isPurlDuplicate when purls are unique', () => {
      wrapper.vm.localOverrides.forEach(({ purl }) => {
        expect(wrapper.vm.isPurlDuplicate(purl)).toBe(false);
      });
    });
  });

  describe('selectLicense', () => {
    it('sets the license value at the given index', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      wrapper.vm.selectLicense(0, 'GPL-3.0');

      expect(wrapper.vm.localOverrides[0].license).toBe('GPL-3.0');
    });
  });

  describe('licenseItemsForRow', () => {
    it('returns all licenses when no search term', () => {
      createComponent();
      wrapper.vm.show();

      const items = wrapper.vm.licenseItemsForRow(0);

      expect(items).toHaveLength(mockLicenses.length);
    });

    it('filters licenses by search term', () => {
      createComponent();
      wrapper.vm.show();
      wrapper.vm.licenseSearchTerms = { 0: 'MIT' };

      const items = wrapper.vm.licenseItemsForRow(0);

      expect(items.some((l) => l.text.includes('MIT'))).toBe(true);
    });

    it('adds a custom entry when search term does not match any license', () => {
      createComponent();
      wrapper.vm.show();
      wrapper.vm.licenseSearchTerms = { 0: 'LicenseRef-Custom' };

      const items = wrapper.vm.licenseItemsForRow(0);

      expect(items[0].text).toContain('LicenseRef-Custom');
      expect(items[0].text).toContain('custom');
    });
  });

  describe('updateMode', () => {
    it('updates the mode at the given index', () => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();

      wrapper.vm.updateMode(0, OVERRIDE_MODE_OVERWRITE);

      expect(wrapper.vm.localOverrides[0].mode).toBe(OVERRIDE_MODE_OVERWRITE);
    });
  });

  describe('licenseToggleText', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();
    });

    it('returns the license value when a license is set', () => {
      expect(wrapper.vm.licenseToggleText(0)).toBe('MIT License');
    });

    it('returns a placeholder when no license is set', () => {
      wrapper.vm.localOverrides[0].license = '';

      expect(wrapper.vm.licenseToggleText(0)).toBe('Choose a license');
    });
  });

  describe('selectedLicenseValue', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();
    });

    it('returns the license value when a license is set', () => {
      expect(wrapper.vm.selectedLicenseValue(0)).toBe('MIT License');
    });

    it('returns an empty string when no license is set', () => {
      wrapper.vm.localOverrides[0].license = '';

      expect(wrapper.vm.selectedLicenseValue(0)).toBe('');
    });
  });

  describe('setLicenseSearchTerm', () => {
    beforeEach(() => {
      createComponent();
      wrapper.vm.show();
    });

    it('sets the search term for the given row index', () => {
      wrapper.vm.setLicenseSearchTerm(0, 'MIT');

      expect(wrapper.vm.licenseSearchTerms[0]).toBe('MIT');
    });

    it('trims whitespace from the search term', () => {
      wrapper.vm.setLicenseSearchTerm(0, '  Apache  ');

      expect(wrapper.vm.licenseSearchTerms[0]).toBe('Apache');
    });

    it('preserves search terms for other rows', () => {
      wrapper.vm.setLicenseSearchTerm(0, 'MIT');
      wrapper.vm.setLicenseSearchTerm(1, 'GPL');

      expect(wrapper.vm.licenseSearchTerms[0]).toBe('MIT');
      expect(wrapper.vm.licenseSearchTerms[1]).toBe('GPL');
    });
  });

  describe('hasFormatErrors', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();
    });

    it('is false when all purls are valid', () => {
      expect(wrapper.vm.hasFormatErrors).toBe(false);
    });

    it('is true when a purl has an invalid format', () => {
      wrapper.vm.localOverrides[0].purl = INVALID_PURL;

      expect(wrapper.vm.hasFormatErrors).toBe(true);
    });

    it('is false when a purl is empty', () => {
      wrapper.vm.localOverrides[0].purl = '';

      expect(wrapper.vm.hasFormatErrors).toBe(false);
    });

    it('disables the save button when a format error exists', async () => {
      wrapper.vm.localOverrides[0].purl = INVALID_PURL;
      await nextTick();

      expect(findModal().props('actionPrimary').attributes.disabled).toBe(true);
    });
  });

  describe('purlState', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();
    });

    it('returns null for an empty purl', () => {
      wrapper.vm.localOverrides[0].purl = '';

      expect(wrapper.vm.purlState(0)).toBeNull();
    });

    it('returns false for an invalid purl format', () => {
      wrapper.vm.localOverrides[0].purl = INVALID_PURL;

      expect(wrapper.vm.purlState(0)).toBe(false);
    });

    it('returns false for a duplicate purl', () => {
      wrapper.vm.localOverrides[1].purl = VALID_PURL;

      expect(wrapper.vm.purlState(0)).toBe(false);
    });

    it('returns true for a valid unique purl', () => {
      expect(wrapper.vm.purlState(0)).toBe(true);
    });
  });

  describe('purlErrorMessage', () => {
    beforeEach(() => {
      createComponent({ props: { overrides: mockOverrides } });
      wrapper.vm.show();
    });

    it('returns empty string for an empty purl', () => {
      wrapper.vm.localOverrides[0].purl = '';

      expect(wrapper.vm.purlErrorMessage(0)).toBe('');
    });

    it('returns a format error for an invalid purl', () => {
      wrapper.vm.localOverrides[0].purl = INVALID_PURL;

      expect(wrapper.vm.purlErrorMessage(0)).toContain('pkg:pypi/urllib3');
    });

    it('returns a duplicate error when the purl is duplicated', () => {
      wrapper.vm.localOverrides[1].purl = VALID_PURL;

      expect(wrapper.vm.purlErrorMessage(0)).toContain('Duplicate');
    });

    it('returns empty string for a valid unique purl', () => {
      expect(wrapper.vm.purlErrorMessage(0)).toBe('');
    });
  });
});
