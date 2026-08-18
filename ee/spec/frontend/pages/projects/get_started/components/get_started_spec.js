import { GlCard, GlAlert } from '@gitlab/ui';
import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GetStarted from 'ee/pages/projects/get_started/components/get_started.vue';
import SectionHeader from 'ee/pages/projects/get_started/components/section_header.vue';
import SectionBody from 'ee/pages/projects/get_started/components/section_body.vue';
import eventHub from '~/invite_members/event_hub';
import DuoExtensions from 'ee/pages/projects/get_started/components/duo_extensions.vue';
import RightSidebar from 'ee/pages/projects/get_started/components/right_sidebar.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import axios from '~/lib/utils/axios_utils';
import { createAlert, VARIANT_INFO } from '~/alert';

jest.mock('~/alert', () => ({
  ...jest.requireActual('~/alert'),
  createAlert: jest.fn().mockName('createAlertMock'),
}));

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('GetStarted', () => {
  let wrapper;

  const defaultProvide = {
    projectName: 'test-project',
  };

  const createSections = () => [
    {
      title: 'Section 1',
      description: 'Description 1',
      actions: [
        { id: 1, title: 'Action 1' },
        { id: 2, title: 'Action 2' },
      ],
    },
    {
      title: 'Section 2',
      description: 'Description 2',
      trialActions: [
        { id: 3, title: 'Trial Action 1' },
        { id: 4, title: 'Trial Action 2' },
      ],
    },
  ];

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(GetStarted, {
      propsData: {
        sections: createSections(),
        tutorialEndPath: '/group/project/-/get-started/end',
        ...props,
      },
      provide: {
        ...defaultProvide,
      },
      stubs: {
        GlCard: { template: '<div><slot name="header" /><slot /></div>' },
      },
    });
  };

  const findCards = () => wrapper.findAllComponents(GlCard);
  const findSectionHeaders = () => wrapper.findAllComponents(SectionHeader);
  const findSectionBodies = () => wrapper.findAllComponents(SectionBody);
  const findTitle = () => wrapper.find('h2');
  const findSuccessfulInvitationsAlert = () => wrapper.findComponent(GlAlert);
  const findRightSidebar = () => wrapper.findComponent(RightSidebar);
  const findEndTutorialButton = () => wrapper.findComponentByTestId('end-tutorial-button');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the component', () => {
      expect(wrapper.exists()).toBe(true);
    });

    it('renders the correct title', () => {
      expect(findTitle().text()).toBe('Quick start');
    });

    it('renders a card for each section', () => {
      expect(findCards()).toHaveLength(2);
    });

    it('renders section headers', () => {
      expect(findSectionHeaders()).toHaveLength(2);
    });

    it('renders section bodies', () => {
      expect(findSectionBodies()).toHaveLength(2);
    });

    it('renders the right sidebar', () => {
      expect(findRightSidebar().exists()).toBe(true);
    });
  });

  describe('section expansion', () => {
    beforeEach(() => {
      createComponent();
    });

    it('expands the first section by default', () => {
      expect(wrapper.vm.expandedIndex).toBe(0);
      expect(wrapper.vm.isExpanded(0)).toBe(true);
      expect(wrapper.vm.isExpanded(1)).toBe(false);
    });

    it('toggles expansion when a section header is clicked', async () => {
      // Toggle section 1 (should collapse it)
      await wrapper.vm.toggleExpand(0);
      expect(wrapper.vm.expandedIndex).toBe(null);
      expect(wrapper.vm.isExpanded(0)).toBe(false);

      // Toggle section 2 (should expand it)
      await wrapper.vm.toggleExpand(1);
      expect(wrapper.vm.expandedIndex).toBe(1);
      expect(wrapper.vm.isExpanded(0)).toBe(false);
      expect(wrapper.vm.isExpanded(1)).toBe(true);

      // Toggle section 2 again (should collapse it)
      await wrapper.vm.toggleExpand(1);
      expect(wrapper.vm.expandedIndex).toBe(null);
      expect(wrapper.vm.isExpanded(1)).toBe(false);
    });

    it('renders the duo extension section', () => {
      expect(wrapper.findComponent(DuoExtensions).exists()).toBe(true);
    });
  });

  describe('End tutorial button', () => {
    let axiosMock;
    const errorMessage = 'There was a problem trying to end the tutorial. Please try again.';

    beforeEach(() => {
      axiosMock = new MockAdapter(axios);
      createComponent();
    });

    afterEach(() => {
      axiosMock.restore();
    });

    it('should disable the button when clicked', async () => {
      findEndTutorialButton().vm.$emit('click');

      await nextTick();

      expect(findEndTutorialButton().attributes('disabled')).toBeDefined();
    });

    it('should call visitUrl with the correct link when clicked', async () => {
      const redirectPath = '/group/project';
      axiosMock.onPatch('/group/project/-/get-started/end').reply(200, {
        success: true,
        redirect_path: redirectPath,
      });

      findEndTutorialButton().vm.$emit('click');
      await waitForPromises();

      expect(visitUrl).toHaveBeenCalledWith(redirectPath);
    });

    it('should show alert when post request to end tutorial fails', async () => {
      axiosMock.onPatch('/group/project/-/get-started/end').reply(422, {
        success: false,
        message: errorMessage,
      });

      findEndTutorialButton().vm.$emit('click');
      await waitForPromises();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        variant: VARIANT_INFO,
      });
      expect(findEndTutorialButton().attributes('disabled')).not.toBeDefined();
    });

    it('should show alert when post request does not return success', async () => {
      axiosMock.onPatch('/group/project/-/get-started/end').reply(200, {
        success: false,
      });

      findEndTutorialButton().vm.$emit('click');
      await waitForPromises();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        variant: VARIANT_INFO,
      });
      expect(findEndTutorialButton().attributes('disabled')).not.toBeDefined();
    });
  });

  describe('event handling', () => {
    let sections;

    beforeEach(() => {
      jest.spyOn(eventHub, '$on');
      jest.spyOn(eventHub, '$off');
      sections = createSections();
      sections[0].actions[1].urlType = 'invite';
      createComponent({ sections });
    });

    it('registers event listeners on mount', () => {
      expect(eventHub.$on).toHaveBeenCalledWith(
        'showSuccessfulInvitationsAlert',
        wrapper.vm.handleShowSuccessfulInvitationsAlert,
      );
    });

    it('removes event listeners before destroy', () => {
      wrapper.destroy();

      expect(eventHub.$off).toHaveBeenCalledWith(
        'showSuccessfulInvitationsAlert',
        wrapper.vm.handleShowSuccessfulInvitationsAlert,
      );
    });
  });

  describe('invitation alerts', () => {
    let sections;

    beforeEach(() => {
      sections = createSections();
      sections[0].actions[0].urlType = 'invite';
      createComponent({ sections });
    });

    it('does not show alert by default', () => {
      expect(findSuccessfulInvitationsAlert().exists()).toBe(false);
    });

    it('shows alert when invitation is successful', async () => {
      eventHub.$emit('showSuccessfulInvitationsAlert');
      await nextTick();

      expect(findSuccessfulInvitationsAlert().exists()).toBe(true);
      expect(findSuccessfulInvitationsAlert().props('variant')).toBe('success');
      expect(findSuccessfulInvitationsAlert().props('dismissible')).toBe(true);
    });

    it('dismisses the alert when dismissed', async () => {
      eventHub.$emit('showSuccessfulInvitationsAlert');
      await nextTick();

      findSuccessfulInvitationsAlert().vm.$emit('dismiss');
      await nextTick();

      expect(findSuccessfulInvitationsAlert().exists()).toBe(false);
    });
  });
});
