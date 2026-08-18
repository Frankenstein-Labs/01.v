import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupToolCoverageIndicator from 'ee/security_inventory/components/group_tool_coverage_indicator.vue';
import GroupToolCoverageDetails from 'ee/security_inventory/components/group_tool_coverage_details.vue';
import { subgroupsAndProjects } from 'ee_jest/security_inventory/mock_data';

describe('GroupToolCoverageIndicator', () => {
  let wrapper;

  const mockGroup = subgroupsAndProjects.data.group.descendantGroups.nodes[0];
  const groupPath = mockGroup.path;

  const findScannerBar = (key) => wrapper.findComponentByTestId(`${key}-${groupPath}-bar`);
  const findScannerLabel = (key) => wrapper.findByTestId(`${key}-${groupPath}-label`).text();
  const findGroupToolCoverageDetails = () => wrapper.findComponent(GroupToolCoverageDetails);
  const findGroupToolCoverageDetailsAt = (i) =>
    wrapper.findAllComponents(GroupToolCoverageDetails).at(i);

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(GroupToolCoverageIndicator, {
      propsData: {
        item: {
          ...propsData,
          ...mockGroup,
          analyzerStatuses: propsData.analyzerStatuses || mockGroup.analyzerStatuses,
        },
      },
    });
  };

  describe('component rendering', () => {
    it('renders tool coverage details component in popovers', () => {
      createComponent();
      expect(findGroupToolCoverageDetails().exists()).toBe(true);
    });
  });

  describe('segments bar props', () => {
    it('passes correct segments prop to segmented bar when there are two scanner types', () => {
      createComponent();
      const key = 'SAST';
      expect(findScannerBar(key).props()).toStrictEqual({
        segments: [
          {
            class: 'gl-bg-green-500',
            count: 0,
          },
          {
            class: 'gl-bg-red-500',
            count: 1,
          },
          {
            class: 'gl-bg-neutral-600',
            count: 2,
          },
          {
            class: 'gl-bg-neutral-200',
            count: 3,
          },
        ],
      });

      const scannerLabel = findScannerLabel(key);
      expect(scannerLabel).toContain(key);
      expect(scannerLabel).toContain('Tool coverage: 1 of 3');
    });

    it('passes correct segments prop to segmented bar when there is one scanner type', () => {
      createComponent();
      const key = 'SAST_IAC';
      expect(findScannerBar(key).props()).toStrictEqual({
        segments: [
          {
            class: 'gl-bg-green-500',
            count: 1,
          },
          {
            class: 'gl-bg-red-500',
            count: 0,
          },
          {
            class: 'gl-bg-neutral-600',
            count: 2,
          },
          {
            class: 'gl-bg-neutral-200',
            count: 3,
          },
        ],
      });

      const scannerLabel = findScannerLabel(key);
      expect(scannerLabel).toContain('IaC');
      expect(scannerLabel).toContain('Tool coverage: 1 of 3');
    });

    it('passes correct segments prop to segmented bar when there is no scanner type', () => {
      createComponent();
      const key = 'DAST';
      expect(findScannerBar(key).props()).toStrictEqual({
        segments: [
          {
            class: 'gl-bg-green-500',
            count: 0,
          },
          {
            class: 'gl-bg-red-500',
            count: 0,
          },
          {
            class: 'gl-bg-neutral-600',
            count: 0,
          },
          {
            class: 'gl-bg-neutral-200',
            count: 0,
          },
        ],
      });

      const scannerLabel = findScannerLabel(key);
      expect(scannerLabel).toContain(key);
      expect(scannerLabel).toContain('Tool coverage: 0 of 0');
    });

    it.each`
      index | analyzerType             | expectedCounts
      ${0}  | ${'DEPENDENCY_SCANNING'} | ${{ failure: 0, notConfigured: 0, success: 0 }}
      ${1}  | ${'SAST'}                | ${{ failure: 1, notConfigured: 3, success: 0 }}
      ${2}  | ${'SECRET_DETECTION'}    | ${{ failure: 0, notConfigured: 3, success: 4 }}
      ${3}  | ${'CONTAINER_SCANNING'}  | ${{ failure: 0, notConfigured: 6, success: 1 }}
      ${4}  | ${'DAST'}                | ${{ failure: 0, notConfigured: 0, success: 0 }}
      ${5}  | ${'SAST_IAC'}            | ${{ failure: 0, notConfigured: 3, success: 1 }}
    `(
      'passes correct data to tool coverage details component for $analyzerType',
      ({ index, analyzerType, expectedCounts }) => {
        createComponent();
        expect(findGroupToolCoverageDetailsAt(index).props('securityScanner')).toMatchObject({
          analyzerType,
          ...expectedCounts,
        });
      },
    );
  });
});
