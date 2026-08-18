import { GlAvatar, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NamespaceMetadata from 'ee/analytics/analytics_dashboards/components/visualizations/namespace_metadata.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { mockGroupNamespaceMetadata } from 'ee_jest/analytics/analytics_dashboards/mock_data';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';

describe('Namespace Metadata Visualization', () => {
  let wrapper;

  const defaultProps = { data: mockGroupNamespaceMetadata };

  const createWrapper = ({ props = defaultProps } = {}) => {
    wrapper = shallowMountExtended(NamespaceMetadata, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        ...props,
      },
    });
  };

  const findNamespaceAvatar = () => wrapper.findComponent(GlAvatar);
  const findNamespaceTypeIcon = () =>
    wrapper.findComponentByTestId('namespace-metadata-namespace-type-icon');
  const findNamespaceVisibilityButton = () =>
    wrapper.findByTestId('namespace-metadata-visibility-button');
  const findNamespaceVisibilityButtonIcon = () =>
    findNamespaceVisibilityButton().findComponent(GlIcon);
  const findTooltipOnTruncate = () => wrapper.findComponent(TooltipOnTruncate);

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it("should render namespace's truncated full name", () => {
      expect(findTooltipOnTruncate().text()).toBe('GitLab Org');
      expect(findTooltipOnTruncate().props()).toMatchObject({
        title: 'GitLab Org',
        boundary: 'viewport',
      });
    });

    it('should render namespace type', () => {
      expect(wrapper.findByText('Group').exists()).toBe(true);
    });

    it('should render namespace type icon', () => {
      expect(findNamespaceTypeIcon().props()).toMatchObject({
        name: 'group',
        variant: 'subtle',
      });
    });

    it('should render avatar', () => {
      expect(findNamespaceAvatar().props()).toMatchObject({
        entityName: 'GitLab Org',
        entityId: 225,
        src: '/avatar.png',
        shape: 'rect',
        fallbackOnError: true,
        size: 48,
        alt: `GitLab Org's avatar`,
      });
    });

    it('should render accessible visibility level icon', () => {
      const tooltip = getBinding(findNamespaceVisibilityButton().element, 'gl-tooltip');

      expect(tooltip).toBeDefined();

      expect(findNamespaceVisibilityButton().attributes()).toMatchObject({
        title:
          'Public - The group and any public projects can be viewed without any authentication.',
        'aria-label':
          'Public - The group and any public projects can be viewed without any authentication.',
      });
      expect(findNamespaceVisibilityButtonIcon().props()).toMatchObject({
        name: 'earth',
        variant: 'subtle',
      });
    });
  });
});
