import { GlButton, GlIcon } from '@gitlab/ui';
import ProjectToolCoverageDetails from 'ee/security_inventory/components/project_tool_coverage_details.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ProjectToolCoverageDetails', () => {
  let wrapper;
  const webUrl = '/group1/project1';

  const moreProps = {
    lastCall: '2025-01-01T00:00:00Z',
    buildId: 'gid://git/path/123',
    updatedAt: '2025-01-01T00:00:00Z',
  };

  const emptyAnalyzerStatus = [
    {
      analyzerType: 'SAST_IAC',
    },
  ];

  const singleAnalyzerStatus = [
    {
      analyzerType: 'DEPENDENCY_SCANNING',
      status: 'SUCCESS',
      ...moreProps,
    },
  ];

  const disabledAnalyzerStatus = [
    {
      analyzerType: 'DEPENDENCY_SCANNING',
      status: 'NOT_CONFIGURED',
      ...moreProps,
    },
  ];

  const multipleAnalyzerStatuses = [
    {
      analyzerType: 'SAST',
      status: 'SUCCESS',
      ...moreProps,
    },
    {
      analyzerType: 'SAST_ADVANCED',
      status: 'SUCCESS',
      ...moreProps,
    },
  ];

  const failedAnalyzerStatuses = [
    {
      analyzerType: 'SAST',
      status: 'FAILED',
      ...moreProps,
    },
    {
      analyzerType: 'SAST_ADVANCED',
      status: 'SUCCESS',
      ...moreProps,
    },
  ];

  const staleAnalyzerStatus = [
    {
      analyzerType: 'DEPENDENCY_SCANNING',
      status: 'STALE',
      ...moreProps,
    },
  ];

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ProjectToolCoverageDetails, {
      propsData: {
        securityScanner: multipleAnalyzerStatuses,
        webUrl,
        ...propsData,
      },
    });
  };

  const findAllGlIcons = () => wrapper.findAllComponents(GlIcon);
  const findGlIcon = () => wrapper.findComponent(GlIcon);
  const findByTestId = (id) => wrapper.findByTestId(id);
  const findButton = () => wrapper.findComponent(GlButton);

  describe('single scanner type', () => {
    it('renders the correct status label when the scanner is enabled', () => {
      createComponent({ securityScanner: singleAnalyzerStatus });
      expect(findByTestId('scanner-title-0').text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Enabled');
    });

    it('renders the correct status label when the scanner is disabled', () => {
      createComponent({
        securityScanner: [{ analyzerType: 'DEPENDENCY_SCANNING', status: 'DISABLED' }],
      });
      expect(findByTestId('scanner-title-0').text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Not enabled');
    });
  });

  describe('multiple scanners types', () => {
    it('renders multiple status labels when the scanners are enabled', () => {
      createComponent();

      const expectedTitles = ['Basic SAST:', 'GitLab Advanced SAST:'];
      expectedTitles.forEach((expectedTitle, index) => {
        expect(findByTestId(`scanner-title-${index}`).text()).toEqual(expectedTitle);
        expect(findByTestId(`scanner-status-${index}`).text()).toEqual('Enabled');
      });
    });

    it('renders multiple status labels when the scanners are not enabled', () => {
      createComponent({
        securityScanner: [{ analyzerType: 'SAST' }, { analyzerType: 'SAST_ADVANCED' }],
      });
      const expectedTitles = ['Basic SAST:', 'GitLab Advanced SAST:'];
      expectedTitles.forEach((expectedTitle, index) => {
        expect(findByTestId(`scanner-title-${index}`).text()).toEqual(expectedTitle);
        expect(findByTestId(`scanner-status-${index}`).text()).toEqual('Not enabled');
      });
    });

    it('renders mixed status labels when some scanners are enabled and some failed', () => {
      createComponent({ securityScanner: failedAnalyzerStatuses });
      expect(findByTestId('scanner-title-0').text()).toEqual('Basic SAST:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Failed');
      expect(findByTestId('scanner-title-1').text()).toEqual('GitLab Advanced SAST:');
      expect(findByTestId('scanner-status-1').text()).toEqual('Enabled');
    });
  });

  describe('empty security scanner', () => {
    it('renders default status when no security scanner data is provided', () => {
      createComponent({ securityScanner: emptyAnalyzerStatus });
      expect(findByTestId('scanner-title-0').text()).toEqual('Status:');
      expect(findByTestId('scanner-status-0').text()).toEqual('Not enabled');
    });
  });

  describe('icons', () => {
    it.each`
      name               | securityScanner           | expectedIconName         | expectedIconVariant
      ${'enabled'}       | ${singleAnalyzerStatus}   | ${'check-circle-filled'} | ${'success'}
      ${'disabled'}      | ${disabledAnalyzerStatus} | ${'clear'}               | ${'disabled'}
      ${'failed'}        | ${failedAnalyzerStatuses} | ${'status-failed'}       | ${'danger'}
      ${'stale'}         | ${staleAnalyzerStatus}    | ${'status-scheduled'}    | ${'subtle'}
      ${'never enabled'} | ${emptyAnalyzerStatus}    | ${'clear'}               | ${'disabled'}
    `(
      'renders correct icon when the scanner is $name',
      ({ securityScanner, expectedIconName, expectedIconVariant }) => {
        createComponent({ securityScanner });
        expect(findGlIcon().exists()).toBe(true);
        expect(findGlIcon().props('name')).toBe(expectedIconName);
        expect(findGlIcon().props('variant')).toBe(expectedIconVariant);
      },
    );

    it('displays correct number of icons for multiple scanners', () => {
      createComponent();
      expect(findAllGlIcons()).toHaveLength(2);
    });
  });

  describe('last scan', () => {
    it.each`
      name               | securityScanner           | expectedIconExists | expectedIconName
      ${'enabled'}       | ${singleAnalyzerStatus}   | ${false}           | ${null}
      ${'disabled'}      | ${disabledAnalyzerStatus} | ${false}           | ${null}
      ${'failed'}        | ${failedAnalyzerStatuses} | ${false}           | ${null}
      ${'never enabled'} | ${emptyAnalyzerStatus}    | ${true}            | ${'dash'}
    `(
      'renders last scan when the scanner is $name',
      ({ securityScanner, expectedIconExists, expectedIconName }) => {
        createComponent({ securityScanner });
        expect(findByTestId('last-scan-0').exists()).toBe(true);
        expect(findByTestId('last-scan-0').text()).toContain('Last scan:');
        const scanIcon = findByTestId('last-scan-0').findComponent(GlIcon);
        expect(scanIcon.exists()).toBe(expectedIconExists);
        if (expectedIconExists && expectedIconName) {
          expect(scanIcon.props('name')).toBe(expectedIconName);
        }
      },
    );
  });

  describe('data updated', () => {
    it.each`
      name               | securityScanner           | expectedTextExists
      ${'enabled'}       | ${singleAnalyzerStatus}   | ${true}
      ${'disabled'}      | ${disabledAnalyzerStatus} | ${true}
      ${'failed'}        | ${failedAnalyzerStatuses} | ${true}
      ${'never enabled'} | ${emptyAnalyzerStatus}    | ${false}
    `('renders last scan when the scanner is $name', ({ securityScanner, expectedTextExists }) => {
      createComponent({ securityScanner });
      expect(findByTestId('date-updated').exists()).toBe(expectedTextExists);
    });
  });

  describe('pipeline job path', () => {
    it.each`
      name               | securityScanner           | expectedTextContains | expectedIconExists | expectedIconName
      ${'enabled'}       | ${singleAnalyzerStatus}   | ${'Pipeline job: #'} | ${false}           | ${null}
      ${'disabled'}      | ${disabledAnalyzerStatus} | ${'Pipeline job: #'} | ${false}           | ${null}
      ${'failed'}        | ${failedAnalyzerStatuses} | ${'Pipeline job: #'} | ${false}           | ${null}
      ${'never enabled'} | ${emptyAnalyzerStatus}    | ${'Pipeline job:'}   | ${true}            | ${'dash'}
    `(
      'renders pipeline job path when the scanner is $name',
      ({ securityScanner, expectedTextContains, expectedIconExists, expectedIconName }) => {
        createComponent({ securityScanner });
        expect(findByTestId('pipeline-job-0').exists()).toBe(true);
        expect(findByTestId('pipeline-job-0').text()).toContain(expectedTextContains);
        const scanIcon = findByTestId('pipeline-job-0').findComponent(GlIcon);
        expect(scanIcon.exists()).toBe(expectedIconExists);
        if (expectedIconExists && expectedIconName) {
          expect(scanIcon.props('name')).toBe(expectedIconName);
        }
      },
    );
  });

  describe('manage configuration button', () => {
    it('renders "Manage configuration" button', () => {
      createComponent();
      expect(findButton().exists()).toBe(true);
      expect(findButton().text()).toBe('Manage configuration');
      expect(findButton().attributes('href')).toBe(`${webUrl}/-/security/configuration`);
      expect(findButton().props('category')).toBe('secondary');
      expect(findButton().props('variant')).toBe('confirm');
      expect(findButton().props('size')).toBe('small');
    });
  });
});
