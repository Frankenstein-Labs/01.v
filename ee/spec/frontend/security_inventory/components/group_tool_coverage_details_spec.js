import GroupToolCoverageDetails from 'ee/security_inventory/components/group_tool_coverage_details.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('GroupToolCoverageDetails', () => {
  let wrapper;

  const moreProps = {
    updatedAt: '2025-01-01T00:00:00Z',
  };

  const emptyAnalyzerStatus = {
    analyzerType: 'SAST_IAC',
  };

  const enabledAnalyzerStatus = {
    analyzerType: 'SAST',
    failure: 0,
    notConfigured: 1,
    success: 2,
    ...moreProps,
  };

  const failedAnalyzerStatuses = {
    analyzerType: 'DEPENDENCY_SCANNING',
    failure: 3,
    notConfigured: 0,
    success: 0,
    ...moreProps,
  };

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(GroupToolCoverageDetails, {
      propsData: {
        securityScanner: propsData.securityScanner || enabledAnalyzerStatus,
      },
    });
  };

  const findByTestId = (id) => wrapper.findByTestId(id);
  const findIcon = (name) => wrapper.findComponentByTestId(`icon-${name}`);

  describe('single scanner type', () => {
    it('renders the correct status label when the scanner is enabled', () => {
      createComponent();
      expect(findByTestId('scanner-title-success').text()).toEqual('Enabled:');
      expect(findByTestId('scanner-status-success').text()).toEqual('2');
    });

    it('renders the correct status label when the scanner is disabled', () => {
      createComponent({
        securityScanner: failedAnalyzerStatuses,
      });
      expect(findByTestId('scanner-title-failure').text()).toEqual('Failed:');
      expect(findByTestId('scanner-status-failure').text()).toEqual('3');
    });
  });

  describe('empty security scanner', () => {
    it('renders default status when no security scanner data is provided', () => {
      createComponent({ securityScanner: emptyAnalyzerStatus });
      expect(findByTestId('scanner-title-notConfigured').text()).toEqual('Not enabled:');
      expect(findByTestId('scanner-status-notConfigured').text()).toEqual('');
    });
  });

  describe('icons', () => {
    it.each`
      name               | expectedIconName         | expectedIconVariant
      ${'success'}       | ${'check-circle-filled'} | ${'success'}
      ${'failure'}       | ${'status-failed'}       | ${'danger'}
      ${'stale'}         | ${'status-scheduled'}    | ${'subtle'}
      ${'notConfigured'} | ${'clear'}               | ${'disabled'}
    `(
      'renders correct icon when the scanner is $name',
      ({ name, expectedIconName, expectedIconVariant }) => {
        createComponent();
        expect(findIcon(name).exists()).toBe(true);
        expect(findIcon(name).props('name')).toBe(expectedIconName);
        expect(findIcon(name).props('variant')).toBe(expectedIconVariant);
      },
    );
  });

  describe('data updated', () => {
    it('renders data updated', () => {
      createComponent();
      expect(findByTestId('date-updated').exists()).toBe(true);
    });
  });
});
