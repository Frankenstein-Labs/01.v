import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EnableScannersReview from 'ee/security_configuration/components/enable_scanners_wizard/review.vue';
import ScanProfileDetailsModal from 'ee/security_configuration/components/scan_profiles/scan_profile_details_modal.vue';
import { APPROACH_QUICK } from 'ee/security_configuration/components/enable_scanners_wizard/constants';

describe('EnableScannersReview', () => {
  let wrapper;
  let enableScanners;

  const selectedItems = [
    { id: 'gid://gitlab/Project/1', name: 'Project 1', group: { name: 'Group A', webPath: '/a' } },
    { id: 'gid://gitlab/Project/2', name: 'Project 2', group: { name: 'Group B', webPath: '/b' } },
    { id: 'gid://gitlab/Project/3', name: 'Project 3', group: { name: 'Group B', webPath: '/b' } },
  ];
  const selectedScanners = [
    { id: 'gid://gitlab/Security::ScanProfile/1', name: 'SAST Profile', scanType: 'SAST' },
    {
      id: 'gid://gitlab/Security::ScanProfile/2',
      name: 'Secret Detection Profile',
      scanType: 'SECRET_DETECTION',
    },
  ];

  const createComponent = ({
    approach = APPROACH_QUICK,
    selectedItems: items = [],
    selectedScanners: scanners = [],
    areAllItemsSelected = false,
    stubs = {},
  } = {}) => {
    enableScanners = {
      approach,
      selectedItems: items,
      selectedScanners: scanners,
      areAllItemsSelected,
    };

    wrapper = shallowMountExtended(EnableScannersReview, {
      provide: { enableScanners },
      stubs,
    });
  };

  const findItemsImpactedStat = () => wrapper.findComponentByTestId('items-impacted-stat');
  const findScannersConfiguredStat = () =>
    wrapper.findComponentByTestId('scanners-configured-stat');
  const findItemsTable = () => wrapper.findComponentByTestId('items-table');
  const findScannersTable = () => wrapper.findComponentByTestId('scanners-table');
  const findPreviewModal = () => wrapper.findComponent(ScanProfileDetailsModal);
  const findProfilePreviewLink = () => wrapper.findComponentByTestId('preview-profile-link');

  describe('summary stats', () => {
    it('shows "All" for items impacted when all items are selected', () => {
      createComponent({ areAllItemsSelected: true });

      expect(findItemsImpactedStat().props('value')).toBe('All');
    });

    it('shows the selected item count for items impacted otherwise', () => {
      createComponent({ selectedItems });

      expect(findItemsImpactedStat().props('value')).toBe('3');
    });

    it('shows the selected scanner count for scanners configured', () => {
      createComponent({ selectedScanners });

      expect(findScannersConfiguredStat().props('value')).toBe(2);
    });
  });

  describe('items card', () => {
    it('shows the "all uncovered projects are selected" message when all items are selected', () => {
      createComponent({ areAllItemsSelected: true });

      expect(wrapper.text()).toContain('All uncovered projects are selected.');
      expect(findItemsTable().exists()).toBe(false);
    });

    it('renders a table row per selected item otherwise', () => {
      createComponent({ selectedItems });

      expect(findItemsTable().props('items')).toBe(selectedItems);
    });
  });

  describe('scanners card', () => {
    it('renders a table row per selected scanner', () => {
      createComponent({ selectedScanners });

      expect(findScannersTable().props('items')).toBe(selectedScanners);
    });
  });

  describe('profile preview', () => {
    beforeEach(() => {
      createComponent({
        selectedScanners,
        stubs: {
          // stub name cell so we can test link inside it
          GlTableLite: {
            props: ['items', 'fields'],
            template: `
              <div>
                <div v-for="(item, index) in items" :key="index">
                  <slot name="cell(name)" :item="item" />
                </div>
              </div>
            `,
          },
        },
      });
    });

    it('opens the preview modal for the clicked profile', async () => {
      await findProfilePreviewLink().vm.$emit('click');

      expect(findPreviewModal().props()).toMatchObject({
        visible: true,
        profileId: selectedScanners[0].id,
        scanType: selectedScanners[0].scanType,
      });
    });

    it('closes the preview modal on the modal close event', async () => {
      await findProfilePreviewLink().vm.$emit('click');
      await findPreviewModal().vm.$emit('close');

      expect(findPreviewModal().props('visible')).toBe(false);
    });
  });
});
