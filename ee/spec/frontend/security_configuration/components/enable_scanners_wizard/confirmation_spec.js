import { GlEmptyState, GlButton, GlSprintf, GlTable } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import EnableScannersConfirmation from 'ee/security_configuration/components/enable_scanners_wizard/confirmation.vue';

describe('EnableScannersConfirmation', () => {
  let wrapper;

  const selectedScanners = [
    { id: 'gid://gitlab/Security::ScanProfile/1', name: 'SAST Profile', scanType: 'SAST' },
    {
      id: 'gid://gitlab/Security::ScanProfile/2',
      name: 'Secret Detection Profile',
      scanType: 'SECRET_DETECTION',
    },
  ];

  const createComponent = ({
    areAllItemsSelected = false,
    selectedItems = [],
    selectedScanners: scanners = [],
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(EnableScannersConfirmation, {
      provide: {
        enableScanners: { areAllItemsSelected, selectedItems, selectedScanners: scanners },
      },
      stubs: { GlEmptyState, GlSprintf, GlTable, GlButton: true, ScanTypeCell: true },
    });
  };

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findButton = () => wrapper.findComponent(GlButton);
  const findTableRows = () => wrapper.findAll('tbody tr');
  const findItemsCell = (row) => row.findAll('td').at(2);

  beforeEach(() => {
    createComponent();
  });

  it('renders a "Go to security configuration" link-button to the root route', () => {
    expect(findButton().text()).toBe('Go to security configuration');
    expect(findButton().attributes('to')).toBe('/');
  });

  describe('rollout message', () => {
    it('renders the correct message when all items are selected', () => {
      createComponent({ areAllItemsSelected: true });

      expect(findEmptyState().props()).toMatchObject({
        title: 'Security scanning is rolling out',
      });
      expect(findEmptyState().text()).toContain('all uncovered projects');
    });

    it('renders the correct message when specific items are selected', () => {
      createComponent({ selectedItems: [{ id: 1 }, { id: 2 }] });

      expect(findEmptyState().props()).toMatchObject({
        title: 'Security scanning is rolling out',
      });
      expect(findEmptyState().text()).toContain('2 items');
    });
  });

  describe('configuration applied summary', () => {
    it('renders a row per selected scanner with its scan type and profile name', () => {
      createComponent({ selectedScanners, mountFn: mountExtended });

      const rows = findTableRows();
      expect(rows).toHaveLength(selectedScanners.length);
      expect(rows.at(0).text()).toContain('SAST Profile');
      expect(rows.at(1).text()).toContain('Secret Detection Profile');
    });

    it('shows "All" in the items cell when all items are selected', () => {
      createComponent({ areAllItemsSelected: true, selectedScanners, mountFn: mountExtended });

      expect(findItemsCell(findTableRows().at(0)).text()).toBe('All');
    });

    it('shows the selected project count in the items cell otherwise', () => {
      createComponent({
        selectedItems: [{ id: 1 }, { id: 2 }, { id: 3 }],
        selectedScanners,
        mountFn: mountExtended,
      });

      expect(findItemsCell(findTableRows().at(0)).text()).toBe('3');
    });
  });
});
