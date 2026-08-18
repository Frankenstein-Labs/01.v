import { GlLabel, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FrameworksInfo from 'ee/compliance_dashboard/components/shared/frameworks_info.vue';
import { ROUTE_FRAMEWORKS } from 'ee/compliance_dashboard/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('ComplianceFrameworksInfo', () => {
  let wrapper;
  const routerPushMock = jest.fn();

  const frameworks = [
    { id: 1, name: 'Framework 1', color: '#FF0000' },
    { id: 2, name: 'Framework 2', color: '#00FF00' },
  ];
  const projectName = 'Test Project';
  const complianceCenterPath = '/compliance/center';

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(FrameworksInfo, {
      propsData: {
        frameworks,
        projectName,
        complianceCenterPath,
        ...props,
      },
      mocks: {
        $router: { push: routerPushMock },
      },
      stubs: {
        GlLabel,
      },
    });
  };

  const popover = () => wrapper.findComponent(GlPopover);
  const label = () => wrapper.findByTestId('frameworks-info-label');
  const frameworksLabels = () => wrapper.findAllByTestId('framework-label');
  const badge = () => wrapper.findComponentByTestId('single-framework-label');

  describe('rendering', () => {
    it('does not render components when there is no frameworks applied', () => {
      createComponent({ frameworks: [] });
      expect(badge().exists()).toBe(false);
      expect(label().exists()).toBe(false);
    });

    describe('single framework rendering', () => {
      beforeEach(() => {
        createComponent({ frameworks: [frameworks[0]] });
      });

      it('renders FrameworkBadge component when only one framework is applied', () => {
        expect(badge().exists()).toBe(true);
      });

      it('passes expected props', () => {
        expect(badge().props()).toMatchObject({
          closeable: false,
          framework: frameworks[0],
          showDefault: true,
          popoverMode: 'edit',
        });
      });

      it('passes correct popover mode prop to Badge component', () => {
        createComponent({ frameworks: [frameworks[0]], showEditSingleFramework: false });
        expect(badge().props('popoverMode')).toBe('details');
      });
    });

    describe('multiple frameworks rendering', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders label  with text', () => {
        expect(label().text()).toBe('Multiple frameworks');
      });

      it('renders GlPopover when multiple frameworks are applied', () => {
        expect(popover().exists()).toBe(true);
      });

      it('renders the correct number of framework labels', () => {
        expect(frameworksLabels()).toHaveLength(frameworks.length);
      });

      it('calls router push even when one of the badges is clicked', () => {
        frameworksLabels().at(0).trigger('click');
        expect(routerPushMock).toHaveBeenCalledWith({
          name: ROUTE_FRAMEWORKS,
          query: {
            id: getIdFromGraphQLId(frameworks[0].id),
          },
        });
      });

      it('renders the correct popover title', () => {
        expect(popover().props('title')).toBe(`Compliance frameworks applied to ${projectName}`);
      });
    });
  });
});
