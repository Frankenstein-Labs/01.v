import { GlLabel, GlButton, GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { visitUrl } from '~/lib/utils/url_utility';

import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';

import { ROUTE_EDIT_FRAMEWORK, ROUTE_FRAMEWORKS } from 'ee/compliance_dashboard/constants';
import { complianceFramework } from '../../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('FrameworkBadge component', () => {
  let wrapper;
  let routerPushMock;

  const findLabel = () => wrapper.findComponent(GlLabel);
  const findTooltip = () => wrapper.findComponent(GlPopover);
  const findCtaButton = () => wrapper.findComponent(GlPopover).findComponent(GlButton);

  const createComponent = (props = {}, provide = {}) => {
    routerPushMock = jest.fn();
    return shallowMount(FrameworkBadge, {
      propsData: {
        ...props,
      },
      provide: {
        namespaceId: 'gid://gitlab/Group/1',
        ...provide,
      },
      mocks: {
        $router: { push: routerPushMock },
      },
    });
  };

  describe('popover modes', () => {
    it('renders edit button in edit mode', () => {
      wrapper = createComponent({ framework: complianceFramework, popoverMode: 'edit' });

      expect(findCtaButton().text()).toBe('Edit the framework');
    });

    it('renders view details button in details mode', () => {
      wrapper = createComponent({ framework: complianceFramework, popoverMode: 'details' });

      expect(findCtaButton().text()).toBe('View the framework details');
    });

    it('renders disabled view details button in disabled mode', () => {
      wrapper = createComponent({ framework: complianceFramework, popoverMode: 'disabled' });

      const button = findCtaButton();
      expect(button.text()).toBe('View the framework details');
      expect(button.props('disabled')).toBe(true);
    });

    it('shows disabled message in disabled mode', () => {
      wrapper = createComponent({ framework: complianceFramework, popoverMode: 'disabled' });

      expect(findTooltip().text()).toContain(
        'Only group owners and maintainers can view the framework details',
      );
    });

    it('does not render popover in hidden mode', () => {
      wrapper = createComponent({ framework: complianceFramework, popoverMode: 'hidden' });

      expect(findTooltip().exists()).toBe(false);
    });
  });

  describe('CSP framework detection', () => {
    it('shows CSP framework message when framework is from different namespace', () => {
      const cspFramework = {
        ...complianceFramework,
        namespaceId: 'gid://gitlab/Group/2',
      };

      wrapper = createComponent(
        { framework: cspFramework, popoverMode: 'details' },
        { namespaceId: 'gid://gitlab/Group/1' },
      );

      expect(findTooltip().text()).toContain('Instance level compliance framework');
    });

    it('does not show CSP framework message when framework is from same namespace', () => {
      const localFramework = {
        ...complianceFramework,
        namespaceId: 'gid://gitlab/Group/1',
      };

      wrapper = createComponent(
        { framework: localFramework, popoverMode: 'details' },
        { namespaceId: 'gid://gitlab/Group/1' },
      );

      expect(findTooltip().text()).not.toContain('Instance level compliance framework');
    });

    it('does not show CSP framework message when framework has no namespaceId', () => {
      const frameworkWithoutNamespace = {
        ...complianceFramework,
        namespaceId: null,
      };

      wrapper = createComponent(
        { framework: frameworkWithoutNamespace, popoverMode: 'details' },
        { namespaceId: 'gid://gitlab/Group/1' },
      );

      expect(findTooltip().text()).not.toContain('Instance level compliance framework');
    });

    it('does not show CSP framework message when namespaceId is not injected', () => {
      const cspFramework = {
        ...complianceFramework,
        namespaceId: 'gid://gitlab/Group/2',
      };

      wrapper = createComponent(
        { framework: cspFramework, popoverMode: 'details' },
        { namespaceId: null },
      );

      expect(findTooltip().text()).not.toContain('Instance level compliance framework');
    });

    it('correctly identifies CSP framework using numeric IDs', () => {
      const cspFramework = {
        ...complianceFramework,
        namespaceId: 'gid://gitlab/Group/999',
      };

      wrapper = createComponent(
        { framework: cspFramework, popoverMode: 'details' },
        { namespaceId: 'gid://gitlab/Group/123' },
      );

      expect(wrapper.vm.isCSPFramework).toBe(true);
      expect(findTooltip().text()).toContain('Instance level compliance framework');
    });
  });

  describe('navigation behavior', () => {
    it('navigates to edit page when edit button is clicked', async () => {
      wrapper = createComponent({ framework: complianceFramework, popoverMode: 'edit' });

      await findCtaButton().vm.$emit('click', new MouseEvent('click'));
      expect(routerPushMock).toHaveBeenCalledWith({
        name: ROUTE_EDIT_FRAMEWORK,
        params: {
          id: getIdFromGraphQLId(complianceFramework.id),
        },
      });
    });

    it('navigates to framework details when view details is clicked', async () => {
      wrapper = createComponent({ framework: complianceFramework, popoverMode: 'details' });

      await findCtaButton().vm.$emit('click', new MouseEvent('click'));
      expect(routerPushMock).toHaveBeenCalledWith({
        name: ROUTE_FRAMEWORKS,
        query: {
          id: getIdFromGraphQLId(complianceFramework.id),
        },
      });
    });

    it('navigates to viewDetailsUrl when provided', async () => {
      const viewDetailsUrl = 'http://example.com/framework-details';
      wrapper = createComponent({
        framework: complianceFramework,
        popoverMode: 'details',
        viewDetailsUrl,
      });

      await findCtaButton().vm.$emit('click', new MouseEvent('click'));
      expect(visitUrl).toHaveBeenCalledWith(viewDetailsUrl);
      expect(routerPushMock).not.toHaveBeenCalled();
    });
  });

  describe('label rendering', () => {
    it('renders the framework label', () => {
      wrapper = createComponent({ framework: complianceFramework });

      expect(findLabel().props()).toMatchObject({
        backgroundColor: '#009966',
        title: complianceFramework.name,
      });
      expect(findTooltip().text()).toContain(complianceFramework.description);
    });

    it('renders the default addition when the framework is default', () => {
      wrapper = createComponent({ framework: { ...complianceFramework, default: true } });

      expect(findLabel().props('title')).toEqual(`${complianceFramework.name} (default)`);
    });

    it('renders the truncated text when the framework name is long', () => {
      wrapper = createComponent({
        framework: {
          ...complianceFramework,
          name: 'A really long standard regulation name that will not fit in one line',
          default: false,
        },
      });

      expect(findLabel().props('title')).toEqual('A really long standard regulat...');
    });

    it('does not render the default addition when the framework is default but component is configured to hide the badge', () => {
      wrapper = createComponent({
        framework: { ...complianceFramework, default: true },
        showDefault: false,
      });

      expect(findLabel().props('title')).toEqual(complianceFramework.name);
    });

    it('does not render the default addition when the framework is not default', () => {
      wrapper = createComponent({ framework: complianceFramework });

      expect(findLabel().props('title')).toEqual(complianceFramework.name);
    });

    it('renders closeable label when closeable is true', () => {
      wrapper = createComponent({ framework: complianceFramework, closeable: true });

      expect(findLabel().props('showCloseButton')).toBe(true);
    });

    it('emits close event when label close button is clicked', async () => {
      wrapper = createComponent({ framework: complianceFramework, closeable: true });

      await findLabel().vm.$emit('close');
      expect(wrapper.emitted('close')).toHaveLength(1);
    });
  });
});
