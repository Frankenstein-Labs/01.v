import { nextTick } from 'vue';
import { GlAlert, GlFormRadio, GlFormRadioGroup, GlSprintf, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';
import VisibilityLevelRadioGroup from 'ee/ai/catalog/components/visibility_level_radio_group.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

describe('VisibilityLevelRadioGroup', () => {
  let wrapper;

  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findAllHelpPopovers = () => wrapper.findAllComponents(HelpPopover);
  const findConfirmModal = () => wrapper.findComponent(GlModal);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const selectVisibilityLevel = async (level) => {
    findFormRadioGroup().vm.$emit('input', level);
    await nextTick();
  };

  const defaultProps = {
    id: '1',
    texts: {
      textPrivate: 'Private text',
      textRestricted: 'Restricted text',
      textPublic: 'Public text',
    },
    itemType: 'AGENT',
    value: VISIBILITY_LEVEL_PUBLIC,
  };

  const createWrapper = (props = {}, glFeatures = {}, { isGlobalNamespace = false } = {}) => {
    wrapper = shallowMountExtended(VisibilityLevelRadioGroup, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        glFeatures,
        isGlobalNamespace,
      },
      stubs: {
        GlFormRadio,
        GlSprintf,
      },
    });
  };

  describe('Visibility Level Radio Group', () => {
    describe('input event', () => {
      it('emits the input event', async () => {
        createWrapper();
        await selectVisibilityLevel(VISIBILITY_LEVEL_PRIVATE);

        expect(findConfirmModal().exists()).toBe(false);
        expect(wrapper.emitted('input')).toHaveLength(1);
        expect(wrapper.emitted('input')[0][0]).toBe(VISIBILITY_LEVEL_PRIVATE);
      });

      it('emits the input event without showing the modal for restricted', async () => {
        createWrapper({ value: VISIBILITY_LEVEL_PRIVATE }, { aiCatalogInternalVisibility: true });
        await selectVisibilityLevel(VISIBILITY_LEVEL_RESTRICTED);

        expect(findConfirmModal().exists()).toBe(false);
        expect(wrapper.emitted('input')).toHaveLength(1);
        expect(wrapper.emitted('input')[0][0]).toBe(VISIBILITY_LEVEL_RESTRICTED);
      });
    });

    describe('when selecting public visibility from private', () => {
      beforeEach(async () => {
        createWrapper({ value: VISIBILITY_LEVEL_PRIVATE });
        await selectVisibilityLevel(VISIBILITY_LEVEL_PUBLIC);
      });

      it('emits input event and shows confirmation modal', () => {
        expect(findConfirmModal().exists()).toBe(true);
        expect(wrapper.emitted('input')).toHaveLength(1);
        expect(wrapper.emitted('input')[0][0]).toBe(VISIBILITY_LEVEL_PUBLIC);
      });

      it('closes modal when user confirms', async () => {
        findConfirmModal().vm.$emit('primary');
        await nextTick();

        expect(findConfirmModal().exists()).toBe(false);
        expect(wrapper.emitted('input')).toHaveLength(1);
      });

      it.each([VISIBILITY_LEVEL_PRIVATE, VISIBILITY_LEVEL_RESTRICTED])(
        'reverts to previous value (%s) when user cancels modal',
        async (previousValue) => {
          createWrapper({ value: previousValue }, { aiCatalogInternalVisibility: true });
          await selectVisibilityLevel(VISIBILITY_LEVEL_PUBLIC);

          findConfirmModal().vm.$emit('hidden');
          await nextTick();

          expect(findConfirmModal().exists()).toBe(false);
          expect(wrapper.emitted('input')).toHaveLength(2);
          expect(wrapper.emitted('input')[1][0]).toBe(previousValue);
        },
      );

      it('displays correct modal title', () => {
        expect(findConfirmModal().props('title')).toBe('Make agent public?');
      });

      it('displays warning alert in modal', () => {
        expect(findAlert().exists()).toBe(true);
        expect(findAlert().props('variant')).toBe('warning');
      });

      it('displays Make public as primary action text', () => {
        expect(findConfirmModal().props('actionPrimary').text).toBe('Make public');
      });
    });

    describe('when itemType is FLOW', () => {
      it('displays correct modal title for flow', async () => {
        createWrapper({ value: VISIBILITY_LEVEL_PRIVATE, itemType: 'FLOW' });

        await selectVisibilityLevel(VISIBILITY_LEVEL_PUBLIC);

        expect(findConfirmModal().props('title')).toBe('Make flow public?');
      });
    });

    describe('when value is already public', () => {
      it('does not show modal when selecting public again', async () => {
        createWrapper({ value: VISIBILITY_LEVEL_PUBLIC });

        await selectVisibilityLevel(VISIBILITY_LEVEL_PUBLIC);

        expect(findConfirmModal().exists()).toBe(false);
      });
    });

    describe('aiCatalogInternalVisibility feature flag', () => {
      const popoverTitles = () =>
        findAllHelpPopovers().wrappers.map((popover) => popover.props('options').title);

      it('hides the restricted option when the flag is disabled', () => {
        createWrapper();

        expect(popoverTitles()).toEqual(['Private agent', 'Public agent']);
      });

      it('shows the restricted option when the flag is enabled', () => {
        createWrapper({}, { aiCatalogInternalVisibility: true });

        expect(popoverTitles()).toEqual(['Private agent', 'Restricted agent', 'Public agent']);
      });

      it('hides the restricted option at explore-level even when the flag is enabled', () => {
        createWrapper({}, { aiCatalogInternalVisibility: true }, { isGlobalNamespace: true });

        expect(popoverTitles()).toEqual(['Private agent', 'Public agent']);
      });
    });

    describe('popover', () => {
      beforeEach(() => {
        createWrapper({}, { aiCatalogInternalVisibility: true });
      });

      it('renders a popover for each visibility level', () => {
        expect(findAllHelpPopovers()).toHaveLength(3);
      });

      it('renders correct content for private popover', () => {
        const privatePopover = findAllHelpPopovers().at(0);
        expect(privatePopover.props('options')).toEqual({
          title: 'Private agent',
        });
        expect(privatePopover.findAll('strong').at(0).text()).toBe('A private agent:');
        expect(privatePopover.text()).toContain(
          'Is visible only to users with at least the Developer role for this project, and to users with the Owner role for the top-level group.',
        );
        expect(privatePopover.findAll('strong').at(1).text()).toBe('Private agents are best for:');
        expect(privatePopover.text()).toContain('Project-specific automation.');
      });

      it('renders correct content for restricted popover', () => {
        const restrictedPopover = findAllHelpPopovers().at(1);
        expect(restrictedPopover.props('options')).toEqual({
          title: 'Restricted agent',
        });
        expect(restrictedPopover.findAll('strong').at(0).text()).toBe('A restricted agent:');
        expect(restrictedPopover.text()).toContain(
          "Is visible to everyone in the owning project's top-level group.",
        );
        expect(restrictedPopover.findAll('strong').at(1).text()).toBe(
          'Restricted agents are best for:',
        );
        expect(restrictedPopover.text()).toContain('Reuse across teams.');
      });

      it('renders correct content for public popover', () => {
        const publicPopover = findAllHelpPopovers().at(2);
        expect(publicPopover.props('options')).toEqual({
          title: 'Public agent',
        });
        expect(publicPopover.findAll('strong').at(0).text()).toBe('A public agent:');
        expect(publicPopover.text()).toContain(
          'Is visible to everyone, including users outside your organization.',
        );
        expect(publicPopover.findAll('strong').at(1).text()).toBe('Public agents are best for:');
        expect(publicPopover.text()).toContain('Community contributions.');
        expect(publicPopover.text()).toContain(
          "Anyone can see your prompts and settings. Don't include sensitive data or reference internal systems.",
        );
      });
    });
  });
});
