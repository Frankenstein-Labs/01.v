import { shallowMount } from '@vue/test-utils';
import { GlIcon, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from 'ee/ai/catalog/constants';

describe('FoundationalIcon', () => {
  let wrapper;

  const defaultProps = {
    resourceId: 'gid://gitlab/Ai::Catalog::Item/1',
    itemType: AI_CATALOG_TYPE_AGENT,
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMount(FoundationalIcon, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);

  const findPrintText = () => wrapper.findComponent(GlSprintf);

  beforeEach(() => {
    createComponent();
  });

  it('uses tanuki-verified icon', () => {
    expect(findIcon().props('name')).toBe('tanuki-verified');
  });

  it('renders icon with correct id based on resourceId', () => {
    expect(findIcon().attributes('id')).toBe('1-foundational-icon');
  });

  it('renders with custom size', () => {
    createComponent({ size: 16 });
    expect(findIcon().props('size')).toBe(16);
  });

  it('renders with default size', () => {
    expect(findIcon().props('size')).toBe(24);
  });

  describe('popover', () => {
    it('renders popover with correct target', () => {
      expect(findPopover().props('target')).toBe('1-foundational-icon');
    });

    it('renders popover content with GitLab text', () => {
      expect(findPrintText().attributes('message')).toBe(
        'Created and maintained by %{boldStart}GitLab%{boldEnd}',
      );
    });

    describe('when itemType is AGENT', () => {
      beforeEach(() => {
        createComponent({ itemType: AI_CATALOG_TYPE_AGENT });
      });

      it('renders help page link', () => {
        const link = findLink();

        expect(link.props('href')).toBe(
          '/help/user/duo_agent_platform/agents/foundational_agents/_index.md',
        );
        expect(link.text()).toBe('Learn more about foundational agents');
      });
    });

    describe('when itemType is FOUNDATIONAL_AGENT', () => {
      beforeEach(() => {
        createComponent({ itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT });
      });

      it('renders help page link', () => {
        const link = findLink();

        expect(link.props('href')).toBe(
          '/help/user/duo_agent_platform/agents/foundational_agents/_index.md',
        );
        expect(link.text()).toBe('Learn more about foundational agents');
      });
    });

    describe('when itemType is FLOW', () => {
      beforeEach(() => {
        createComponent({ itemType: AI_CATALOG_TYPE_FLOW });
      });

      it('renders help page link', () => {
        const link = findLink();

        expect(link.props('href')).toBe(
          '/help/user/duo_agent_platform/flows/foundational_flows/_index.md',
        );
        expect(link.text()).toBe('Learn more about foundational flows');
      });
    });

    it('does not render link when itemType is invalid', () => {
      createComponent({ itemType: 'INVALID_TYPE' });

      expect(findLink().exists()).toBe(false);
    });
  });
});
