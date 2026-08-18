import {
  GlCard,
  GlLoadingIcon,
  GlFormCheckbox,
  GlFormGroup,
  GlDisclosureDropdown,
} from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EnableScannersSelectScanners from 'ee/security_configuration/components/enable_scanners_wizard/select_scanners.vue';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import { APPROACH_QUICK } from 'ee/security_configuration/components/enable_scanners_wizard/constants';
import { mockScanner, mockScanner2 } from '../scan_profiles/mock_data';

describe('EnableScannersSelectScanners', () => {
  let wrapper;
  let enableScanners;

  const sastProfile = mockScanner2;
  const secretProfile = mockScanner;
  const defaultProfilesByScanType = {
    SAST: [sastProfile],
    SECRET_DETECTION: [secretProfile],
  };
  const allScanTypes = Object.keys(defaultProfilesByScanType);

  const createComponent = ({
    approach = APPROACH_QUICK,
    isLoadingAvailableScanners = false,
    selectedScanners = [],
    profilesByScanType = defaultProfilesByScanType,
    activeProfileForScanType = (scanType) =>
      selectedScanners.find((scanner) => scanner.scanType === scanType) ??
      profilesByScanType[scanType]?.[0],
    toggleScanner = jest.fn(),
    toggleAllScanners = jest.fn(),
    selectScannerProfile = jest.fn(),
  } = {}) => {
    enableScanners = {
      approach,
      isLoadingAvailableScanners,
      profilesByScanType,
      allScanTypes: Object.keys(profilesByScanType),
      selectedScanners,
      activeProfileForScanType,
      toggleScanner,
      toggleAllScanners,
      selectScannerProfile,
    };

    wrapper = shallowMountExtended(EnableScannersSelectScanners, {
      provide: { enableScanners },
      stubs: { GlCard, GlFormGroup },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findSelectAllCheckbox = () => findCheckboxes().at(0);
  const findCardCheckboxes = () => findCheckboxes().wrappers.slice(1);
  const findCards = () => wrapper.findAllComponents(GlCard);
  const findDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findPreviewLink = () => wrapper.findAllComponentsByTestId('preview-profile-link').at(0);
  const findPreviewModal = () => wrapper.findComponent(ScanProfileDetailsModal);

  it('shows a loading icon while available scanners are loading', () => {
    createComponent({ isLoadingAvailableScanners: true });

    expect(findLoadingIcon().exists()).toBe(true);
    expect(findCards()).toHaveLength(0);
  });

  describe('select all scanners checkbox header', () => {
    it('is checked when every scan type is selected', () => {
      createComponent({ selectedScanners: [sastProfile, secretProfile] });

      expect(findSelectAllCheckbox().props('checked')).toBe(true);
    });

    it('is indeterminate when only some scan types are selected', () => {
      createComponent({ selectedScanners: [sastProfile] });

      expect(findSelectAllCheckbox().props('checked')).toBe(false);
      expect(findSelectAllCheckbox().props('indeterminate')).toBe(true);
    });

    it('calls toggleAllScanners on change', () => {
      const toggleAllScanners = jest.fn();
      createComponent({ toggleAllScanners });

      findSelectAllCheckbox().vm.$emit('change', true);

      expect(toggleAllScanners).toHaveBeenCalledWith(true);
    });

    it('shows the count of selected scan types out of the total', () => {
      createComponent({ selectedScanners: [sastProfile] });

      expect(wrapper.text()).toContain('1 of 2 selected');
    });
  });

  describe('scanner cards', () => {
    it('renders a card for each scan type', () => {
      createComponent();

      expect(findCards()).toHaveLength(allScanTypes.length);
    });

    it('shows a checkbox to select each scanner', () => {
      createComponent();

      expect(findCardCheckboxes()).toHaveLength(allScanTypes.length);
    });

    it('calls toggleScanner with the scan type when a card checkbox changes', () => {
      const toggleScanner = jest.fn();
      createComponent({ toggleScanner });

      findCardCheckboxes()[0].vm.$emit('change', true);

      expect(toggleScanner).toHaveBeenCalledWith('SAST', true);
    });
  });

  describe('profile dropdown', () => {
    it('shows the active profile name', () => {
      createComponent();

      expect(findDropdowns().at(0).props('toggleText')).toBe(sastProfile.name);
    });

    it('disables the dropdown when the scan type is not selected', () => {
      createComponent({ selectedScanners: [] });

      expect(findDropdowns().at(0).props('disabled')).toBe(true);
    });

    it('calls selectScannerProfile when a profile is chosen', () => {
      const selectScannerProfile = jest.fn();
      createComponent({ selectScannerProfile });

      const dropdown = findDropdowns().at(0);
      const chosenItem = dropdown.props('items')[0];
      dropdown.vm.$emit('action', chosenItem);

      expect(selectScannerProfile).toHaveBeenCalledWith('SAST', sastProfile);
    });

    it('shows the selected profile name when a non-default profile is selected', () => {
      const customSastProfile = {
        ...sastProfile,
        id: 'gid://gitlab/Security::ScanProfile/99',
        name: 'SAST Custom A',
      };

      createComponent({
        profilesByScanType: {
          SAST: [sastProfile, customSastProfile],
          SECRET_DETECTION: [secretProfile],
        },
        selectedScanners: [customSastProfile],
      });

      expect(findDropdowns().at(0).props('toggleText')).toBe(customSastProfile.name);
    });
  });

  describe('profile preview link', () => {
    it('opens the preview modal for the chosen profile when clicked', async () => {
      createComponent();

      await findPreviewLink().vm.$emit('click');

      expect(findPreviewModal().props()).toMatchObject({
        visible: true,
        profileId: sastProfile.id,
        scanType: 'SAST',
      });
    });

    it('closes the preview modal on the modal close event', async () => {
      createComponent();

      await findPreviewLink().vm.$emit('click');
      await findPreviewModal().vm.$emit('close');

      expect(findPreviewModal().props('visible')).toBe(false);
    });
  });
});
