import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import AiCatalogItemConsumerDisclaimer from 'ee/ai/catalog/components/ai_catalog_item_consumer_disclaimer.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
} from 'ee/ai/catalog/constants';

describe('AiCatalogItemConsumerDisclaimer', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AiCatalogItemConsumerDisclaimer, {
      propsData: {
        itemType: AI_CATALOG_TYPE_AGENT,
        canEnable: true,
        ...props,
      },
      stubs: {
        GlAlert,
        HelpPageLink,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findHelpPageLink = () => wrapper.findComponent(HelpPageLink);

  describe('alert', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with info variant', () => {
      expect(findAlert().props('variant')).toBe('info');
    });

    it('renders as non-dismissible', () => {
      expect(findAlert().props('dismissible')).toBe(false);
    });
  });

  describe('agent disclaimer', () => {
    beforeEach(() => {
      createComponent({ itemType: AI_CATALOG_TYPE_AGENT });
    });

    it('displays enablement and access text', () => {
      expect(wrapper.text()).toContain(
        'When you enable this agent, all project members will be able to use it.',
      );
      expect(wrapper.text()).toContain(
        'When this agent runs, it will have access to the projects the user who runs it has access to.',
      );
    });

    it('renders the disclaimer as a two-item list', () => {
      expect(wrapper.findAll('ul li')).toHaveLength(2);
    });

    it('does not display composite identity link', () => {
      expect(findHelpPageLink().exists()).toBe(false);
    });
  });

  describe('flow disclaimer', () => {
    beforeEach(() => {
      createComponent({ itemType: AI_CATALOG_TYPE_FLOW });
    });

    it('displays composite identity text', () => {
      expect(wrapper.text()).toContain(
        'Enabling this flow creates a service account, which combines with a user role into a composite identity. The flow can access all projects that either the service account or the user role can access.',
      );
    });

    it('displays composite identity link', () => {
      expect(findHelpPageLink().props('href')).toBe('user/duo_agent_platform/composite_identity');
      expect(findHelpPageLink().text()).toBe('Learn more about composite identity.');
    });
  });

  describe('third-party flow disclaimer', () => {
    beforeEach(() => {
      createComponent({ itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW });
    });

    it('displays composite identity text', () => {
      expect(wrapper.text()).toContain(
        'Enabling this agent creates a service account, which combines with a user role into a composite identity. The agent can access all projects that either the service account or the user role can access.',
      );
    });

    it('displays composite identity link', () => {
      expect(findHelpPageLink().props('href')).toBe('user/duo_agent_platform/composite_identity');
    });
  });

  describe('when the user cannot enable', () => {
    it('shows the restricted message for agents', () => {
      createComponent({ itemType: AI_CATALOG_TYPE_AGENT, canEnable: false });

      expect(wrapper.text()).toContain(
        'You must have the Maintainer or Owner role to enable an agent in a project.',
      );
      expect(wrapper.text()).not.toContain('When you enable this agent');
    });

    it('shows the restricted message for flows', () => {
      createComponent({ itemType: AI_CATALOG_TYPE_FLOW, canEnable: false });

      expect(wrapper.text()).toContain(
        'You must have the Maintainer or Owner role to enable a flow in a project.',
      );
      expect(findHelpPageLink().exists()).toBe(false);
    });

    it('shows the restricted message for third-party flows', () => {
      createComponent({ itemType: AI_CATALOG_TYPE_THIRD_PARTY_FLOW, canEnable: false });

      expect(wrapper.text()).toContain(
        'You must have the Maintainer or Owner role to enable an agent in a project.',
      );
      expect(findHelpPageLink().exists()).toBe(false);
    });
  });
});
